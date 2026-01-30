# Spectasia - macOS Image Viewer & Manager

A modern, polished macOS image viewer and manager with AI-powered tagging and non-destructive metadata management.

## Features

- **Modern Gypsum UI**: Clean, matte finish design system.
- **High-Performance Viewing**: Thumbnail, list, and single image views.
- **Non-Destructive**: Original images are never modified. Metadata is stored in XMP sidecars.
- **Smart Caching**: Multi-size thumbnails (120/480/1024px) with a configurable cache location.
- **AI-Powered**: Automatic image tagging using Apple's Vision Framework.
- **Background Processing**: Non-blocking thumbnail generation and AI analysis.
- **Directory Monitoring**: Keeps libraries in sync by watching for file system changes.
- **Bilingual**: Supports English and Korean.

## Requirements

- macOS 13.0+ (Ventura or later)
- Xcode 15.0+
- Swift 6.2+

## License

This software is licensed under the **PolyForm Noncommercial License 1.0.0**. See the [LICENSE](LICENSE) file for full details.

For commercial use, a separate license is required. Please see our [End-User License Agreement (EULA)](EULA.md) for more information on purchasing a commercial license via Lemon Squeezy or the Apple App Store.

## Architecture

### Core Services (`SpectasiaCore` Swift Package)

The `SpectasiaCore` library contains the backend logic for the application.

1. **AppConfig**: Manages application settings via `UserDefaults`.
2. **PermissionManager**: Handles directory access using Security-Scoped Bookmarks.
3. **FileMonitorService**: Monitors directories for changes using FSEvents.
4. **XMPService**: Reads and writes XMP sidecar files for metadata.
5. **ThumbnailService**: Generates thumbnails of various sizes using ImageIO.
6. **AIService**: Performs image classification with the Vision Framework.
7. **ImageRepository**: An actor-based coordinator for all background processing tasks.
8. **MetadataStore**: Manages the index and storage paths for thumbnails and XMP files.

### UI (`UI/` Directory)

The user interface is built with SwiftUI and follows our custom Gypsum design system.

- **Gypsum Design System**: A custom set of SwiftUI components, colors, and fonts providing a unique matte finish aesthetic.
- **Three-Panel Layout**: A classic sidebar, main content view, and detail panel layout.
- **Image Views**: Includes a lazy-loading grid view, a list view, and a single image viewer.
- **Metadata Panel**: Displays and allows editing of image metadata like ratings and tags.

## File Structure

```
./
├── SpectasiaCore/            # Core services Swift Package
│   ├── Sources/Core/         # Service implementations
│   └── Tests/CoreTests/      # Unit tests for core services
├── UI/                       # SwiftUI views + Gypsum design system
├── Resources/                # App assets and localization
├── SpectasiaApp.swift         # Main application entry point
├── Spectasia.xcodeproj        # Xcode project
├── LICENSE                   # PolyForm Noncommercial License
└── EULA.md                   # End-User License Agreement
```

## Building & Testing

### Prerequisites

Ensure you have Xcode 15.0 or later installed.

### Build from Xcode

1. Open `Spectasia.xcodeproj`.
2. Press `⌘R` to build and run the application.

### Run Tests

You can run tests from Xcode or the command line:

```bash
# Run all tests for the Core package
swift test
```

## Credits

Built with ❤️ using:

- Swift & SwiftUI
- Apple Vision Framework
- ImageIO, CoreGraphics, and FSEvents
