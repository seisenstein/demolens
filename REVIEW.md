# DemoLens Plan Architecture Review

This review is intentionally adversarial. It audits `PLAN.md` against the Promptable codebase at `/Users/sean/Promptable_Technologies` and against macOS 14 implementation constraints. It does not modify the plan.

## Critical Findings

### 1. SCStream microphone capture is not macOS 14 feasible

Severity: critical

What's wrong: `PLAN.md` says the app targets macOS 14 because of "Native microphone capture in SCStream" and Phase 2 uses `SCStreamConfiguration.captureMicrophone` as "macOS 14+". The installed SDK marks both `captureMicrophone` and `microphoneCaptureDeviceID` as `API_AVAILABLE(macos(15.0))`, so the Phase 2 design will not compile or run as described for the stated minimum OS.

Recommended fix: Either raise the minimum deployment target to macOS 15 or capture microphone audio separately on macOS 14 with `AVCaptureSession` or `AVAudioEngine`, then explicitly synchronize that track with ScreenCaptureKit system audio and video.

Evidence: `PLAN.md:99`, `PLAN.md:241`; local SDK `ScreenCaptureKit.framework/Headers/SCStream.h:342`.

### 2. The actor handoff has no bounded backpressure model

Severity: critical

What's wrong: The plan sends arbitrary `SCStreamOutput` callbacks into a `RecordingCoordinator` actor that serializes access. If 30fps frames arrive every 33 ms and compositing or writing takes longer, callbacks can enqueue unbounded async work behind the actor. `queueDepth = 6` is capture-side buffering, not an application backpressure policy.

Recommended fix: Keep SCStream callbacks minimal. Validate metadata and hand off to bounded queues or a latest-frame mailbox before actor entry. Use dedicated render/write queues with explicit drop/coalesce behavior, and add metrics for queue depth, render latency, append latency, and dropped frames.

Evidence: `PLAN.md:181-190`, `PLAN.md:216`.

### 3. Timestamp rebasing can desynchronize audio and video

Severity: critical

What's wrong: The plan says to store "the first timestamp" and subtract it, but it also says to drop incomplete/idle/blank frames. If the first video frame is dropped while audio already started, each stream can end up with a different effective epoch, or video can begin with a silent/blank offset that was never modeled.

Recommended fix: Define a single recording epoch for all tracks. Start the writer session from one canonical host-time/media-time anchor, validate video frames before selecting a video epoch, and rebase every accepted audio and video sample against the same session start.

Evidence: `PLAN.md:213-215`, `PLAN.md:240-243`.

### 4. AVAssetWriter readiness and drop policy are missing

Severity: critical

What's wrong: `VideoWriter` is described as an actor with append methods, but the plan never defines behavior when `AVAssetWriterInput.isReadyForMoreMediaData` is false or when `append` returns false. This can fail writes, grow memory, or block behind writer backpressure.

Recommended fix: Gate every append on writer input readiness. For video, drop or coalesce before render when behind, preserving timestamps for surviving frames. For audio, buffer within a strict limit or fail the recording cleanly rather than dropping arbitrary audio samples.

Evidence: `PLAN.md:124`, `PLAN.md:187-190`, `PLAN.md:208`.

### 5. DemoLens has no Promptable discovery path

Severity: critical

What's wrong: The plan says DemoLens should feel like it is built into Promptable, but Promptable's actual app navigation is Dashboard, Prompt Library, Skills Library, and Organization. There is no "Record demo", desktop app download, launch, or onboarding surface in the web product.

Recommended fix: Add DemoLens as a first-class Promptable surface before treating design fidelity as integration. Define marketing placement, authenticated app navigation, install/open actions, and what users see when the native app is absent.

Evidence: `/Users/sean/Promptable_Technologies/lib/config/navigation/app.ts`, `/Users/sean/Promptable_Technologies/components/landing/landing-nav.tsx`.

### 6. There is no native auth or deep-link bridge

Severity: critical

What's wrong: Promptable APIs assume browser Supabase cookies and CSRF tokens. A native macOS app has no defined device flow, app token, universal link, custom scheme, or post-login callback. Without this, DemoLens cannot securely upload recordings or attach them to Promptable resources.

Recommended fix: Design native app auth explicitly: OAuth/device-code or short-lived app tokens, CSRF-compatible API access, token revocation, and `promptable://` or universal-link flows for login, record, upload, and recording-complete handoff.

