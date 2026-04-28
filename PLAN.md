# DemoLens: Native macOS Screen Demo Recorder

## Scoping Decision

- DemoLens v1 is internal team tooling for neurocollective. It records demos locally, outputs `.mov` files, and supports simple file-based sharing with the team.
- Promptable integration (auth, upload, web player, recording object model) is deferred to v2 and will be designed when Promptable's product roadmap prioritizes it.
- Design fidelity to Promptable is visual only: colors, fonts, shadows, density, and interaction patterns. There is no runtime connection to Promptable servers in v1.

## Context

Sean needs to record walkthrough demos of AI tools (Promptable, Claude, Codex) for the neurocollective team. Loom does this but costs money. A native Swift macOS app is the right call: ScreenCaptureKit gives direct screen frames, Core Image composites overlays, and AVAssetWriter outputs H.264 MOV natively. No Electron bloat, no FFmpeg, no background throttling hacks.

The app should feel visually native to Promptable, applying its dark surfaces, teal accent, Manrope typography, hairline borders, and restrained interaction patterns to a SwiftUI macOS utility. v1 is not a Promptable web product feature.

## What Gets Built

A native macOS menu bar app (Swift 6, SwiftUI, ScreenCaptureKit) that:

- Records any display with ScreenCaptureKit (`SCStream`)
- Captures the normal system cursor and adds a custom cursor highlight ring + click animations
- Composites an optional circular webcam PiP bubble via Core Image
- Captures system audio via ScreenCaptureKit
- Captures microphone audio via `AVAudioEngine` for macOS 14 compatibility
- Outputs H.264/AAC `.mov` files directly via AVAssetWriter
- Reveals or copies completed `.mov` files for manual team sharing
- Lives in the menu bar with a compact menu and floating recording control panel
- Provides Settings and Recordings windows for heavier workflows
- Applies Promptable's visual design language without connecting to Promptable servers

## Promptable Design Language (for SwiftUI translation)

Extracted from `/Users/sean/Promptable_Technologies/`. Use the dark-mode tokens below. Do not mirror Promptable's legacy `WindowFrame` marketing chrome; DemoLens uses real `NSPanel`, `MenuBarExtra`, and native macOS window controls while applying Promptable colors, type, spacing, borders, and shadows inside those surfaces.

### OKLCH Conversion

Converted with CSS Color 4 OKLCH -> Oklab -> linear sRGB -> gamma-encoded sRGB:

```text
a = C * cos(h)
b = C * sin(h)

l' = L + 0.3963377774a + 0.2158037573b
m' = L - 0.1055613458a - 0.0638541728b
s' = L - 0.0894841775a - 1.2914855480b

l = l'^3
m = m'^3
s = s'^3

Rlinear =  4.0767416621l - 3.3077115913m + 0.2309699292s
Glinear = -1.2684380046l + 2.6097574011m - 0.3413193965s
Blinear = -0.0041960863l - 0.7034186147m + 1.7076147010s
```

Then clamp to `[0, 1]` and encode each channel with sRGB gamma.

Audit note: the token table below is generated from `/Users/sean/Promptable_Technologies/app/globals.css` dark-mode tokens, lines 110-204. All single-value OKLCH variables are converted to clamped, gamma-encoded sRGB/RGBA, and compound shadow tokens preserve the original white/black alpha values. Do not substitute older approximate hex values.

### Core Colors

| Token | Hex / RGBA | Use |
|-------|------------|-----|
| Background | `#010303` | App canvas |
| Background 80 | `rgba(1, 3, 3, 0.8)` | Tinted overlays when needed |
| Foreground | `#c2c1bd` | Body text |
| Card | `#040a0c` | Solid panel/card surface |
| Card foreground | `#f9f8f5` | Bright card titles |
| Surface elevated | `#081113` | Popovers, menus, HUDs |
| Popover | `#081113` | Toast/menu surface |
| Popover foreground | `#e4e4e4` | Text on popovers |
| Primary | `#2c8a9d` | Accent, icons, focus rings |
| Primary hover | `#007082` | Accent hover state |
| Primary button | `#157c8e` | Solid primary CTA background |
| Primary button hover | `#006779` | Primary CTA hover/press |
| Primary foreground | `#f8f8f8` | Text on primary button |
| Primary 10 | `rgba(44, 138, 157, 0.1)` | Active item backgrounds |
| Primary 30 | `rgba(44, 138, 157, 0.3)` | Accent borders / hover shadow ring |
| Primary 40 | `rgba(44, 138, 157, 0.4)` | Primary hover glow |
| Secondary | `#081619` | Secondary button background |
| Secondary foreground | `#2c8a9d` | Secondary button text |
| Muted | `#1b1b1b` | Skeleton/loading fill |
| Muted foreground | `#b5b4ad` | Secondary text |
| Muted foreground disabled | `#81807d` | Disabled labels |
| Muted subtle | `#676767` | Placeholders/counts |
| Accent | `#121212` | Ghost hover background |
| Accent foreground | `#f6f5f1` | Ghost hover text |
| Destructive | `#f8554c` | Error accents |
| Destructive solid | `#d40c19` | Stop/destructive button |
| Destructive solid hover | `#c20000` | Stop/destructive hover |
| Border / input | `#3a3a3a` | 1px borders and inputs |
| Hairline | `rgba(255, 255, 255, 0.05)` | Top inset highlight |
| Hairline strong | `rgba(255, 255, 255, 0.08)` | Button inset highlight |
| Ring | `#2c8a9d` | Focus ring |
| Ring 50 | `rgba(44, 138, 157, 0.5)` | Softer focus/selection ring |

Complete converted dark token reference:

