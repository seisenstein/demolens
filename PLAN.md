# DemoLens: Native macOS Screen Demo Recorder

## Context

Sean needs to record walkthrough demos of AI tools (Promptable, Claude, Codex) for the neurocollective team. Loom does this but costs money. A native Swift macOS app is the right call: ScreenCaptureKit gives direct GPU-level screen frames, Core Image composites overlays on the GPU, and AVAssetWriter outputs H.264 MOV natively. No Electron bloat, no FFmpeg, no background throttling hacks. The app should look and feel like Promptable built it, applying their teal-on-black design language to a SwiftUI interface.

## What Gets Built

A native macOS menu bar app (Swift 6, SwiftUI, ScreenCaptureKit) that:
- Records any display with ScreenCaptureKit (SCStream)
- Composites a circular webcam PiP bubble via Core Image (GPU-accelerated)
- Draws a cursor highlight ring + click animations via Core Image
- Captures system audio + microphone as separate tracks
- Outputs H.264 MOV directly via AVAssetWriter (no conversion step)
- Lives in the menu bar with a floating recording control panel
- Applies Promptable's design language (teal #2c8a9d on near-black, Manrope font, hairline shadows, glassmorphic surfaces)

## Promptable Design Language (for SwiftUI translation)

Extracted from `/Users/sean/Promptable_Technologies/`:

### Colors (OKLCH-derived, dark mode only)
| Token | Hex | Use |
|-------|-----|-----|
| Background (canvas) | `#0f1214` | App background, teal undertone |
| Card surface | `#1a1f22` | Elevated panels, cards |
| Surface elevated | `#212830` | Popovers, modals, control bar |
| Primary teal | `#2c8a9d` | Accent, active states, icons |
| Primary button | `#1a7080` | Solid teal button backgrounds (darker for contrast) |
| Primary hover | `#15606e` | Button hover/press |
| Text foreground | `#c8c5bf` | Body text (warm off-white) |
| Text bright | `#f5f5f0` | Headings, card titles (near-white) |
| Text muted | `#b5b0a5` | Secondary text, labels |
| Border | `#444444` | Neutral dividers |
| Hairline | `rgba(255,255,255,0.05)` | Inset top-edge highlight on surfaces |
| Hairline strong | `rgba(255,255,255,0.08)` | Inset highlight on interactive elements |
| Destructive | `#d94040` | Stop/cancel |
| Primary 10% | `rgba(44,138,157,0.10)` | Active item backgrounds |
| Primary 30% | `rgba(44,138,157,0.30)` | Tag/pill borders |

### Typography
- **Sans (UI)**: Manrope (bundle .ttf, weights 400/500/600/700)
- **Mono (timer/data)**: JetBrains Mono (bundle .ttf, weights 400/500)
- **Heading weight**: 650 with tight tracking (-0.03em)
- **Body**: 14-16pt, weight 400, relaxed line height

### Signature Patterns for SwiftUI
1. **Hairline inset highlights**: Every elevated surface gets a 1px white top-edge at 5% opacity (use `.overlay(alignment: .top)` with a 1pt Rectangle)
2. **Button press**: `.scaleEffect(isPressed ? 0.985 : 1.0)` with 150ms animation
3. **Teal glow on hover**: `shadow(color: teal.opacity(0.3), radius: 12)` on primary buttons
4. **Card lift on hover**: shadow-sm to shadow-md transition
5. **Glassmorphic containers**: `.ultraThinMaterial` + teal gradient overlay at 15% opacity
6. **Rounded corners**: 8pt base (cards: 12pt, buttons: 6pt, pills: full)
7. **Icon style**: SF Symbols at 13-16pt, `symbolRenderingMode(.hierarchical)` with teal tint

### Brand Voice (for UI copy)
- Direct, second-person, no jargon
- Short CTAs: verb + object ("Start recording", "Open file", "Copy link")
- No emojis, no em-dashes
- Assume the user is technical and uses AI daily

## Architecture: Actor-Based MVVM

### Pipeline Overview

```
ScreenCaptureKit (SCStream)  -->  CVPixelBuffer (screen frame)
AVCaptureSession             -->  CIImage (webcam frame)
NSEvent global monitors      -->  CGPoint (cursor position)
                                       |
                                       v
                              FrameCompositor (Core Image, GPU)
                              - Draw screen base layer
                              - Draw cursor highlight ring (CIRadialGradient)
                              - Draw circular webcam bubble (CIBlendWithAlphaMask)
                                       |
                                       v
                              AVAssetWriter (H.264, hardware-accelerated)
                              - Video track (composited frames)
                              - System audio track
                              - Microphone audio track
                                       |
                                       v
                              Output: .mov file, ready to share
```

