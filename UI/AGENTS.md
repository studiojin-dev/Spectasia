# UI MODULE

## OVERVIEW
SwiftUI views + Gypsum design system for Spectasia GUI.

## STRUCTURE
```
UI/
├── GypsumDesignSystem.swift    # Design tokens + reusable components
├── ContentView.swift            # Main view (placeholder)
├── ImageGridView.swift         # Thumbnail grid gallery
├── SingleImageView.swift        # Single image viewer with zoom/pan
├── MetadataPanel.swift        # Rating, tags, properties panel
├── SettingsView.swift         # App settings (cache, language, AI toggle)
├── DirectoryPicker.swift      # Folder selection UI
└── SpectasiaLayout.swift      # Three-panel layout (sidebar, grid, detail)
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Design tokens | `GypsumDesignSystem.swift` | Colors, fonts, GypsumCard, GypsumButton |
| Main view | `ContentView.swift` | Currently placeholder - NOT connected to Core |
| Image gallery | `ImageGridView.swift` | LazyVGrid with async thumbnails |
| Image viewer | `SingleImageView.swift` | Zoom/pan gestures, fullscreen |
| Metadata editor | `MetadataPanel.swift` | Rating, tags, image properties |
| Settings | `SettingsView.swift` | Cache dir, language, AI toggle |
| Folder selection | `DirectoryPicker.swift` | UI wrapper for PermissionManager |
| Layout | `SpectasiaLayout.swift` | Three-panel: sidebar | grid | detail |

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