```css
--background: #010303;
--background-50: rgba(1, 3, 3, 0.5);
--background-60: rgba(1, 3, 3, 0.6);
--background-80: rgba(1, 3, 3, 0.8);
--background-90: rgba(1, 3, 3, 0.9);
--foreground: #c2c1bd;
--card: #040a0c;
--card-50: rgba(4, 10, 12, 0.5);
--card-foreground: #f9f8f5;
--surface-elevated: #081113;
--popover: #081113;
--popover-foreground: #e4e4e4;
--hairline: rgba(255, 255, 255, 0.05);
--hairline-strong: rgba(255, 255, 255, 0.08);
--primary: #2c8a9d;
--primary-foreground: #f8f8f8;
--primary-hover: #007082;
--primary-active: #0c0e0f;
--primary-button: #157c8e;
--primary-button-hover: #006779;
--primary-5: rgba(44, 138, 157, 0.05);
--primary-8: rgba(44, 138, 157, 0.08);
--primary-10: rgba(44, 138, 157, 0.1);
--primary-20: rgba(44, 138, 157, 0.2);
--primary-30: rgba(44, 138, 157, 0.3);
--primary-40: rgba(44, 138, 157, 0.4);
--primary-50: rgba(44, 138, 157, 0.5);
--primary-80: rgba(44, 138, 157, 0.8);
--primary-90: rgba(44, 138, 157, 0.9);
--primary-bg-subtle: rgba(44, 138, 157, 0.08);
--primary-border-subtle: rgba(44, 138, 157, 0.3);
--secondary: #081619;
--secondary-80: rgba(8, 22, 25, 0.8);
--secondary-foreground: #2c8a9d;
--muted: #1b1b1b;
--muted-10: rgba(27, 27, 27, 0.1);
--muted-20: rgba(27, 27, 27, 0.2);
--muted-30: rgba(27, 27, 27, 0.3);
--muted-50: rgba(27, 27, 27, 0.5);
--muted-foreground: #b5b4ad;
--muted-foreground-disabled: #81807d;
--muted-subtle: #676767;
--accent: #121212;
--accent-foreground: #f6f5f1;
--accent-5: rgba(18, 18, 18, 0.05);
--accent-10: rgba(18, 18, 18, 0.1);
--accent-50: rgba(18, 18, 18, 0.5);
--destructive: #f8554c;
--destructive-foreground: #f5f5f5;
--destructive-5: rgba(248, 85, 76, 0.05);
--destructive-10: rgba(248, 85, 76, 0.1);
--destructive-20: rgba(248, 85, 76, 0.2);
--destructive-30: rgba(248, 85, 76, 0.3);
--destructive-40: rgba(248, 85, 76, 0.4);
--destructive-50: rgba(248, 85, 76, 0.5);
--destructive-80: rgba(248, 85, 76, 0.8);
--destructive-90: rgba(248, 85, 76, 0.9);
--destructive-solid: #d40c19;
--destructive-solid-hover: #c20000;
--border: #3a3a3a;
--border-30: rgba(58, 58, 58, 0.3);
--border-40: rgba(58, 58, 58, 0.4);
--border-50: rgba(58, 58, 58, 0.5);
--border-60: rgba(58, 58, 58, 0.6);
--input: #3a3a3a;
--input-30: rgba(58, 58, 58, 0.3);
--input-50: rgba(58, 58, 58, 0.5);
--ring: #2c8a9d;
--ring-50: rgba(44, 138, 157, 0.5);
--chart-1: #329fb4;
--chart-2: #2a7b8b;
--chart-3: #245b66;
--chart-4: #18383f;
--chart-5: #081619;
--sidebar: #1f1f1f;
--sidebar-foreground: #c2c1bd;
--sidebar-primary: #353535;
--sidebar-primary-foreground: #fcfcfc;
--sidebar-accent: #0f0f0f;
--sidebar-accent-foreground: #c2c1bd;
--sidebar-border: #ebebeb;
--sidebar-ring: #b4b4b4;
--shadow-2xs: inset 0 1px 0 0 rgba(255, 255, 255, 0.04);
--shadow-xs: inset 0 1px 0 0 rgba(255, 255, 255, 0.05);
--shadow-sm: inset 0 1px 0 0 rgba(255, 255, 255, 0.05), 0 1px 2px 0 rgba(0, 0, 0, 0.35);
--shadow: inset 0 1px 0 0 rgba(255, 255, 255, 0.05), 0 2px 4px -1px rgba(0, 0, 0, 0.4);
--shadow-md: inset 0 1px 0 0 rgba(255, 255, 255, 0.05), 0 4px 8px -2px rgba(0, 0, 0, 0.45);
--shadow-lg: inset 0 1px 0 0 rgba(255, 255, 255, 0.06), 0 12px 24px -4px rgba(0, 0, 0, 0.5);
--shadow-xl: inset 0 1px 0 0 rgba(255, 255, 255, 0.06), 0 24px 48px -8px rgba(0, 0, 0, 0.55);
--shadow-2xl: inset 0 1px 0 0 rgba(255, 255, 255, 0.08), 0 40px 80px -16px rgba(0, 0, 0, 0.65);
```

### Typography

- **Sans UI**: Manrope static fonts bundled at 400, 500, 600, 700.
- **Mono timer/data**: JetBrains Mono static fonts bundled at 400, 500.
- **Heading decision**: use Manrope Semibold 600 with tight tracking. A true 650 is not available from the planned static files, and SwiftUI named weights cannot synthesize numeric 650 reliably. Only use 650 if bundling the variable Manrope font and applying a numeric weight through an attributed font descriptor.
- **Body**: 14-16 pt, weight 400, relaxed line height.
- **Small labels**: 12-13 pt, weight 500, muted foreground.
- **Timer/data**: JetBrains Mono 500.

### Font Loading

Add bundled fonts to Copy Bundle Resources under `Resources/Fonts`. Configure `ATSApplicationFontsPath` to the bundle-relative font directory and also register fonts at launch with `CTFontManagerRegisterFontsForURL(..., .process, ...)` for process-scoped reliability. After registration, verify expected PostScript names before using them in SwiftUI font declarations.

### Surfaces

Promptable surfaces are solid dark layers, not system glass.