Evidence: `/Users/sean/Promptable_Technologies/lib/api/secure-handler.ts`, `/Users/sean/Promptable_Technologies/lib/api/client.ts`, `/Users/sean/Promptable_Technologies/lib/utils/open-in-ai.ts`.

### 7. Promptable has no recording object model or web player

Severity: critical

What's wrong: DemoLens outputs local MOV files and defers sharing to a future phase. Promptable has prompts, skills, files, imports, shares, and notifications, but no recording table, thumbnail/duration/transcript metadata, ownership model, team visibility model, web player route, or share workflow for videos.

Recommended fix: Define `recordings` as a product entity with storage keys, scan/transcode status, duration, poster frame, owner/org/project associations, share permissions, and a web playback page.

Evidence: `PLAN.md:270-281`; `/Users/sean/Promptable_Technologies/supabase/migrations/001_initial_schema.sql`.

## High Findings

### 8. Dropping video but not audio can create drift

Severity: high

What's wrong: The plan allows dropping video frames but does not state whether subsequent frames keep their original presentation timestamps. If video is renumbered to a synthetic 30fps cadence while audio keeps original timing, audio/video drift follows.

Recommended fix: Never derive output PTS from frame count. Append surviving frames at their rebased source PTS. If constant-frame-rate output is required, duplicate the last good frame at scheduled timestamps instead of shifting time.

Evidence: `PLAN.md:203-216`.

### 9. Core Image rendering is treated as free, but it is synchronous from the caller

Severity: high

What's wrong: The plan assumes `CIContext.render(composited, to: outputPixelBuffer)` is cheap because it is GPU-backed. That call still blocks the caller while Core Image schedules and completes work, waits on GPU resources, performs color conversion, and obtains output buffers.

Recommended fix: Run compositing on a dedicated render queue, preallocate a `CVPixelBufferPool`, measure p50/p95 render time, and drop/coalesce frames before render when the pipeline falls behind. Do not render on SCStream callback queues or behind a shared coordinator actor.

Evidence: `PLAN.md:208-210`.

### 10. Actor-based MVVM is too coarse for real-time media

Severity: high

What's wrong: The plan uses actor-based MVVM as the main thread-safety story for screen frames, webcam frames, cursor state, system audio, and microphone audio. A single coordinator actor creates head-of-line blocking: audio appends can wait behind video rendering, and cursor/webcam state reads can become cross-actor work inside a 33 ms frame budget.

Recommended fix: Keep UI state in `@MainActor`, lifecycle coordination in a small actor, and real-time media on dedicated queues or narrowly scoped actors. Cursor and webcam state should be latest-value snapshots with timestamps, not per-frame blocking calls through a central actor.

Evidence: `PLAN.md:62-101`, `PLAN.md:181-190`.

### 11. Cursor capture contradicts itself

Severity: high

What's wrong: The plan sets `showsCursor = false + custom highlight` because it wants a highlight ring, but the compositing pipeline only draws the highlight ring, not the actual cursor image. The resulting video can show a ring with no pointer.

Recommended fix: Either set `showsCursor = true` and composite only the highlight/click effects, or render the cursor image manually with correct hotspot, scale, cursor-shape changes, and multi-display coordinate conversion.

Evidence: `PLAN.md:100`, `PLAN.md:205-207`, `PLAN.md:252-257`.

### 12. `Cmd+Shift+R` via `NSEvent.addGlobalMonitorForEvents` is not a real global shortcut

Severity: high

What's wrong: A global monitor observes copies of events sent to other apps, cannot prevent delivery, does not receive events sent to DemoLens itself, and requires Accessibility trust for key events. `Cmd+Shift+R` also conflicts with browser reload/hard-reload habits, exactly where demos are likely recorded.

Recommended fix: Use `RegisterEventHotKey` or a maintained wrapper such as `KeyboardShortcuts`, make the shortcut user-configurable, handle registration failure, and choose a less collision-prone default.

Evidence: `PLAN.md:271`; Apple `NSEvent.addGlobalMonitorForEvents` docs.

### 13. Transparent overlays are underspecified for Spaces, full-screen apps, and multiple displays

Severity: high

What's wrong: The plan lists a transparent cursor overlay and countdown overlay as if one window is enough. On macOS, reliable overlay behavior needs per-display windows and AppKit configuration for full-screen Spaces, separate display Spaces, display reconfiguration, Mission Control, and click-through behavior.

