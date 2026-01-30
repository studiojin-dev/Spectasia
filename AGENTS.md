# PROJECT KNOWLEDGE BASE

**Generated:** 2026-01-28
**Last Updated:** 2026-01-30
**Commit:** n/a
**Branch:** n/a

## OVERVIEW
macOS image viewer & manager with AI-powered tagging, non-destructive XMP metadata, Gypsum design system. XMP + thumbnails are stored under app-managed storage (not in original folders). Swift 6.2 + SwiftUI + Vision Framework.

## STRUCTURE
```
./
├── SpectasiaCore/            # SwiftPM package
│   ├── Sources/Core/         # Core services (12 files)
│   └── Tests/CoreTests/      # Core tests (9 files)
├── UI/                       # SwiftUI views + Gypsum design system
├── Resources/                # Assets, localization
├── Spectasia/                # App target resources
├── SpectasiaApp.swift         # @main entry point
└── Spectasia.xcodeproj        # Xcode project
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| App entry | `SpectasiaApp.swift` | SwiftUI @main |
| Core services | `SpectasiaCore/Sources/Core/*.swift` | All services (Config, Monitor, XMP, Thumbnail, AI, Repo, Permission) |
| UI components | `UI/*.swift` | Views, design system |
| Design tokens | `UI/GypsumDesignSystem.swift` | Colors, fonts, GypsumCard, GypsumButton |
| Package definition | `Package.swift` | Swift 6.2, macOS 13+, SpectasiaCore library |
| Tests | `SpectasiaCore/Tests/CoreTests/*.swift` | TDD for all services |

## CODE MAP
*(LSP unavailable - skipped)*

## CONVENTIONS
- **Package structure**: Swift Package Manager (`Package.swift`) for `SpectasiaCore` library
- **SwiftUI views**: Separate from Core package, in `UI/` directory
- **TDD**: All core services have corresponding test files in `Tests/`
- **Design system**: Gypsum aesthetic defined in `UI/GypsumDesignSystem.swift` (colors, fonts, components)
- **Permissions**: Security-Scoped Bookmarks via `PermissionManager` class
- **Metadata**: Non-destructive XMP sidecars only
- **Language**: `AppLanguage` enum (en, ko), persisted in `AppConfig`

## ANTI-PATTERNS (THIS PROJECT)
*(None detected in analysis)*

## UNIQUE STYLES
- **Gypsum Design System**: Custom SwiftUI components with matte finish, soft shadows
- **Non-destructive metadata**: XMP sidecars only, stored in app-managed directory
- **Security-Scoped Bookmarks**: macOS sandboxing with persistent folder access
- **Actor-based background**: `BackgroundCoordinator` actor for task scheduling

## CURRENT IMPLEMENTATION STATUS (2026-01-30)
- **Core**: All services implemented with tests; `ImageRepository` exposes `ObservableImageRepository`; XMP supports ratings/tags only; AI is basic `VNClassifyImageRequest`; `MetadataStore` manages XMP/thumbnail paths + index.
- **UI**: `ContentView` wired to Core; `SpectasiaLayout` provides 3-panel shell with Settings sheet; `ImageGridView` loads thumbnails and binds selection; `SingleImageView` loads and displays a single image; detail panel shows `MetadataPanel` when selection exists.
- **Gaps**: list view is a simple row list; SingleImageView lacks zoom/pan/filmstrip; metadata panel is read-only for tags; file-monitor UI auto-refresh is incomplete.

## PLAN SUMMARY (Updated from .sisyphus)
- **Phase 1 (Core-UI wiring)**: Remove sample data path; wire selection + metadata panel; propagate file monitor events to UI; improve loading/error states.
- **Phase 2 (View modes)**: Proper list view table; single image filmstrip + zoom/pan; view-mode switching + thumbnail size controls.
- **Phase 3 (AI expansion)**: Faces/animals/objects/mood; auto analysis mode; progress tracking.
- **Phase 4 (Albums)**: XMP album metadata; tag/date/location/people/pets album views.
- **Phase 5 (UX)**: Gestures, menu bar commands, keyboard shortcuts, background progress UI.
- **Phase 6 (Tech)**: ICC/HDR handling, cache cleanup/LRU, robust XMP parsing.

## COMMANDS
```bash
# Build Core package
swift build

# Run tests (34 tests total)
swift test

# Build GUI (requires Xcode)
open Spectasia.xcodeproj  # Press ⌘R
```

## NOTES
- **GUI wiring started**: `ContentView` and `SpectasiaLayout` are connected to Core services, but several UI panels remain placeholders or partial.
- **Test coverage**: Core tests present in `SpectasiaCore/Tests/CoreTests/` (count may differ from older docs).
- **Permission flow**: `PermissionManager.requestDirectoryAccess()` → security-scoped bookmark storage via `AppConfig`.
- **Entry point**: `SpectasiaApp` creates `AppConfig`, `ObservableImageRepository`, `PermissionManager` and injects them via `.environmentObject`.