Do not use `.ultraThinMaterial`, `.regularMaterial`, or a teal gradient overlay as the default Promptable container treatment.

- Base app background: solid `background`
- Base card: solid `card`, 1px `border`, 12 pt radius, `shadow-sm`
- Elevated popover/HUD/menu: solid `surface-elevated` or `popover`, 1px `border`, 8-12 pt radius, `shadow-md` or `shadow-lg`
- Hairline inset highlight: every elevated Promptable surface gets an inset top highlight, `rgba(255,255,255,0.05)`, 1 logical pt high
- Interactive hairline: buttons and pressed controls use `hairline-strong`
- Translucent overlays may use `background-80` plus blur only when the UI must sit over moving video or screen content. Keep the same border, hairline, and dark tint so the result still reads as Promptable.
- Promptable's base app pattern is solid `card`/`popover` color, 1px `border`, and hairline inset shadow. Legacy landing blur treatments are not the native app chrome model.

SwiftUI radius map:

- `sm`: 4 pt
- `md`: 6 pt
- `lg/base`: 8 pt
- `xl/card`: 12 pt
- pill: capsule

Use logical points, not physical pixels. Promptable's `0.5rem` base radius is 8 CSS px, which maps perceptually to an 8 pt SwiftUI/AppKit radius on Retina displays.

### Buttons

Base button behavior:

- Inline horizontal layout with icon/text gap 8 pt
- Radius 6 pt
- Text: Manrope 500, 14 pt unless size overrides
- Transition duration: 150 ms
- Press transform: `scaleEffect(isPressed ? 0.985 : 1.0)`
- Disabled: opacity 0.5, no pointer interaction
- Focus: 1 pt ring using `ring`

Variant matrix:

| Variant | SwiftUI translation |
|---------|---------------------|
| `default` | Background `primaryButton`; text `primaryForeground`; shadow `inset 0 1px 0 0 hairlineStrong + 0 1px 2px 0 rgba(0,0,0,0.35)`; hover background `primaryButtonHover`; hover shadow `inset 0 1px 0 0 hairlineStrong + 0 0 0 1px primary30 + 0 4px 12px -2 primary40`. |
| `destructive` | Background `destructiveSolid`; text `destructiveForeground`; shadow `inset hairlineStrong + 0 1px 2px rgba(0,0,0,0.35)`; hover background `destructiveSolidHover`. |
| `outline` | 1px `border`; background `card`; text `foreground`; `shadow-xs`; hover border `primary`; hover text `foreground`. |
| `secondary` | Background `secondary`; text `secondaryForeground`; `shadow-xs`; hover background `secondary80`. |
| `ghost` | Transparent background; text `foreground`; hover background `accent`; hover text `accentForeground`. |
| `link` | Transparent background; text `primary`; underline on hover. |

Size matrix:

| Size | SwiftUI translation |
|------|---------------------|
| `sm` | Height 32 pt, horizontal padding 12 pt, text 12 pt. |
| `md` | Height 36 pt, horizontal padding 16 pt, vertical padding 8 pt, text 14 pt. |
| `lg` | Height 40 pt, horizontal padding 32 pt, text 14 pt. |
| `icon` | 36 pt x 36 pt, zero padding, icon 16 pt. |

### Cards

Split base and interactive card behavior.

`PTCard`:

- Equivalent to Promptable `Card`: `rounded-xl border bg-card text-card-foreground shadow-sm`
- Use for passive grouped content
- No hover lift by default

`PTInteractiveCard`:

- Starts from `PTCard`
- Adds hover/pressed affordance only when the whole surface is clickable
- Hover may raise from `shadow-sm` to `shadow-md`, tint border toward `primary30`, or add a subtle `primary5` overlay
- Press uses the same `0.985` scale as buttons when appropriate

### Support Patterns

- **Focus rings**: every keyboard-focusable custom control gets a 1 pt `ring` outline. Use `ring50` for softened outer emphasis where needed.
- **Scroll indicators**: use native macOS scroll indicators where practical. For custom scroll containers, keep indicators narrow and muted, with `border50` or `mutedSubtle` styling.
- **Skeletons**: use rounded `muted` blocks with a pulse animation. Match final content geometry so loading does not shift layout.
- **Empty states**: use an icon-circle treatment: circular `primary8` or `accent` background, `primary` icon, concise title in `cardForeground`, one muted sentence, and one clear action when useful.
- **Toasts/HUD**: foreground SwiftUI HUD/toasts use `popover`, `popoverForeground`, and `border`, with `shadow-lg`, bottom-right placement, and short text. Use macOS `UserNotifications` only when the app is backgrounded or for recording/export completion and failure after notification permission is granted. Permission problems stay in onboarding/settings or foreground HUDs; do not directly model Sonner as a macOS notification system.
- **Dropdowns/popovers**: dense, Radix-like spacing; solid `popover`; 1px border; `shadow-md`; no fake browser/window chrome.

### Icon Style

- Use SF Symbols at 13-16 pt.
- Prefer hierarchical rendering.
- Primary action icons use `primary`; neutral icons use `foreground` or `mutedForeground`.
- Buttons with icons follow the button size matrix above.

### Brand Voice

- Direct, second-person, no jargon
- Short CTAs: verb + object, such as "Start recording", "Open file", "Copy file"
- No emojis, no em-dashes
- Avoid fake desktop/window metaphors inside real macOS chrome
- Assume the user is technical and uses AI daily

## Recording Architecture: Real-Time Queues + Lifecycle Actor

DemoLens v1 is internal local `.mov` tooling. It supports file-based sharing only; it does not upload recordings, authenticate with Promptable, or model recordings as cloud objects. The recording system is optimized for reliable local capture on macOS 14.

### Pipeline Overview

