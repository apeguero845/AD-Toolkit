# Tasks: Xcode Build System Fix

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~20 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

## Phase 1: Edit project.yml — Install Helper Tool

- [x] 1.1 Move "Install Helper Tool" block from `preBuildScripts` to `postBuildScripts` (before the existing "Copy launchd.plist" entry)
- [x] 1.2 Add `inputFiles` to the moved block: `$(BUILT_PRODUCTS_DIR)/HelperTool.bundle/Contents/MacOS/HelperTool`
- [x] 1.3 Add `outputFiles` to the moved block: `$(BUILT_PRODUCTS_DIR)/$(CONTENTS_FOLDER_PATH)/Library/LaunchServices/HelperTool`
- [x] 1.4 Verify: `xcodebuild` completes without "run script phase" warnings; HelperTool binary present at `Contents/Library/LaunchServices/` in built product

## Phase 2: Edit project.yml — Copy launchd.plist

- [x] 2.1 Add `inputFiles` to "Copy launchd.plist for SMAppService": `$(SRCROOT)/Resources/launchd.plist`
- [x] 2.2 Add `outputFiles` to same block: `$(BUILT_PRODUCTS_DIR)/$(CONTENTS_FOLDER_PATH)/Library/LaunchDaemons/com.cisa.ad-toolkit.helper.plist`
- [x] 2.3 Verify: `xcodebuild` completes without "run script phase" warnings; launchd.plist present at `Contents/Library/LaunchDaemons/` in built product

## Phase 3: Full Integration Verification

- [x] 3.1 Run `xcodebuild -project ADToolkit.xcodeproj -scheme ADToolkit build` and assert zero warnings related to run script phases (grep for "run script" in build log — should show only informational "Run custom shell script" lines, never "will be run during every build")
- [x] 3.2 Inspect built product: confirm `Contents/Library/LaunchServices/HelperTool` exists
- [x] 3.3 Inspect built product: confirm `Contents/Library/LaunchDaemons/com.cisa.ad-toolkit.helper.plist` exists
- [x] 3.4 After `xcodebuild`, run `codesign -dv --verbose=4 ADToolkit.app` and confirm no code signing errors in embedded bundles

## Rollback

- `git checkout project.yml` reverts both changes atomically — no database, no migrations, no generated files.