Recommended fix: Create one non-activating borderless window or `NSPanel` per `NSScreen`, with clear background, `isOpaque = false`, `ignoresMouseEvents = true`, and collection behavior such as `.canJoinAllSpaces`, `.fullScreenAuxiliary`, `.stationary`, and `.ignoresCycle`. Use `.screenSaver` level only where justified, such as countdown, and test full-screen Safari/Chrome and external displays.

Evidence: `PLAN.md:135`, `PLAN.md:257`, `PLAN.md:266`.

### 14. Promptable color tokens are materially inaccurate

Severity: high

What's wrong: The plan's hex table does not match the real dark-mode OKLCH tokens for most surfaces and buttons. Actual dark conversions include background `#010303` not `#0f1214`, card `#040a0c` not `#1a1f22`, surface/popover `#081113` not `#212830`, primary button `#157c8e` not `#1a7080`, primary button hover `#006779` not `#15606e`, foreground `#c2c1bd` not `#c8c5bf`, border `#3a3a3a` not `#444444`, and destructive `#f8554c` or solid destructive `#d40c19` not `#d94040`.

Recommended fix: Generate SwiftUI colors from the actual OKLCH tokens or replace the table with verified dark-mode hex values. Do not use the current plan table for surfaces, buttons, or destructive states.

Evidence: `PLAN.md:22-39`; `/Users/sean/Promptable_Technologies/app/globals.css`.

### 15. Glassmorphism spec does not match Promptable's real pattern

Severity: high

What's wrong: The plan says glassmorphic containers should be `.ultraThinMaterial + teal gradient overlay at 15% opacity`. Promptable mostly uses dark `bg-card`/`bg-popover`, border/hairline shadows, and occasional `bg-background-80 backdrop-blur-xl`; legacy landing components use `bg-black/40-60 backdrop-blur-xl` and teal gradients, not a standard 15% overlay.

Recommended fix: Use a deliberately dark tinted SwiftUI material or translucent color layer with Promptable hairline and shadow tokens. Treat plain `.ultraThinMaterial` as insufficient because it will inherit macOS desktop colors and read more like system glass than Promptable.

Evidence: `PLAN.md:52`; `/Users/sean/Promptable_Technologies/components/ui/dropdown-menu.tsx`, `/Users/sean/Promptable_Technologies/components/legacy-landing/IconContainer.tsx`, `/Users/sean/Promptable_Technologies/components/landing/landing-nav.tsx`.

### 16. Existing Promptable upload APIs are not suitable for recordings

Severity: high

What's wrong: Promptable recognizes video MIME types, but current upload contexts exclude video from prompt attachments, imports, and feedback. The database also caps `file_storage.file_size_bytes` at 100 MB, which is too low for many screen recordings.

Recommended fix: Add a `recording` upload context, increase or separate size limits, support resumable/direct-to-storage upload, and process recording-specific scan/transcode/metadata jobs.

Evidence: `/Users/sean/Promptable_Technologies/lib/validation/file.schema.ts`, `/Users/sean/Promptable_Technologies/supabase/migrations/001_initial_schema.sql`.

### 17. Recordings cannot feed back into Promptable workflows

Severity: high

What's wrong: Promptable can import prompts and skills and associate files with prompts, but there is no endpoint or UX to turn a DemoLens recording into a prompt asset, skill asset, feedback item, review request, transcript, or org/project artifact.

Recommended fix: Add post-recording actions: attach to prompt, attach to skill, create demo artifact, submit feedback, generate transcript/summary, and link to org/project context.

Evidence: `PLAN.md:277-281`; `/Users/sean/Promptable_Technologies/app/api/files/associate/route.ts`, `/Users/sean/Promptable_Technologies/app/api/skills/import/route.ts`.

### 18. Notification bell cannot represent recording lifecycle

Severity: high

What's wrong: Promptable notification types cover org/member/import events, and the dropdown defaults unknown types to mail. Recording processing states such as uploaded, processing, ready, and failed would need schema, DB constraints, filters, icons, routes, and realtime cache behavior.

Recommended fix: Add notification types such as `recording_uploaded`, `recording_processing`, `recording_ready`, and `recording_failed`; update DB constraints, category filters, dropdown icon mapping, click targets, and realtime invalidation.