```text
RecordingCoordinator actor
  - lifecycle only: configure, start, pause, stop, fail, finish
  - creates queues, stream, audio engine, writer, compositor
  - does not receive every media callback

Named capture queues
  com.demolens.capture.screen
  com.demolens.capture.system-audio
  com.demolens.capture.microphone
        |
        v
+-----------------------------+
| SCStream video callback     |
| - validate frame metadata   |
| - handle .complete/.idle    |
|   status explicitly         |
| - drop invalid frames from  |
|   render path               |
| - never render, append, or  |
|   block                     |
+--------------+--------------+
               |
               v
       LatestVideoFrameMailbox
       (single retained complete frame)
               |
               v
com.demolens.render.video serial queue
  - check nonblocking writer video readiness snapshot before render
  - pull latest frame, coalescing older frames
  - snapshot latest webcam + cursor state
  - render Core Image into preallocated pool buffer
  - enqueue append at rebased source PTS
  - preserve original video timing, no synthetic 30fps
               |
               v
com.demolens.writer serial queue
  - owns AVAssetWriter and all input readiness checks
  - publishes latest video readiness snapshot for renderQueue
  - appends video, system audio, and microphone audio
  - drains bounded audio buffers while inputs are ready
  - finalizes .mov output

System audio:
SCStream audio callback
  - timestamp against same epoch
  - discard samples before epoch
  - buffer up to 100 ms if writer not ready
  - drop oldest audio beyond 100 ms

Microphone audio:
AVAudioEngine input tap
  - macOS 14 compatible mic capture
  - convert AVAudioTime.hostTime to same CMTime domain
  - timestamp against same epoch
  - discard samples before epoch
  - buffer up to 100 ms if writer not ready
  - drop oldest audio beyond 100 ms
```

### Key Technical Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Scope | Local `.mov` recorder only for v1 | Avoids cloud/auth/product-model work while proving capture quality |
| Minimum macOS | 14.0 Sonoma | Supports ScreenCaptureKit system audio and modern Swift concurrency |
| System audio | `SCStreamConfiguration.capturesAudio` | Native system audio capture from ScreenCaptureKit |
| Microphone audio | `AVAudioEngine` input-node tap | `SCStream` microphone capture is macOS 15+, so macOS 14 must capture mic separately |
| Sync epoch | First valid complete video frame PTS | One canonical epoch for video, system audio, and mic |
| Video timing | Surviving frames keep source PTS | Dropped frames do not shift the timeline or drift against audio |
| Backpressure | One-slot latest-frame mailbox for video | Slow render/write coalesces frames instead of building unbounded work |
| Audio backpressure | Per-track 100 ms bounded buffers | Preserves short writer stalls while capping memory and latency |
| Compositing | Core Image on dedicated serial render queue | `CIContext.render` is synchronous from the caller and must not run in callbacks |
| Pixel buffers | Preallocated `CVPixelBufferPool` of 3 | Bounds allocation latency and memory during recording |
| Coordination | Small `RecordingCoordinator` actor for lifecycle only | Start, stop, cancellation, and state transitions stay serialized without putting media on an actor hot path |
| UI state | `@MainActor` view models | UI remains isolated from real-time media queues |
| Writer | AVAssetWriter + H.264/AAC | Native hardware-accelerated `.mov` output |
| Webcam capture | AVCaptureSession | Standard API, device selection, works alongside ScreenCaptureKit |
| Mouse tracking | Timestamped `MouseEvent` stream from NSEvent local/global mouse monitors | One shared model drives live overlay and recorded effects so preview and output stay aligned |
| Cursor in video | `SCStreamConfiguration.showsCursor = true` + additive custom highlight | ScreenCaptureKit records the normal system cursor; Core Image only composites highlight rings and click animations over it |
| Global shortcut | User-configurable shortcut via `KeyboardShortcuts`, default `Ctrl+Cmd+R` | Real global hotkey registration, persistence, and conflict handling; avoids `Cmd+Shift+R` browser conflicts and `Cmd+Shift+5` screenshot UI |
| UI framework | SwiftUI + AppKit interop | SwiftUI for content, `MenuBarExtra`, Settings, and Recordings windows; AppKit for `NSPanel` and overlay windows |
| App type | Menu bar utility with companion windows | Compact status in the menu bar; full workflows in native windows |
| Sandboxing | Non-sandboxed for internal distribution by default | Distribution choice for v1 simplicity, not a permission bypass. TCC permissions remain explicit either way. |

### File Structure

