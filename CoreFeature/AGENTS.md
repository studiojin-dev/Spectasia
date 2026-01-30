# Core Services Module

## OVERVIEW
SpectasiaCore package - backend services for image management, metadata, thumbnails, AI, file monitoring.

## STRUCTURE
```
Core/
├── SpectasiaCore.swift      # Core module entry point
├── AppConfig.swift          # UserDefaults-based configuration
├── PermissionManager.swift   # Security-Scoped Bookmarks, directory access
├── FileMonitorService.swift  # FSEvents-based directory monitoring
├── XMPService.swift        # XMP sidecar metadata (non-destructive)
├── ThumbnailService.swift    # ImageIO thumbnail generation
├── AIService.swift         # Vision Framework classification
└── ImageRepository.swift    # Coordinator for all services
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| App config | `AppConfig.swift` | `cacheDirectory`, `language`, `isAutoAIEnabled` |
| Permissions | `PermissionManager.swift` | `requestDirectoryAccess()`, `accessDirectory()` with security scope |
| Directory watch | `FileMonitorService.swift` | FSEvents, real-time file changes |
| Metadata R/W | `XMPService.swift` | XMP sidecar read/write, never modifies original |
| Thumbnails | `ThumbnailService.swift` | Multi-size (120/480/1024px), ImageIO |
| AI tagging | `AIService.swift` | Vision Framework `VNClassifyImageRequest` |
| Coordination | `ImageRepository.swift` | Background queue, service orchestration |

## CONVENTIONS
- **TDD**: Every service has test file in `Tests/SpectasiaCoreTests/`
- **UserDefaults**: `AppConfig` persists settings (cache dir, language, AI toggle)
- **Non-destructive**: XMP sidecars only - never touch original images
- **Background processing**: `ImageRepository` manages background queues for thumbnails/AI
- **Logging**: `os.log` with subsystem `com.spectasia.core`
- **Public API**: All services `public`, no internal package leakage

## ANTI-PATTERNS
*(See root AGENTS.md)*

## UNIQUE STYLES
- **Security-Scoped Bookmarks**: macOS sandboxing via `PermissionManager`
- **FSEvents monitoring**: Real-time directory change detection
- **Actor-based coordination**: `ImageRepository` uses background actors
- **Multi-size thumbnails**: 120/480/1024px for different use cases
- **Vision Framework**: `VNClassifyImageRequest` for AI-powered tagging