Evidence: `/Users/sean/Promptable_Technologies/lib/services/notification.service.ts`, `/Users/sean/Promptable_Technologies/components/notifications/notification-dropdown.tsx`, `/Users/sean/Promptable_Technologies/app/api/notifications/route.ts`.

## Medium Findings

### 19. SCStream callback queue ownership is missing

Severity: medium

What's wrong: The plan says callbacks arrive on arbitrary queues, but SCStream outputs are registered with caller-provided queues. The plan does not specify separate queues for screen, system audio, and microphone, nor ordering and isolation guarantees.

Recommended fix: Define named queues per output type. Video callbacks should validate/extract metadata and enqueue bounded work. Audio should append or hand off to audio writer queues without waiting on video render work.

Evidence: `PLAN.md:181`.

### 20. `queueDepth = 6` is oversold and partially wrong

Severity: medium

What's wrong: The plan says `queueDepth = 6 (minimum 4) to prevent stutter`. The local SDK says the default is 8 and should not exceed 8; it does not state a minimum of 4. Deeper buffering increases memory and latency and can hide a slow processing pipeline.

Recommended fix: Treat queue depth as capture buffering only. Pick a measured default and pair it with render/write budgets, frame drop counters, and explicit recovery behavior.

Evidence: `PLAN.md:216`; local SDK `SCStream.h:258-261`.

### 21. Idle frame handling conflicts with last-frame padding

Severity: medium

What's wrong: The plan says ScreenCaptureKit only sends frames when pixels change and to repeat the last frame on stop, but also says to drop idle frames. Without precise timestamp behavior, long static periods can produce timeline gaps or incorrect duration.

Recommended fix: Handle `.idle` separately from incomplete/blank. Preserve duration by appending duplicate frames at needed timestamps, especially before stop and across long static periods.

Evidence: `PLAN.md:214-215`.

### 22. Cursor preview and recorded cursor paths can diverge

Severity: medium

What's wrong: `CursorOverlayWindow` renders live visual feedback while the compositor separately bakes cursor effects into the recording. Without a shared timestamped cursor-event model, the user can see one effect while the video captures another. The overlay may also be accidentally captured unless explicitly excluded.

Recommended fix: Use one cursor event model with timestamps. Let the overlay and compositor consume the same model, or mark the overlay as preview-only. Exclude DemoLens overlay windows from ScreenCaptureKit capture.

Evidence: `PLAN.md:176-179`, `PLAN.md:257`.

### 23. Separate audio tracks lack an operational sync strategy

Severity: medium

What's wrong: The plan says system audio and microphone are separate tracks, but does not define clock alignment, sample rate/channel normalization, format conversion, start offsets, or behavior if one source starts later.

Recommended fix: Normalize audio formats up front, choose one session epoch, record per-track start offsets, and test system-only, mic-only, and delayed-device-start cases.

Evidence: `PLAN.md:13`, `PLAN.md:240-243`.

### 24. MenuBarExtra `.window` is overloaded

Severity: medium

What's wrong: The plan puts rich settings, display thumbnails, device pickers, and recordings list into `MenuBarExtra`. A `.window` menu extra can host SwiftUI, but it is an anchored transient surface, not a durable settings workspace. Long lists and thumbnails can overflow, close on focus changes, and feel fragile.

Recommended fix: Keep MenuBarExtra compact: status, start/stop, selected display/camera, and recent recordings. Put full Settings and Recordings in a separate `Settings {}` scene or `WindowGroup`, with fixed sizes and scrollable content.

Evidence: `PLAN.md:129-141`, `PLAN.md:261-268`.

### 25. NSPanel SwiftUI lifecycle needs explicit ownership

Severity: medium

What's wrong: SwiftUI in `NSPanel` is feasible, but manually created `NSHostingView`/`NSHostingController` instances do not automatically inherit app-level `@EnvironmentObject`s. `@StateObject` can reset if the root view or panel controller is recreated.

Recommended fix: Own panels from a retained `@MainActor` controller, keep recording-critical view models outside the panel, inject dependencies explicitly with `.environmentObject(...)`, and hide rather than deallocate active recording panels.

Evidence: `PLAN.md:96`, `PLAN.md:265`.

### 26. Bundled font implementation is incomplete

Severity: medium

