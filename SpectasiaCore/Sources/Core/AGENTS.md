# Core Services Module

## OVERVIEW
SpectasiaCore package - backend services for image management, metadata, thumbnails, AI, file monitoring.

## STRUCTURE
```
SpectasiaCore/Sources/Core/
├── SpectasiaCore.swift      # Core module entry point
├── AppConfig.swift          # UserDefaults-based configuration
├── PermissionManager.swift   # Security-Scoped Bookmarks, directory access
├── FileMonitorService.swift  # FSEvents-based directory monitoring
├── XMPService.swift        # XMP sidecar metadata (non-destructive)
├── ThumbnailService.swift    # ImageIO thumbnail generation
├── AIService.swift         # Vision Framework classification
├── ImageRepository.swift    # Coordinator + BackgroundCoordinator
├── MetadataStore.swift      # XMP/thumbnail path store + index
├── MetadataStoreManager.swift # Observable wrapper for MetadataStore
└── CoreLog.swift            # OSLog helper
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| App config | `AppConfig.swift` | `metadataStoreDirectory`, `cacheDirectory`, `language`, `isAutoAIEnabled` |
| Permissions | `PermissionManager.swift` | `requestDirectoryAccess()`, `accessDirectory()` with security scope |
| Directory watch | `FileMonitorService.swift` | FSEvents, real-time file changes |
| Metadata R/W | `XMPService.swift` | XMP sidecar read/write, never modifies original |
| Thumbnails | `ThumbnailService.swift` | Multi-size (120/480/1024px), ImageIO |
| AI tagging | `AIService.swift` | Vision Framework `VNClassifyImageRequest` |
| Coordination | `ImageRepository.swift` | Background queue, service orchestration, Observable wrapper |
| Storage index | `MetadataStore.swift` | XMP/thumbnail paths + index persistence |

## CONVENTIONS
- **TDD**: Every service has test file in `SpectasiaCore/Tests/CoreTests/`
- **UserDefaults**: `AppConfig` persists settings (cache dir, language, AI toggle)
- **Non-destructive**: XMP sidecars only, stored under app-managed metadata directory
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

## CURRENT IMPLEMENTATION STATUS (2026-01-30)
- **Implemented**: AppConfig, PermissionManager, FileMonitorService, ThumbnailService (basic), XMPService (ratings/tags), AIService (basic classification), MetadataStore + manager, ImageRepository + ObservableImageRepository.
- **Partial**: BackgroundCoordinator status is string-based; no task cancellation/parallelism.
- **Missing**: XMP albums/EXIF/GPS, ICC/HDR preservation in thumbnails, AI faces/objects/mood, search/filter, persistent metadata store, progress reporting model.

## PLAN SUMMARY
- **Short-term**: Strengthen repository/UI binding (selection updates, monitoring events), and formalize processing status model for UI.
- **Mid-term**: Expand AI requests (faces/animals/objects/mood) and add auto-analysis flow.
- **Long-term**: Album metadata in XMP, cache cleanup/LRU, robust XML parsing, and persistent metadata index.