```text
DemoLens/
  DemoLens.xcodeproj/
  DemoLens/
    App/
      DemoLensApp.swift                 # @main, MenuBarExtra scene
      AppState.swift                    # Global app state container

    ViewModels/
      RecordingViewModel.swift          # @MainActor, UI state + bindings
      PermissionViewModel.swift         # Permission check state
      SettingsViewModel.swift           # User preferences

    Services/
      RecordingCoordinator.swift        # Actor: lifecycle state machine only
      ScreenCaptureService.swift        # SCStream + SCStreamOutput
      MicrophoneCaptureService.swift    # AVAudioEngine input tap for macOS 14 mic
      WebcamCaptureService.swift        # AVCaptureSession for camera
      MouseTracker.swift                # NSEvent local/global monitors
      CursorEventStore.swift            # Timestamped MouseEvent ring buffer
      LatestVideoFrameMailbox.swift     # One-slot latest complete frame mailbox
      FrameCompositor.swift             # Core Image compositing on renderQueue
      VideoWriter.swift                 # writerQueue-owned AVAssetWriter + inputs
      WriterReadinessSnapshot.swift     # Atomic latest readiness state for renderQueue preflight
      BoundedAudioBuffer.swift          # 100 ms per-track audio buffering/drop policy
      DisplayThumbnailCache.swift       # SCScreenshotManager snapshots
      PermissionManager.swift           # Check/request all permissions

    Controllers/
      RecordingPanelController.swift    # Retained @MainActor NSPanel owner
      OverlayWindowController.swift     # Per-display countdown/cursor overlay windows

    Views/
      MenuBar/
        MenuBarView.swift               # Compact menu bar content
        DisplayPicker.swift             # Multi-monitor selector with cached thumbnails
        CameraPicker.swift              # Webcam device selector
      Recording/
        RecordingControlBar.swift       # Floating NSPanel content
        CountdownOverlay.swift          # 3-2-1 countdown
        CursorOverlayWindow.swift       # Transparent click-through preview overlay
      Onboarding/
        PermissionsView.swift           # First-launch permission guide
      Settings/
        SettingsView.swift              # Preferences (resolution, codec, hotkeys)
      Recordings/
        RecordingsWindow.swift          # Past recordings with open/delete

    Design/
      PromptableTheme.swift             # Color tokens, font styles, shadow modifiers
      Components/
        PTButton.swift                  # Promptable button variants
        PTCard.swift                    # Quiet card surface
        PTInteractiveCard.swift         # Clickable card with hover lift
        PTHUD.swift                     # Promptable-styled foreground HUD/toast
        PTSkeleton.swift                # Loading placeholder blocks

    Utilities/
      CoordinateConverter.swift         # Screen coords to display-relative pixels
      DisplayInfo.swift                 # Multi-monitor enumeration
      RecordingHotkeyService.swift      # Integrates KeyboardShortcuts package for user-configurable global recording shortcut
      FileManager+Recording.swift       # Output directory management

    Resources/
      Fonts/
        Manrope-Regular.ttf
        Manrope-Medium.ttf
        Manrope-SemiBold.ttf
        Manrope-Bold.ttf
        JetBrainsMono-Regular.ttf
        JetBrainsMono-Medium.ttf
      Assets.xcassets/
        AppIcon.appiconset/
        AccentColor.colorset/
      Info.plist                         # Usage strings + ATSApplicationFontsPath
      DemoLens.entitlements             # Internal distribution entitlements

  PLAN.md
```

### Real-Time Queue Model

SCStream outputs use explicit serial queues. The `AVAudioEngine` input tap does minimum realtime-safe work, retains/copies the buffer metadata needed for sync, and immediately forwards to the explicit microphone queue:

- `videoCallbackQueue` (`com.demolens.capture.screen`): receives screen frames only. It validates `SCStreamFrameInfo`, extracts timestamps/status, updates the latest valid frame mailbox, signals bounded render work, and returns immediately.
- `audioCallbackQueue` (`com.demolens.capture.system-audio`): receives ScreenCaptureKit system audio only. It validates sample timing, rebases accepted samples, deposits them into the system-audio bounded buffer, schedules writer drain work, and returns without waiting on video rendering.
- `micCallbackQueue` (`com.demolens.capture.microphone`): receives retained microphone buffers forwarded from the `AVAudioEngine` tap. It normalizes format/timing, rebases accepted samples, deposits them into the microphone bounded buffer, schedules writer drain work, and returns.
- `renderQueue` (`com.demolens.render.video`): performs Core Image composition from the latest screen, webcam, and cursor snapshots. It drops or coalesces video frames before render when behind.
- `writerQueue` (`com.demolens.writer`): owns `AVAssetWriter`, input readiness checks, appends, bounded audio buffer draining, finalization, stop padding, and the latest video readiness snapshot exposed to `renderQueue`.

The `RecordingCoordinator` actor owns lifecycle state only: start, pause, stop, error handling, and metrics snapshots. It does not serialize every media callback.

### Data Flow

```text
RecordingCoordinator actor
  - owns lifecycle: configure, start, pause, stop, fail, finish
  - creates queues, stream, audio engine, writer, compositor
  - does not receive every frame or serialize media callbacks

SCStream video output
  queue: videoCallbackQueue
  - read `SCStreamFrameInfo.status`
  - `.complete`: validate metadata and extract PTS and pixel buffer
  - if epoch is unset, atomically publish epoch = this complete video PTS and dispatch `writerQueue` once to start the writer session at `.zero`
  - deposit the latest complete frame into the one-slot mailbox and signal `renderQueue`
  - `.idle`: do not render as new visual content; preserve the last valid frame buffer and update duration/stop-padding state
  - incomplete, blank, or invalid frames: drop from the render path
  - return immediately

Render queue
  queue: renderQueue
  - skip work if already rendering
  - read and clear latest-frame mailbox
  - compute rebasedPTS = sourcePTS - epoch
  - read `WriterReadinessSnapshot.videoReady`
  - if not ready, drop frame before rendering
  - get output buffer from preallocated pool
  - composite screen + latest webcam + timestamped cursor/click snapshot
  - enqueue rendered buffer and rebasedPTS to writerQueue
  - if newer frame arrived while rendering, schedule another render pass

Writer queue video append
  queue: writerQueue
  - recheck `videoInput.isReadyForMoreMediaData`
  - if not ready, drop rendered buffer and increment `frames_dropped`
  - append rendered frame at rebasedPTS
  - update `WriterReadinessSnapshot.videoReady` after each append attempt

SCStream system audio output
  queue: audioCallbackQueue
  - ignore until epoch exists
  - discard samples whose PTS is earlier than epoch
  - rebase accepted samples against epoch
  - record first accepted sample offset for the system-audio track
  - enqueue in bounded 100 ms system-audio buffer
  - schedule writerQueue drain work
  - when buffer exceeds 100 ms, drop oldest samples and increment metrics

AVAudioEngine microphone tap
  realtime tap callback
  - retain/copy the buffer and AVAudioTime metadata needed for sync
  - dispatch immediately to micCallbackQueue

Microphone processing
  queue: micCallbackQueue
  - convert `AVAudioTime.hostTime` to CMTime in the host-time domain
  - ignore until epoch exists
  - discard samples whose PTS is earlier than epoch
  - rebase accepted samples against epoch
  - record first accepted sample offset for the microphone track
  - convert/normalize to writer format as needed
  - enqueue in bounded 100 ms microphone buffer
  - schedule writerQueue drain work
  - when buffer exceeds 100 ms, drop oldest samples and increment metrics

Writer queue audio drain
  queue: writerQueue
  - drain each track only while its `AVAssetWriterInput.isReadyForMoreMediaData` is true
  - keep buffers bounded to 100 ms per track
  - drop oldest samples beyond the cap and increment `audio_samples_dropped`

Cursor event stream
  MouseTracker -> CursorEventStore
  - local/global mouse move and button events with host-time timestamps
  - CursorOverlayWindow consumes same model for live preview
  - FrameCompositor samples same model by frame timestamp
```