### Key Technical Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Compositing engine | Core Image (CIFilter) | GPU-accelerated via Metal, built-in filters for masking/compositing, handles 30fps 1080p easily on Apple Silicon |
| Video encoding | AVAssetWriter + H.264 | Hardware-accelerated, universal compatibility, outputs MOV directly (no conversion) |
| Webcam capture | AVCaptureSession | Standard API, device selection, works alongside ScreenCaptureKit |
| Mouse tracking | NSEvent.addGlobalMonitorForEvents | Push-based, captures clicks, simpler than CGEventTap |
| Architecture | Actor-based MVVM | Thread safety for multi-source pipeline (CMSampleBuffers arrive on arbitrary queues) |
| UI framework | SwiftUI + AppKit interop | SwiftUI for views, NSPanel for floating controls, MenuBarExtra for menu bar |
| App type | Menu bar utility (MenuBarExtra) | Non-intrusive, always accessible, Loom-like UX |
| Sandboxing | Non-sandboxed | Required for Accessibility APIs + full ScreenCaptureKit access |
| Minimum macOS | 14.0 (Sonoma) | Native microphone capture in SCStream, modern Swift concurrency |
| Cursor in video | showsCursor = false + custom highlight | System cursor composited by ScreenCaptureKit looks normal; we want the highlight ring instead |
| Output format | MOV (H.264 video, AAC audio) | Native, no conversion step, universally playable |

### File Structure

```
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
      RecordingCoordinator.swift        # Actor: orchestrates entire pipeline
      ScreenCaptureService.swift        # SCStream + SCStreamOutput
      WebcamCaptureService.swift        # AVCaptureSession for camera
      MouseTracker.swift                # NSEvent global monitors
      FrameCompositor.swift             # Core Image compositing pipeline
      VideoWriter.swift                 # Actor: AVAssetWriter + H.264
      PermissionManager.swift           # Check/request all 4 permissions

    Views/
      MenuBar/
        MenuBarView.swift               # MenuBarExtra content (settings, record button)
        DisplayPicker.swift             # Multi-monitor selector with thumbnails
        CameraPicker.swift              # Webcam device selector
      Recording/
        RecordingControlBar.swift       # Floating NSPanel (stop/pause/timer)
        CountdownOverlay.swift          # 3-2-1 countdown
        CursorOverlayWindow.swift       # Transparent click-through overlay
      Onboarding/
        PermissionsView.swift           # First-launch permission guide
      Settings/
        SettingsView.swift              # Preferences (resolution, codec, hotkeys)
      Recordings/
        RecordingsListView.swift        # Past recordings with open/delete

    Design/
      PromptableTheme.swift             # Color tokens, font styles, shadow modifiers
      Components/
        PTButton.swift                  # Promptable-styled button variants
        PTCard.swift                    # Card with hairline inset shadow
        PTControlBar.swift              # Glassmorphic floating bar

    Utilities/
      CoordinateConverter.swift         # Screen coords to display-relative pixels
      DisplayInfo.swift                 # Multi-monitor enumeration
      KeyboardShortcuts.swift           # Global hotkey registration
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
      Info.plist                         # Camera + Mic usage descriptions
      DemoLens.entitlements             # Non-sandboxed

  PLAN.md                               # This file
```

### IPC / Data Flow

```
MouseTracker (@Published position, isClicking)
  |
  +---> CursorOverlayWindow (live visual feedback for user)
  +---> RecordingCoordinator -> FrameCompositor (baked into video)

ScreenCaptureService (SCStreamOutput callback, arbitrary queue)
  |
  +---> RecordingCoordinator (actor, serializes access)
        |
        +---> FrameCompositor.compositeFrame(screen, webcam, cursor)
        |     |
        |     +---> VideoWriter.appendVideo(composited, timestamp)
        |
        +---> VideoWriter.appendAudio(systemAudio)
        +---> VideoWriter.appendAudio(microphone)

RecordingCoordinator.state changes
  |
  +---> RecordingViewModel (@MainActor, @Published)
        |
        +---> MenuBarView (record button state)
        +---> RecordingControlBar (timer, stop/pause)
        +---> System tray icon (recording indicator)
```

## Compositing Pipeline (Core Image)

Per frame at 30fps:

1. **Screen frame**: `CIImage(cvPixelBuffer: screenBuffer)` from SCStreamOutput
2. **Cursor highlight**: CIRadialGradient ring at mouse position (teal for normal, red for clicking), composited over screen
3. **Webcam bubble**: Scale + center-crop webcam to square, apply circular CIRadialGradient mask via CIBlendWithAlphaMask, add drop shadow, position at bottom-right, composite over
4. **Output**: `CIContext.render(composited, to: outputPixelBuffer)`, append to AVAssetWriter

The CIContext forces GPU rendering (`useSoftwareRenderer: false`). At 1080p 30fps on Apple Silicon, this pipeline uses minimal CPU.