What's wrong: The plan lists font files and Info.plist only for camera/mic permissions. A macOS app needs fonts copied into the bundle and registered through `ATSApplicationFontsPath` or process-scoped Core Text registration. Non-sandboxing is irrelevant to font availability.

Recommended fix: Add fonts to Copy Bundle Resources and either set `ATSApplicationFontsPath` to the resources-relative font folder or register each font at launch with `CTFontManagerRegisterFontsForURL(..., .process, ...)`. Verify actual PostScript names.

Evidence: `PLAN.md:42-44`, `PLAN.md:156-167`.

### 27. Manrope weight 650 cannot be produced from the planned static fonts

Severity: medium

What's wrong: Promptable loads Manrope weights 400/500/600/700/800 from Google Fonts. The plan wants heading weight 650 but bundles only 400/500/600/700. SwiftUI's named weights do not include 650, and static 600/700 files cannot render a true 650.

Recommended fix: Use Manrope Semibold 600 with the same tight tracking, or bundle a variable Manrope font and apply numeric weight through an attributed font descriptor.

Evidence: `PLAN.md:42-44`; `/Users/sean/Promptable_Technologies/app/layout.tsx`.

### 28. Button spec omits Promptable variants and exact shadows

Severity: medium

What's wrong: The plan captures the `active:scale-[0.985]` behavior, but simplifies the hover glow. Promptable buttons include variants `default`, `destructive`, `outline`, `secondary`, `ghost`, and `link`; sizes `sm`, `md`, `lg`, and `icon`; and default hover shadow `inset hairline + 0 0 0 1px primary-30 + 0 4px 12px -2 primary-40`.

Recommended fix: Port the exact variant/size matrix and shadow recipes into `PTButton`. Keep the 150 ms press transform.

Evidence: `PLAN.md:49-50`, `/Users/sean/Promptable_Technologies/components/ui/button.tsx`.

### 29. Card lift is not a base card behavior

Severity: medium

What's wrong: The plan says "Card lift on hover" as a signature pattern. Promptable's base `Card` is `rounded-xl border bg-card text-card-foreground shadow-sm`; hover lift is added only by interactive cards.

Recommended fix: Make `PTCard` a quiet base surface and add a separate interactive/lift modifier for clickable cards.

Evidence: `PLAN.md:51`, `/Users/sean/Promptable_Technologies/components/ui/card.tsx`.

### 30. Promptable support patterns are missing

Severity: medium

What's wrong: The plan omits several real Promptable details: global focus rings, custom scrollbars, muted loading skeletons, icon-circle empty states, Radix-like dropdown/popover density, and Sonner toast styling.

Recommended fix: Add SwiftUI equivalents for focus rings, scroll indicators where practical, skeleton pulse placeholders, empty states, and toast/HUD surfaces.

Evidence: `/Users/sean/Promptable_Technologies/app/globals.css`, `/Users/sean/Promptable_Technologies/components/ui/skeleton.tsx`, `/Users/sean/Promptable_Technologies/components/notifications/notification-dropdown.tsx`, `/Users/sean/Promptable_Technologies/components/ui/sonner.tsx`.

### 31. Sonner toasts do not translate directly to macOS

Severity: medium

What's wrong: Promptable uses Sonner web toasts at bottom-right with `popover`, `popover-foreground`, and `border` tokens. DemoLens needs native foreground/background behavior for permission failures, upload progress, and completed recordings.

Recommended fix: Use macOS `UserNotifications` for background or completed work and a Promptable-styled SwiftUI HUD/toast only while the app UI is foregrounded.

Evidence: `/Users/sean/Promptable_Technologies/components/ui/sonner.tsx`, `/Users/sean/Promptable_Technologies/app/providers.tsx`.

### 32. WindowFrame is marketing chrome, not native app chrome

Severity: medium

What's wrong: The required `WindowFrame` component is `aria-hidden` and presentation-only for landing demos. Mirroring it in DemoLens would create fake traffic-light chrome inside real macOS chrome.

Recommended fix: Reuse Promptable colors, typography, spacing, borders, and shadows, but use real `NSPanel`, `MenuBarExtra`, and system window controls.

Evidence: `/Users/sean/Promptable_Technologies/components/legacy-landing/WindowFrame.tsx`.

### 33. Non-sandboxed is overstated as a requirement

Severity: medium