### Cursor Event Model

`MouseEvent` is the single cursor truth for v1:

- `timestamp`: host-time aligned with the recording epoch
- `type`: move, leftDown, leftUp, rightDown, rightUp
- `globalLocation`: AppKit global screen coordinates
- `displayID`: resolved display for multi-monitor conversion
- `buttons`: current pressed-button state

The live overlay and compositor consume this same timestamped model. The overlay is preview-only UI; recorded output comes from ScreenCaptureKit's normal cursor plus compositor-added highlight/click effects.

### Overlay Windows

Cursor and countdown overlays are per-display borderless AppKit windows or non-activating panels:

- one overlay window per `NSScreen`
- `isOpaque = false`, clear background, `ignoresMouseEvents = true`
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`
- use `.statusBar` or `.screenSaver` level only where needed for countdown visibility
- update and recreate windows on display attach/detach or Spaces-related state changes
- resolve DemoLens overlay, countdown, and control `NSWindow`s to `SCWindow`s from `SCShareableContent`, then build/update the stream filter with `SCContentFilter(display: selectedDisplay, excludingWindows: excludedSCWindows)`

## Compositing Pipeline (Core Image)

The compositor runs only on `renderQueue`, a dedicated serial queue. It never runs inside an `SCStreamOutput` callback and never runs behind the lifecycle actor.

Per accepted video frame:

1. **Read source frame**: Pull the newest complete screen frame from the latest-frame mailbox.
2. **Preserve timing**: Use the frame's source PTS rebased against the single recording epoch. Do not derive timestamps from frame count and do not synthesize a fixed 30fps cadence.
3. **Check writer readiness**: If the latest writer readiness snapshot says video is not ready, drop the frame before rendering. The writer queue still rechecks `AVAssetWriterInput.isReadyForMoreMediaData` immediately before append.
4. **Allocate output buffer**: Create a `CVPixelBufferPool` with minimum count 3 and prewarm it by allocating 3 buffers before recording starts. If prewarm fails, fail startup. If no pool buffer is available during recording, drop the video frame before render and increment `frames_dropped`.
5. **Compose**:
   - screen base layer from `CIImage(cvPixelBuffer:)`
   - normal system cursor already captured by ScreenCaptureKit (`showsCursor = true`)
   - additive cursor highlight ring and click animation from `CursorEventStore`
   - optional circular webcam bubble from latest webcam snapshot
6. **Render**: Call `CIContext.render(_:to:)` on the render queue using a GPU-backed `CIContext`.
7. **Append**: Enqueue the rendered buffer to `writerQueue` with the rebased source PTS. If the writer queue recheck fails because the input is no longer ready, drop the rendered buffer and increment `frames_dropped`. If `append` returns false or the writer reports an error, fail the recording cleanly and report the writer error.

### Backpressure and Timing Rules

- `SCStream` video callbacks validate and deposit only. They never render, append, wait for writer readiness, call actor methods per frame, or block on queue work.
- The video mailbox stores only the latest complete frame. A newer complete frame replaces an older unrendered frame.
- Dropped video frames increment `frames_dropped`.
- Successfully appended video frames increment `frames_rendered`.
- Surviving video frames keep their original source PTS rebased to the epoch.
- There is no synthetic `1/30` timestamp generation for captured frames.
- Static periods are represented by source timing from ScreenCaptureKit. Preserve both the last valid source frame and the last rendered output buffer; on stop, append a final duplicate at the current rebased timestamp only if needed to preserve the final duration.
- `SCStreamConfiguration.queueDepth = 8`, the SDK default and documented upper recommendation. This is capture-side buffering only, not the application backpressure policy.

### Critical Edge Cases

- **Single recording epoch**: Establish one session start time for video, system audio, and microphone. Rebase all accepted media samples against that epoch.
- **Frame validation**: Process only `.complete` frames as new visual content. Keep incomplete/blank frames out of the render path.
- **Idle frames**: Treat `.idle` separately from invalid frames. `.idle` preserves the last valid source frame buffer and timestamp state; it does not clear the frame mailbox or produce new visual content.
- **Last frame padding**: On stop, append the last valid rendered output buffer, or render from the last valid source frame if needed, again at the current rebased timestamp so static screens produce the correct duration.
- **Writer backpressure**: Check `AVAssetWriterInput.isReadyForMoreMediaData` before every append. Drop/coalesce video before render when behind; keep audio buffering bounded at 100 ms.
- **Overlay exclusion**: Resolve DemoLens overlay/countdown/preview/control `NSWindow`s to `SCWindow`s from `SCShareableContent`, then build or update the stream filter with `SCContentFilter(display: selectedDisplay, excludingWindows: excludedSCWindows)`.

### Metrics

Record these counters for every session:

| Metric | Meaning |
|--------|---------|
| `frames_rendered` | Count of composited video frames successfully appended |
| `frames_dropped` | Count of complete video frames skipped because a newer frame replaced them, writer was not ready, no pool buffer was available, or render/append failed |
| `audio_samples_dropped` | Count of system-audio and microphone samples dropped because their bounded buffers exceeded 100 ms |
| `latest_frame_replacements` | Complete video frames replaced in the one-slot mailbox before render |
| `render_latency_p50_p95` | Core Image render duration percentiles |
| `append_latency_p50_p95` | `writerQueue` append duration percentiles |
| `writer_not_ready_video` | Count of video frames dropped because the video input was not ready |
| `audio_buffered_ms_system` / `audio_buffered_ms_mic` | Current bounded audio buffer depth by track |

## Audio Capture and Sync

DemoLens writes system audio and microphone audio as separate AAC tracks in the local `.mov`.

### Sources

- **System audio**: ScreenCaptureKit with `SCStreamConfiguration.capturesAudio = true`.
- **Microphone**: `AVAudioEngine` input-node tap. Do not use `SCStreamConfiguration.captureMicrophone` for macOS 14 because that API is macOS 15+.

### Single Epoch

The recording epoch is the PTS of the first valid complete video frame.

Rules:

- Do not start timestamp rebasing from the first audio sample.
- Do not use different epochs per track.
- Ignore incomplete, idle, or invalid video frames when selecting the epoch.
- Discard all system-audio and microphone samples earlier than the epoch.
- Rebase every accepted video, system-audio, and microphone sample as `samplePTS - epoch`.
- Start the `AVAssetWriter` session at `.zero`; all appended media uses rebased timestamps.
- Record `systemAudioStartOffset` and `microphoneStartOffset` as each track's first accepted sample PTS minus `epoch`, so delayed source start is observable in metrics/debug output.
- If a source starts late, append its samples at their rebased timestamps without shifting video or the other audio track.

### Microphone Timestamping

`AVAudioEngine` mic buffers must be timestamped against the same host-time domain as ScreenCaptureKit.

- Prefer `AVAudioTime.hostTime` from the tap callback.
- Convert host time to `CMTime` using the mach timebase.
- If a mic callback lacks a usable host time, fail microphone capture for that recording rather than appending unsynchronized samples.
- Normalize mic format before writing so the writer receives stable sample rate, channel count, and AAC-compatible buffers.

### Audio Backpressure

Each audio track has a bounded buffer of at most 100 ms of audio.

- Audio capture queues enqueue accepted samples into the track's bounded buffer and schedule `writerQueue` drain work.
- If the corresponding writer input is ready, `writerQueue` drains and appends samples in timestamp order.
- If not ready, samples stay queued until the track reaches 100 ms buffered.
- If the buffer would exceed 100 ms, drop oldest samples first.
- Surviving audio samples keep their rebased source PTS; do not renumber, compact, or close timing gaps after a drop.
- Increment `audio_samples_dropped` by the dropped sample count.
- Audio callbacks must not block on video rendering, the lifecycle actor, or writer readiness.

## macOS Permissions and Distribution

| Permission | API | Can auto-prompt? | v1 behavior |
|------------|-----|------------------|-------------|
| Screen Recording | `CGPreflightScreenCaptureAccess()` then `CGRequestScreenCaptureAccess()` | Can request, may still require System Settings and restart | Show guided settings fallback |
| Camera | `AVCaptureDevice.requestAccess(for: .video)` | Yes | No camera = no PiP bubble |
| Microphone | `AVCaptureDevice.requestAccess(for: .audio)` / AVAudioEngine input | Yes | No mic = system audio only |
| Accessibility | `AXIsProcessTrustedWithOptions(prompt: true)` | Partial | No accessibility = no click/cursor highlight, normal cursor still records |
| Notifications | `UNUserNotificationCenter.requestAuthorization` | Yes | Used for background completion/failure only |

Non-sandboxed v1 distribution is a practical internal tooling choice, not a permission bypass. Screen Recording, Camera, Microphone, Accessibility, and Notifications still need explicit user consent. Re-evaluate sandboxing, hardened runtime, notarization, and App Store constraints before any external distribution.

## UI Architecture

### Menu Bar and Windows

- `MenuBarExtra` stays compact: recording status, start/stop, selected display/camera summary, and latest recording shortcut.
- Full Settings live in a SwiftUI `Settings {}` scene.
- Full Recordings browser lives in a separate `WindowGroup`.
- Display picker thumbnails are generated from cached `SCScreenshotManager` snapshots after Screen Recording permission is granted. Before permission, show stable placeholders with display names/resolutions only. Generate thumbnails lazily, cache them by display ID, and invalidate on display reconfiguration or permission changes.

### Floating Panel Ownership

Recording controls live in an `NSPanel` owned by a retained `@MainActor` panel controller. Recording-critical state lives outside the panel in app-level view models/services. When creating the `NSHostingController`, inject dependencies explicitly with `.environmentObject(...)`. During an active recording, closing the panel hides it; it must not deallocate the controller or reset `@StateObject` state.

### Hotkey Strategy

Use the `KeyboardShortcuts` Swift package by sindresorhus, backed by real system hotkey registration. The default shortcut is `Ctrl+Cmd+R`. The shortcut is user-configurable in Settings, registration failures are surfaced in the UI, and the active shortcut is shown anywhere recording controls appear.

Do not implement the recording hotkey with `NSEvent.addGlobalMonitorForEvents`. Avoid `Cmd+Shift+R` because it conflicts with browser reload habits. Avoid `Cmd+Shift+5` because it invokes macOS screenshot/recording UI.

## Implementation Phases (for Codex)

### Phase 1: Skeleton + Core Recording

- Create Xcode project (SwiftUI App, internal distribution)
- PermissionManager with all required permission checks
- ScreenCaptureService (`SCStream` + `SCStreamOutput`)
- Explicit `videoCallbackQueue`, `renderQueue`, and `writerQueue`
- LatestVideoFrameMailbox and lifecycle-only RecordingCoordinator
- VideoWriter (AVAssetWriter, H.264, MOV)
- Wire complete screen frames directly to writer with readiness checks
- Result: records screen to `.mov` file

### Phase 2: Audio

- System audio via `SCStreamConfiguration.capturesAudio`
- Microphone via `AVAudioEngine` input tap for macOS 14 compatibility
- Dedicated `audioCallbackQueue` and `micCallbackQueue`
- Normalize sample rate, channel layout, and format before writing
- Establish single epoch from first valid complete video frame
- Discard audio samples received before epoch
- Buffer each audio track up to 100 ms when writer input is not ready, then drop oldest samples
- Separate audio tracks in AVAssetWriter
- Test system-only, mic-only, both-sources, and delayed-device-start cases

### Phase 3: Webcam Overlay

- WebcamCaptureService (`AVCaptureSession`)
- Latest webcam frame snapshot with timestamp
- FrameCompositor with CIImage pipeline on `renderQueue`
- Circular webcam mask with Core Image
- Composite webcam bubble onto screen frames
- Preserve video source timestamps while compositing

### Phase 4: Cursor Effects

- Set `SCStreamConfiguration.showsCursor = true` so the recorded `.mov` contains the normal macOS cursor
- MouseTracker captures mouse move/down/up events with NSEvent local/global mouse monitors
- Introduce shared timestamped `MouseEvent` model and `CursorEventStore` ring buffer
- CursorOverlayWindow consumes `CursorEventStore` for live preview feedback
- FrameCompositor samples `CursorEventStore` by video frame timestamp and draws additive highlight/click effects only
- Cursor highlight ring uses CIRadialGradient at the converted cursor position, teal normally and red/expanded/fading on click
- Coordinate conversion handles AppKit global points, display bounds, backing scale, and captured display-relative pixels
- Create overlay windows per display and exclude DemoLens overlay/countdown/control windows from ScreenCaptureKit by resolving them to `SCWindow`s and rebuilding the filter with `SCContentFilter(display: selectedDisplay, excludingWindows: excludedSCWindows)`

### Phase 5: UI (Promptable Visual Language)

- PromptableTheme.swift with all verified color tokens and font styles
- Compact MenuBarExtra: status, start/stop, selected display/camera summary, and latest recording shortcut
- Full Settings in a SwiftUI `Settings {}` scene
- Full Recordings browser in a separate `WindowGroup`
- Display picker with cached `SCScreenshotManager` thumbnails, placeholders, and lazy refresh
- Camera + mic device pickers
- Record button using `PTButton` default variant and press animation
- Implement full `PTButton` variants (`default`, `destructive`, `outline`, `secondary`, `ghost`, `link`) and sizes (`sm`, `md`, `lg`, `icon`) with exact Promptable shadows and 150 ms press animation
- Implement `PTCard` as the quiet base surface and `PTInteractiveCard` as the only hover/lift card variant
- Implement reusable focus-ring, custom scroll-indicator, skeleton, empty-state, and HUD/toast patterns from the support-pattern section
- Retained floating `NSPanel` controller for stop/pause/timer controls
- Countdown overlay with per-display overlay windows
- SwiftUI HUD overlay for foreground events
- macOS UserNotifications for background completion/failure
- Onboarding permissions flow

### Phase 6: Polish

- User-configurable global recording shortcut via `KeyboardShortcuts`, default `Ctrl+Cmd+R`
- Metrics HUD or debug log for `frames_rendered`, `frames_dropped`, and `audio_samples_dropped`
- Settings for resolution, frame rate, output directory, cursor highlight color/size, and PiP position
- App icon designed in Promptable style
- System tray icon changes during recording (red dot)
- Post-recording: auto-reveal in Finder, copy file to clipboard
- Multi-monitor tests with display attach/detach, full-screen apps, and separate Spaces

## Future Scope: v2: Promptable Integration

These items cover REVIEW findings 5, 6, 7, 16, 17, and 18. They are intentionally out of scope for v1 and are not blocking the local recorder:

- Promptable discovery path in web navigation or marketing
- Native Promptable auth bridge, app tokens, deep links, or universal links
- Cloud upload to Promptable storage
- Recording object model, web player, share URLs, processing jobs, transcripts, thumbnails, or org ownership
- Recording-specific upload contexts and larger/resumable upload APIs
- Attach recording to a prompt, skill, feedback item, project, or org workflow
- Promptable notification bell events for recording lifecycle

## Reference Implementations

Study these for patterns (do NOT copy code):

- **EasyDemo** (github.com/danieloquelis/EasyDemo): Closest match. Loom-style, Core Image compositing, webcam overlay, MVVM.
- **Nonstrict ScreenCaptureKit-Recording-example**: Canonical AVAssetWriter + SCStream with edge cases handled (timestamp rebasing, last-frame padding).
- **Capso** (github.com/lzhgus/Capso): Modular Swift 6 architecture with 8 SPM packages.
- **QuickRecorder** (github.com/lihaoyun6/QuickRecorder): Cursor highlighting, presenter overlay, multi-display.
- **Cap** (github.com/CapSoftware/Cap): Open-source Loom alternative. Different stack (Rust) but good product design reference.
- **KeyboardShortcuts** (github.com/sindresorhus/KeyboardShortcuts): User-customizable macOS global shortcuts.

## Verification

After each phase, test:

1. **Phase 1**: Record 30s of screen, play back in QuickTime. Verify smooth output, correct resolution, no unbounded queue growth, and accurate frame metrics.
2. **Phase 2**: Record with system audio, microphone, and both together. Verify A/V sync, correct epoch rebasing, and bounded audio drop metrics under writer stalls.
3. **Phase 3**: Record with webcam, verify circular bubble appears in bottom-right, no frame drops beyond expected backpressure behavior.
4. **Phase 4**: Record while moving mouse across displays, verify the normal cursor is visible and teal highlight ring follows. Click and verify animation. Confirm overlay windows are not captured.
5. **Phase 5**: Verify Promptable visual language: accurate dark tokens, teal accents, solid dark surfaces, Manrope font, hairline shadows, button variants, focus rings, skeletons, and HUDs.
6. **Phase 6**: Test global hotkey registration, multi-monitor switching, display attach/detach, full-screen apps, countdown visibility, post-recording file reveal, and background notifications.

## Repo Setup

Create `seisenstein/demolens` on GitHub with this PLAN.md as the initial commit. Ready for Codex to start Phase 1.
