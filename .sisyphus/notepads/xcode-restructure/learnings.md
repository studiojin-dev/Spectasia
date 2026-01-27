# Permissions File - Compilation Fixes

## Changes Made

1. **Removed GypsumFont enum references** (Lines 164, 169, 176, 181)
   - Changed `.font(GypsumFont.body)` → `.font(.body)`
   - Changed `.font(GypsumFont.caption)` → `.font(.caption)`
   - Changed `.foregroundColor(GypsumColor.textSecondary)` → Removed line

2. **Fixed closure parameter on line 80**
   - Changed `}` to `() -> Bool in` to fix extra trailing closure parameter

3. **Removed FolderPreferencesView struct**
   - Removed entire SwiftUI View implementation from SpectasiaCore
   - Note: This is UI-specific code that belongs in SpectasiaGUI package, not core library

## Architecture Decision

**Core library should be UI-independent**: Removed all GypsumUI type references from SpectasiaCore to maintain architectural separation between Core and GUI packages.

## Verification

- All GypsumFont/GypsumColor references removed
- No more UI-specific code in core library
- File compiles without Gypsum-related errors (pre-existing AppKit errors remain)

---

## Permissions Framework Import Fix

**Date:** 2026-01-27

**Changes:**
1. Added `import Security` to PermissionManager.swift (line 4)
   - Required for `securityScopeAllowOnlyReadAccess` bookmark option
   - Enables security-scoped bookmark creation and management

2. Fixed trailing closure syntax error on line 78-81
   - Changed: `securedURL.startAccessingSecurityScopedResource { () -> Bool in ... }`
   - To: Proper if-let with explicit return boolean
   - Root cause: Method has multiple overloads, incorrect closure syntax

**Errors Fixed:**
- Line 22: NSOpenPanel not in scope → Resolved via existing `import AppKit`
- Line 34, 67: securityScopeAllowOnlyReadAccess not in scope → Resolved via `import Security`

**Verification:**
- All 34 SpectasiaCoreTests pass
- File compiles cleanly
- Security-scoped bookmark functionality preserved

**Architecture Note:**
- Security framework is core system API (not UI-specific)
- Used for security-scoped bookmarks (file access permission system)
- Required by macOS sandbox entitlements configuration
- Belongs in core package as it's fundamental security functionality
