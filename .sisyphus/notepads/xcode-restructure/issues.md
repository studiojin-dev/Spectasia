## Blocked Tasks

Tasks 11-12 (Swift Package Manager and Xcode project tests) are BLOCKED by pre-existing code errors in SpectasiaCore package services:

### Error Sources

**PermissionManager.swift** (Sources/SpectasiaCore/Core/PermissionManager.swift)
- Line 80: Extra trailing closure in startAccessingSecurityScopedResource()
- Lines 164, 169, 176, 181: GypsumFont enum references in UI code
- Line 182: GypsumColor.textSecondary reference

**XMPService.swift** - Missing Security framework
**ImageRepository.swift** - Missing Security framework  
**ThumbnailService.swift** - Missing Security framework

These errors block swift test (34 tests) and Xcode project tests.

### Issues
- Core services have UI-type dependencies (GypsumFont, GypsumColor) but lack proper imports
- Security framework not imported (needed for security-scoped bookmarks)
- Architecture violation: Core package depends on UI types

### Resolution Required (Out of Scope)

1. Remove GypsumFont/GypsumColor references from core services (use standard Font/Color APIs)
2. Add Security framework imports to services that need it
3. Refactor to separate UI dependencies from core package

This is NOT a restructure issue - these are pre-existing architectural problems in the codebase.

### Status

✅ **Restructure Tasks 1-10**: COMPLETED
- Directory structure created
- Core files moved to Sources/SpectasiaCore/
- Package.swift verified
- Xcode project updated  
- Info.plist fixed
- Bundle identifiers standardized
- Entitlements file created and referenced
- Test framework decision documented

⏸️ **Verification Tasks 11-12**: BLOCKED
- Swift Package Manager tests: ❌ (pre-existing PermissionManager.swift errors)
- Xcode project tests: ❌ (pre-existing core service errors)

**Next Steps Required** (Separate Work):
1. Fix PermissionManager.swift compilation errors
2. Fix XMPService, ImageRepository, ThumbnailService Security framework imports
3. Refactor to separate UI dependencies from core package
4. Run tests to verify all functionality works
