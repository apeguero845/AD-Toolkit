# Proposal: Fix Xcode Build System Warnings

## Intent

XcodeGen build emits two persistent run script phase warnings ("will be run during every build because it does not specify any outputs"). These don't block the build but signal fragile config that slows iteration. CISA's AD integration tool must build cleanly on any Mac without manual workarounds or spurious warnings.

## Scope

### In Scope
- Add `inputFiles`/`outputFiles` to "Install Helper Tool" and "Copy launchd.plist for SMAppService" scripts
- Move "Install Helper Tool" from `preBuildScripts` to `postBuildScripts` (depends on HelperTool already compiled)
- Validate zero warnings via `xcodebuild`

### Out of Scope
- CI/CD pipeline setup
- Code signing reconfiguration (already fixed in 234b4c6)
- Test target creation
- Any functional change to AD password change or domain join behavior

## Capabilities

### New Capabilities
None. Pure build infrastructure change — no new functional capability.

### Modified Capabilities
None. No spec-level behavior changes. Both existing specs (`ad-password-change`, `domain-join`) are unaffected.

## Approach

Two targeted edits to `project.yml`:

**1. Move "Install Helper Tool" to `postBuildScripts` with input/output declarations**, removing it from `preBuildScripts`:

```yaml
postBuildScripts:
  - name: "Install Helper Tool"
    script: |
      mkdir -p "$BUILT_PRODUCTS_DIR/$CONTENTS_FOLDER_PATH/Library/LaunchServices"
      cp "$BUILT_PRODUCTS_DIR/HelperTool.bundle/Contents/MacOS/HelperTool" \
         "$BUILT_PRODUCTS_DIR/$CONTENTS_FOLDER_PATH/Library/LaunchServices/"
    inputFiles:
      - $(BUILT_PRODUCTS_DIR)/HelperTool.bundle/Contents/MacOS/HelperTool
    outputFiles:
      - $(BUILT_PRODUCTS_DIR)/$(CONTENTS_FOLDER_PATH)/Library/LaunchServices/HelperTool
```

**2. Add input/output declarations to existing "Copy launchd.plist" postBuildScript**:

```yaml
  - name: "Copy launchd.plist for SMAppService"
    script: |
      mkdir -p "$BUILT_PRODUCTS_DIR/$CONTENTS_FOLDER_PATH/Library/LaunchDaemons"
      cp "$SRCROOT/Resources/launchd.plist" \
         "$BUILT_PRODUCTS_DIR/$CONTENTS_FOLDER_PATH/Library/LaunchDaemons/com.cisa.ad-toolkit.helper.plist"
    inputFiles:
      - $(SRCROOT)/Resources/launchd.plist
    outputFiles:
      - $(BUILT_PRODUCTS_DIR)/$(CONTENTS_FOLDER_PATH)/Library/LaunchDaemons/com.cisa.ad-toolkit.helper.plist
```

Declaring `outputFiles` tells Xcode to skip the script when outputs are already up-to-date, eliminating both warnings. Moving "Install Helper Tool" to `postBuildScripts` fixes the ordering dependency (binary must be compiled first).

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `project.yml` | Modified | Move script phase, add input/output declarations |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Script runs at wrong build phase | Low | `postBuildScripts` runs after compile + link — HelperTool is guaranteed ready |
| Incorrect output path breaks SMAppService | Low | Paths match successful production build (verified in commit 234b4c6) |
| XPC bundle not found at input path | Low | Path matches XcodeGen's `embed: true` convention for bundles |

## Rollback Plan

```bash
git checkout HEAD -- project.yml
```

No functional state changed — only build configuration. Revert is instantaneous and zero-risk.

## Dependencies

- XcodeGen installed (`setup.sh` handles this)

## Success Criteria

- [ ] `xcodebuild` completes with zero warnings related to run script phases
- [ ] HelperTool binary present in `Contents/Library/LaunchServices/` after build
- [ ] launchd.plist present in `Contents/Library/LaunchDaemons/` after build
