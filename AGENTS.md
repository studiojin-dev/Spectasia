# PROJECT KNOWLEDGE BASE

**Generated:** 2026-01-28
**Commit:** n/a
**Branch:** n/a

## OVERVIEW
macOS image viewer & manager with AI-powered tagging, non-destructive XMP metadata, Gypsum design system. Swift 6.2 + SwiftUI + Vision Framework.

## STRUCTURE
```
./
├── Core/           # SpectasiaCore package services (8 files)
├── UI/             # SwiftUI views + Gypsum design system (8 files)
├── Tests/          # SpectasiaCore package tests
├── Resources/      # Assets, localization
├── Spectasia/      # App target source
└── SpectasiaApp.swift # @main entry point
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| App entry | `SpectasiaApp.swift` | SwiftUI @main |
| Core services | `Core/*.swift` | All services (Config, Monitor, XMP, Thumbnail, AI, Repo, Permission) |
| UI components | `UI/*.swift` | Views, design system |
| Design tokens | `UI/GypsumDesignSystem.swift` | Colors, fonts, GypsumCard, GypsumButton |
| Package definition | `Package.swift` | Swift 6.2, macOS 13+, SpectasiaCore library |
| Tests | `Tests/SpectasiaCoreTests/*.swift` | TDD for all services |

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
- **Non-destructive metadata**: XMP sidecars only, never modifies original images
- **Security-Scoped Bookmarks**: macOS sandboxing with persistent folder access
- **Actor-based background**: `BackgroundCoordinator` actor for task scheduling

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
- **GUI disconnected**: Core services fully implemented but UI not wired up. `ContentView` is placeholder ("Hello, world!")
- **Test coverage**: High - 34 tests covering all core services
- **Permission flow**: `PermissionManager.requestDirectoryAccess()` → NSOpenPanel → bookmark saved to UserDefaults
- **Entry point**: `SpectasiaApp` struct with `@main`, renders `ContentView()`
