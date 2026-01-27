## Decision: Keep XCTest for SpectasiaUITests

**Date:** 2026-01-27T21:00:00Z

**Context:** Task 8 attempted to convert SpectasiaUITests.swift from XCTest to Swift Testing framework.

**Analysis:**
- Swift Testing framework is incompatible with UI tests in Xcode
- UI tests require XCTest for XCUIApplication and XCTApplicationLaunchMetric support
- XCTest provides UI test infrastructure (XCUIApplication, lifecycle hooks, launch metrics)
- Swift Testing is designed for unit tests, not UI automation

**Decision:**
- Keep SpectasiaUITests.swift on XCTest framework
- SpectasiaTests.swift already uses Swift Testing (correct)
- This maintains separation: Unit tests use Swift Testing, UI tests use XCTest

**Reason:**
- Correct architectural separation for testing frameworks
- Maintains build stability and Xcode compatibility

## Decision: Sandbox Entitlements Configuration

**Date:** 2026-01-27

**Context:** Task 9 required adding sandbox entitlements file to Spectasia application.

**Analysis:**
- App needs sandbox for macOS security compliance
- Core functionality requires file system access:
  - User-selected folders (security-scoped bookmarks)
  - Downloads folder access
  - Thumbnail caching
  - Image repository operations
- App is local-only (no network), so network entitlement NOT needed
- App reads images (non-destructive), does NOT modify originals (only XMP sidecars)

**Configuration:**
```xml
com.apple.security.app-sandbox = true
com.apple.security.files.user-selected.read-write = true
com.apple.security.files.bookmarks.app-scope = true
com.apple.security.files.downloads.read-write = true
```

**Reason:**
- Enables proper macOS sandboxing while allowing required file operations
- Security-scoped bookmarks allow selective folder access with persistent grants
- Downloads access needed for user workflow (downloaded images)
- Bookmarks app-scope enables cross-process bookmark persistence
- Local-only app avoids unnecessary network permissions

**Verification:**
- `plutil -lint Spectasia/Spectasia.entitlements` passes with "OK"
- Valid XML plist format confirmed
