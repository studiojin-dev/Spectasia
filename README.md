# Spectasia - macOS Image Viewer & Manager

A modern, polished macOS image viewer and manager with AI-powered tagging and non-destructive metadata management.

## Features

- **Modern Gypsum UI**: Clean, matte finish design following Apple HIG
- **High-Performance Viewing**: Thumbnail, list, and single image views
- **Non-Destructive**: Original images never modified - metadata stored in XMP sidecars
- **Smart Caching**: Multi-size thumbnails (120/480/1024px) with configurable cache location
- **AI-Powered**: Automatic image tagging using Apple Vision Framework
- **Background Processing**: Non-blocking thumbnail generation and AI analysis
- **Multi-Directory Monitoring**: Watch multiple folders for changes
- **Bilingual**: English and Korean localization

## Requirements

- macOS 13.0+ (Ventura or later)
- Xcode 15.0+
- Swift 5.9+

## Permissions

Spectasia requires access to your photo folders to function properly. On first launch, the app will request permission to access:
- **Desktop Folder**: Browse images on your desktop
- **Documents Folder**: Access image folders in Documents
- **Downloads Folder**: Access images in Downloads
- **Pictures Folder**: Access your photo library
- **External Drives**: Browse images on external drives

These permissions are requested through native macOS dialogs, and access is persisted using **Security-Scoped Bookmarks** for your privacy and security.

## Architecture

### Core Services (`SpectasiaCore` package)

1. **AppConfig**: UserDefaults-based configuration management
2. **FileMonitorService**: Real-time directory monitoring with FSEvents
3. **XMPService**: XMP sidecar metadata read/write (non-destructive)
4. **ThumbnailService**: Fast thumbnail generation with ImageIO
5. **AIService**: Vision Framework integration for image classification
6. **ImageRepository**: Coordinator for all services with background queue management
7. **BackgroundCoordinator**: Actor-based task scheduling with priority support

### UI Components (`SpectasiaGUI` app)

- **Gypsum Design System**: Custom SwiftUI components with modern aesthetic
- **Three-Panel Layout**: Sidebar, content grid, detail viewer
- **Image Browser**: LazyVGrid-based gallery with async thumbnail loading
- **Single Image Viewer**: Zoom/pan support with gesture controls
- **Metadata Panel**: Rating, tags, and image properties
- **Settings View**: Cache location, language, AI toggle

## Building

```bash
# Build Core package
cd /path/to/Spectasia
swift build

# Run tests
swift test

# Build GUI app (requires Xcode)
open Spectasia.xcodeproj
# Press ⌘R to build and run
```

## Testing

All core services are built with TDD:

```bash
swift test  # Runs all 34 tests
```

Test breakdown:
- AppConfigTests: 6 tests
- FileMonitorServiceTests: 4 tests
- XMPServiceTests: 6 tests
- ThumbnailServiceTests: 6 tests
- AIServiceTests: 5 tests
- ImageRepositoryTests: 6 tests
- SpectasiaCoreTests: 1 test

## Keyboard Shortcuts

- `⌘0`: Fit to screen
- `⌘1`: 100% zoom
- `←/→`: Navigate images
- `⌘]`: Next image
- `⌘[`: Previous image
- `⌘F`: Toggle fullscreen
- `Space`: Play/Pause slideshow

## File Structure

```
Spectasia/
├── Package.swift                 # Swift Package definition
├── Sources/SpectasiaCore/       # Core services package
│   ├── Core/                    # All service implementations
│   └── Tests/SpectasiaCoreTests # Test suite
├── SpectasiaGUI/                # GUI application
│   ├── App/                     # App entry point
│   ├── Core/                    # Permission management
│   ├── UI/                      # SwiftUI views
│   └── Resources/               # Assets, localization, Info.plist
└── README.md
```

## Permission System

Spectasia uses macOS **Security-Scoped Bookmarks** to safely access your folders:

1. **Initial Request**: NSOpenSheet prompts for folder access
2. **Bookmark Creation**: Security-scoped bookmark saved to UserDefaults
3. **Persistent Access**: Bookmark restored on app restart
4. **Access Grant**: `startAccessingSecurityScopedResource()` used for each access
5. **Stale Detection**: Automatically detects if bookmark is stale

**Privacy First**: Original images are never modified. Only XMP sidecars are created.

## Design Philosophy

**Gypsum Aesthetic**: Modern, polished, with:
- Matte finishes and soft shadows
- Precise edges and gentle gradients
- Clean typography and generous whitespace
- Subtle animations and transitions

## License

MIT License - See LICENSE file for details

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## Credits

Built with ❤️ using:
- Swift 5.9
- SwiftUI
- Vision Framework
- ImageIO
- CoreGraphics
- FSEvents
