#!/bin/bash
#
#  setup.sh
#  AD Toolkit
#
#  Two ways to set up the project:
#    Option A (recommended): XcodeGen — one command
#    Option B: Manual Xcode setup
#
#  Prerequisites: macOS 13+, Xcode 15+, Apple Developer account
#

set -euo pipefail

PROJECT_NAME="ADToolkit"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=========================================="
echo "  AD Toolkit — Project Setup"
echo "=========================================="
echo ""

# Check Xcode
if ! command -v xcode-select &> /dev/null; then
    echo "❌ Xcode is not installed. Install from Mac App Store."
    exit 1
fi
echo "✅ Xcode found: $(xcode-select -p)"

echo ""
echo "Choose setup method:"
echo ""
echo "  [1] XcodeGen (recommended) — automatic project generation"
echo "  [2] Manual — create Xcode project by hand"
echo ""
read -p "Method [1]: " METHOD
METHOD=${METHOD:-1}

if [ "$METHOD" = "1" ]; then
    # ── Option A: XcodeGen ──────────────────────────────
    echo ""
    echo "📦 Option A: XcodeGen"

    # Check/install XcodeGen
    if ! command -v xcodegen &> /dev/null; then
        echo "   XcodeGen not found. Installing via Homebrew..."
        if command -v brew &> /dev/null; then
            brew install xcodegen
        else
            echo "   Homebrew not found. Installing via mint..."
            if command -v mint &> /dev/null; then
                mint install yonaskolb/XcodeGen
            else
                echo "❌ Install XcodeGen manually: brew install xcodegen"
                exit 1
            fi
        fi
    fi
    echo "✅ XcodeGen found"

    # Generate project
    echo ""
    echo "   Generating Xcode project..."
    cd "$PROJECT_DIR"
    xcodegen generate --spec project.yml
    echo "✅ Project generated: $PROJECT_NAME.xcodeproj"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  NEXT STEPS:"
    echo ""
    echo "  1. Open $PROJECT_NAME.xcodeproj"
    echo "  2. Select your Apple Developer Team in Signing & Capabilities"
    echo "  3. Build and Run (Cmd+R)"
    echo ""
    echo "  IMPORTANT: On first run, go to:"
    echo "    Settings > General > Login Items"
    echo "    Enable 'ADToolkit Helper'"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

else
    # ── Option B: Manual ────────────────────────────────
    echo ""
    echo "📋 Option B: Manual Setup"
    echo ""
    echo "  Follow these steps in Xcode:"
    echo ""
    echo "  1. File > New > Project"
    echo "     macOS > App (SwiftUI)"
    echo "     Name: $PROJECT_NAME"
    echo "     Bundle ID: com.cisa.ad-toolkit"
    echo "     Team: (your Apple Developer team)"
    echo ""
    echo "  2. File > New > Target"
    echo "     macOS > XPC Service"
    echo "     Name: HelperTool"
    echo "     Bundle ID: com.cisa.ad-toolkit.helper"
    echo ""
    echo "  3. Configure App target:"
    echo "     - Add Sources/App/**/*.swift to Compile Sources"
    echo "     - Add Sources/GSSBridge/**/*.{c,h}"
    echo "     - Add Sources/Common/XPCProtocol.swift"
    echo "     - Set Bridging Header: Sources/GSSBridge/include/ADToolkit-Bridging-Header.h"
    echo "     - Replace Info.plist with Resources/App-Info.plist"
    echo ""
    echo "  4. Configure HelperTool target:"
    echo "     - Remove auto-generated files"
    echo "     - Add Sources/HelperTool/**/*.swift"
    echo "     - Add Sources/Common/XPCProtocol.swift"
    echo "     - Replace Info.plist with Resources/HelperTool-Info.plist"
    echo ""
    echo "  5. Code Signing:"
    echo "     - App: Developer ID Application"
    echo "     - HelperTool: Developer ID Application"
    echo ""
    echo "  6. Build Phases > App:"
    echo "     + Copy Files: /Library/PrivilegedHelperTools/"
    echo "     - Add HelperTool.bundle"
    echo ""
    echo "  7. Build and Run"
fi