### Critical Edge Cases
- **Timestamp rebasing**: SCStream uses system uptime timestamps. Rebase to zero by storing the first timestamp and subtracting.
- **Last frame padding**: When stopping, repeat the last frame at the current time. ScreenCaptureKit only sends frames when pixels change.
- **Frame validation**: Check `SCStreamFrameInfo.status == .complete` before processing. Drop incomplete/idle/blank frames.
- **Queue depth**: Set `SCStreamConfiguration.queueDepth = 6` (minimum 4) to prevent stutter.

## macOS Permissions (4 required)

| Permission | API | Can auto-prompt? |
|------------|-----|-----------------|
| Screen Recording | `CGRequestScreenCaptureAccess()` | No, directs to System Settings |
| Camera | `AVCaptureDevice.requestAccess(for: .video)` | Yes |
| Microphone | `AVCaptureDevice.requestAccess(for: .audio)` | Yes |
| Accessibility | `AXIsProcessTrustedWithOptions(prompt: true)` | Partial (shows dialog linking to Settings) |

Graceful degradation: no camera = no PiP bubble, no accessibility = no cursor highlight, no mic = system audio only.

## Implementation Phases (for Codex)

### Phase 1: Skeleton + Core Recording
- Create Xcode project (SwiftUI App, non-sandboxed)
- PermissionManager with all 4 permission checks
- ScreenCaptureService (SCStream + SCStreamOutput)
- VideoWriter (AVAssetWriter, H.264, MOV)
- Wire screen frames directly to writer (no compositing yet)
- Result: records screen to .mov file

### Phase 2: Audio
- System audio via `SCStreamConfiguration.capturesAudio`
- Microphone via `SCStreamConfiguration.captureMicrophone` (macOS 14+)
- Separate audio tracks in AVAssetWriter
- Test A/V sync

### Phase 3: Webcam Overlay
- WebcamCaptureService (AVCaptureSession)
- FrameCompositor with CIImage pipeline
- Circular webcam mask (CIRadialGradient + CIBlendWithAlphaMask)
- Composite webcam bubble onto screen frames
- Switch from direct buffer writing to composited writing

### Phase 4: Cursor Effects
- MouseTracker (NSEvent global + local monitors)
- Cursor highlight ring (CIRadialGradient at cursor position, teal color)
- Click animation (expanding/fading ring, red on click)
- Coordinate conversion for multi-monitor
- Optional: transparent overlay window for live preview

### Phase 5: UI (Promptable Design Language)
- PromptableTheme.swift with all color tokens and font styles
- MenuBarExtra with rich window content
- Display picker (multi-monitor thumbnails)
- Camera + mic device pickers
- Record button (big, teal, with press animation)
- FloatingPanel (NSPanel) for recording controls (stop/pause/timer)
- Countdown overlay (3...2...1)
- Recordings list with open/delete actions
- Onboarding permissions flow

### Phase 6: Polish
- Global keyboard shortcut (Cmd+Shift+R) via addGlobalMonitorForEvents
- Settings (resolution, framerate, output directory, cursor highlight color/size, PiP position)
- App icon designed in Promptable style
- System tray icon changes during recording (red dot)
- Post-recording: auto-reveal in Finder, copy file to clipboard

### Phase 7: Sharing (future)
- Upload to cloud storage (S3/Supabase Storage)
- Generate shareable link
- Simple web player page
- Could integrate with Promptable's infrastructure

## Reference Implementations

Study these for patterns (do NOT copy code):
- **EasyDemo** (github.com/danieloquelis/EasyDemo): Closest match. Loom-style, Core Image compositing, webcam overlay, MVVM.
- **Nonstrict ScreenCaptureKit-Recording-example**: Canonical AVAssetWriter + SCStream with edge cases handled (timestamp rebasing, last-frame padding).
- **Capso** (github.com/lzhgus/Capso): Modular Swift 6 architecture with 8 SPM packages.
- **QuickRecorder** (github.com/lihaoyun6/QuickRecorder): Cursor highlighting, presenter overlay, multi-display.
- **Cap** (github.com/CapSoftware/Cap): Open-source Loom alternative. Different stack (Rust) but good product design reference.

## Verification

After each phase, test:
1. **Phase 1**: Record 30s of screen, play back in QuickTime. Verify smooth 30fps, correct resolution.
2. **Phase 2**: Record with audio, verify system sounds + mic voice are captured. Check A/V sync.
3. **Phase 3**: Record with webcam, verify circular bubble appears in bottom-right, no frame drops.
4. **Phase 4**: Record while moving mouse across screen, verify teal highlight ring follows. Click and verify animation.
5. **Phase 5**: Verify Promptable design language: teal accents, dark surfaces, Manrope font, hairline shadows, button press effects.
6. **Phase 6**: Test global hotkey, multi-monitor switching, countdown, post-recording file reveal.

## Repo Setup

Create `seisenstein/demolens` on GitHub with this PLAN.md as the initial commit. Ready for Codex to start Phase 1.
