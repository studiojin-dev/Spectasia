# UI MODULE

## OVERVIEW
SwiftUI views + Gypsum design system for Spectasia GUI.

## STRUCTURE
```
UI/
├── GypsumDesignSystem.swift    # Design tokens + reusable components
├── ContentView.swift            # Main view (wired to Core)
├── ImageGridView.swift         # Thumbnail grid gallery
├── ImageListView.swift         # Table list view (columns)
├── SingleImageView.swift        # Single image viewer (basic load/display)
├── MetadataPanel.swift        # Rating, tags panel (partial)
├── SettingsView.swift         # App settings (AppConfig bindings)
├── DirectoryPicker.swift      # Folder selection UI
└── SpectasiaLayout.swift      # Three-panel layout (sidebar, grid, detail)
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Design tokens | `GypsumDesignSystem.swift` | Colors, fonts, GypsumCard, GypsumButton |
| Main view | `ContentView.swift` | Wired to `ObservableImageRepository`, `AppConfig`, `PermissionManager` |
| Image gallery | `ImageGridView.swift` | LazyVGrid with async thumbnails |
| Image viewer | `SingleImageView.swift` | Basic image load/display (no zoom/pan yet) |
| Metadata editor | `MetadataPanel.swift` | Rating writeback + tag display only |
| Settings | `SettingsView.swift` | AppConfig bindings (metadata storage/language/AI) |
| Folder selection | `DirectoryPicker.swift` | UI wrapper for PermissionManager |
| Layout | `SpectasiaLayout.swift` | Three-panel shell with sidebar + content + detail metadata |

## CONVENTIONS
- **Gypsum aesthetic**: `GypsumColor.*` colors, `GypsumFont.*` fonts
- **Reusable components**: `GypsumCard`, `GypsumButton` for consistent styling
- **Matte finish**: `shadow(color: Color.black.opacity(...))` for subtle depth
- **Corner radius**: 8px (buttons), 12px (cards)

## ANTI-PATTERNS
*(See root AGENTS.md)*

## UNIQUE STYLES
- **Design system first**: Centralized tokens (`GypsumColor`, `GypsumFont`)
- **Component library**: Reusable `GypsumCard`, `GypsumButton` with shadows
- **Three-panel layout**: Sidebar (folders) + Grid (thumbnails) + Detail (metadata)

- ## CURRENT IMPLEMENTATION STATUS (2026-01-30)
- **Wired**: `ContentView` drives `SpectasiaLayout`, now wired to `DirectoryScanManager` so selections stay in sync while directories auto-scan.
- **Sidebar**: Gypsum-style “add directory” picker + `DirectoryTreeView` show watch folder state; monitoring toggle removed in favor of always-on background indexing.
- **Directory tree**: Sidebar now lists Settings, directory add flow, and `DirectoryTreeView` with expand/collapse, rescan, and scan completion messaging; manual scans trigger metadata regeneration tracked by the background manager.
- **Metadata panel**: Tags can now be edited inline, the panel shows metadata timing/status, and rating/tag changes refresh repository/metadata indexes so the right pane stays up to date.
- **Grid**: `ImageGridView` renders thumbnails via `ThumbnailService`; selection now binds to `selectedImage`.
- **Single Image**: Displays a file via `Data(contentsOf:)` with basic error handling; no zoom/pan/filmstrip yet.
- **Metadata**: Shows tags and writes rating to XMP; no tag editing, EXIF, or album support.
- **Settings**: `SettingsView` implemented with AppConfig bindings and opened from sidebar.
- **Detail Panel**: `MetadataPanel` renders in detail pane when selection exists.

## NEAR-TERM PLAN
- Remove any remaining selection edge cases (e.g., list/grid sync) and refresh on file monitor events.
- Finish list view (columns, sorting) plus single-image zoom/pan/filmstrip.
- Add tag editing + EXIF display in `MetadataPanel`.