What's wrong: The plan says non-sandboxed is required for Accessibility APIs and full ScreenCaptureKit access. TCC permissions for Screen Recording, Camera, Microphone, and Accessibility are separate from sandboxing. Non-sandboxed may be a practical distribution choice, but it does not remove prompts or permission flows.

Recommended fix: Treat sandboxing as a distribution and entitlement decision. Keep the permission flow explicit either way and verify notarization/distribution assumptions separately.

Evidence: `PLAN.md:98`, `PLAN.md:218-227`.

### 34. Display picker thumbnails need a separate capture design

Severity: medium

What's wrong: The plan asks for multi-monitor thumbnails inside MenuBarExtra. Live ScreenCaptureKit thumbnails in a transient menu bar window can be expensive, permission-gated, and awkward before Screen Recording access is granted.

Recommended fix: Use cached `SCScreenshotManager` or low-rate snapshots after permission, placeholders before permission, lazy thumbnail generation, and display-change invalidation.

Evidence: `PLAN.md:130`, `PLAN.md:262`.

## Low Findings

### 35. "30fps 1080p easily" is an unmeasured assumption

Severity: low

What's wrong: The plan asserts Core Image can handle 30fps 1080p easily on Apple Silicon, but includes no latency budget, instrumentation, fallback resolution, or lower-end hardware target.

Recommended fix: Add capture-to-append latency, render time, writer backpressure, dropped frame count, and A/V skew metrics. Add fallback settings for resolution, frame rate, and overlay complexity.

Evidence: `PLAN.md:91`, `PLAN.md:210`.

### 36. Screen Recording permission behavior is imprecise

Severity: low

What's wrong: The plan says `CGRequestScreenCaptureAccess()` cannot auto-prompt and directs to System Settings. The API is a request API and can potentially prompt; users may still need System Settings and an app restart depending on state.

Recommended fix: Use `CGPreflightScreenCaptureAccess()` first, then `CGRequestScreenCaptureAccess()`, then provide an "Open System Settings" fallback with explicit restart guidance.

Evidence: `PLAN.md:222`.

### 37. Cursor tracking is not a complete cursor model

Severity: low

What's wrong: `NSEvent` global/local monitors can miss app-local events unless both are installed, update only on events, and require careful coordinate conversion for Retina displays, negative display origins, display rotation, and Spaces.

Recommended fix: Use both local and global monitors, poll `NSEvent.mouseLocation` where needed, normalize through `NSScreen` frames and backing scale, and test multi-display movement before treating it as polish.

Evidence: `PLAN.md:94`, `PLAN.md:253-256`.

### 38. Radius translation needs explicit point semantics

Severity: low

What's wrong: Promptable uses `--radius: 0.5rem`, which is 8 CSS px on web. On macOS Retina, SwiftUI radii should be logical points, not physical pixels, so this should translate to 8 pt rather than 4 pt.

Recommended fix: Use SwiftUI logical radii: `sm = 4pt`, `md = 6pt`, base/lg `8pt`, card/xl `12pt`, and pills as capsule/full.

Evidence: `PLAN.md:53`; `/Users/sean/Promptable_Technologies/app/globals.css`.

### 39. Business positioning is web-first and DemoLens is not scoped

Severity: low

What's wrong: Promptable's internal context is web-first until profitable, while DemoLens is a native desktop utility. The plan does not decide whether DemoLens is internal tooling, a Promptable add-on, or a standalone product.

Recommended fix: Decide the product role before investing in deep web integration. If internal-only, scope uploads and discovery differently than if it is a customer-facing Promptable product.

Evidence: `/Users/sean/Promptable_Technologies/research-promptable-context.md`, `PLAN.md:5`.

## External References Checked

- Apple `SCStreamConfiguration.queueDepth`: https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration/queuedepth
- Apple `AVAssetWriterInput.append(_:)`: https://developer.apple.com/documentation/avfoundation/avassetwriterinput/append%28_%3A%29
- Apple `CIContext`: https://developer.apple.com/documentation/coreimage/cicontext
- Apple `NSEvent.addGlobalMonitorForEvents`: https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents%28matching%3Ahandler%3A%29
- Apple SwiftUI custom fonts guidance: https://developer.apple.com/documentation/SwiftUI/Applying-Custom-Fonts-to-Text
- Apple `NSHostingView`: https://developer.apple.com/documentation/swiftui/nshostingview
