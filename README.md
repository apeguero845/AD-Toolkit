# AD Toolkit

Native macOS application for Active Directory integration — domain join, password change, and diagnostics for Macs bound to AD.

---

## Features

### Domain Join
Join macOS to an Active Directory domain with OU support, configurable admin credentials, and detailed error handling for common scenarios (DNS, time sync, permissions, container policy).

### AD Password Change
Change Active Directory passwords via Kerberos (GSS.framework) — the only reliable method that communicates directly with the KDC on port 464/tcp. Avoids the known pitfalls of `dscl`, `sysadminctl` (local-only desync), and `kpasswd` (interactive terminal requirement).

### Local Account Sync
After a password change, synchronizes the local mobile account password and login keychain automatically via the privileged helper tool.

### Diagnostics
Quick health checks for AD integration: DNS SRV resolution, time sync, LDAP reachability, Kerberos port, and domain bind status.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                 ADToolkit.app (SwiftUI)                  │
│  ┌─────────────┐  ┌──────────┐  ┌───────────────────┐  │
│  │ Password     │  │ Domain   │  │ Diagnostics       │  │
│  │ Change View  │  │ Join View│  │ View              │  │
│  └──────┬───────┘  └────┬─────┘  └───────────────────┘  │
│         │               │                                │
│  ┌──────▼───────────────▼────────────────────────────┐   │
│  │ XPCService (XPC Client)                          │   │
│  └──────┬───────────────────────────────────────────┘   │
└─────────┼───────────────────────────────────────────────┘
          │ XPC (inter-process, runs as user)
┌─────────▼───────────────────────────────────────────────┐
│           HelperTool.bundle (XPC Service)                │
│  ┌──────────────────────────────────────────────────┐    │
│  │ XPCServer — privileged operations as root        │    │
│  │ • Domain join (dsconfigad)                       │    │
│  │ • Leave domain (dsconfigad)                      │    │
│  │ • Local password sync (ODRecord)                 │    │
│  │ • Keychain sync (security CLI)                   │    │
│  └──────────────────────────────────────────────────┘    │
└─────────┬───────────────────────────────────────────────┘
          │ Direct call
┌─────────▼───────────────────────────────────────────────┐
│  GSSBridge (C/Obj-C)                                     │
│  ┌──────────────────────────────────────────────────┐    │
│  │ gss_aapl_change_password() → KDC over Kerberos   │    │
│  └──────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

Three layers:
- **SwiftUI App** — user interface, XPC client, GSS bridge calls
- **HelperTool (XPC)** — privileged operations via `SMAppService`, runs as root
- **GSSBridge** — Kerberos password change via GSS.framework

---

## Requirements

- macOS 13.0+
- Xcode 15+
- Apple Developer account (for code signing)

## Setup

```bash
# Install XcodeGen (one-time)
brew install xcodegen

# Generate Xcode project
cd ad-toolkit
xcodegen generate --spec project.yml

# Open in Xcode
open ADToolkit.xcodeproj
```

Select your team in **Signing & Capabilities**, then Build and Run.

## Configuration

Before building, configure your AD environment in each target's settings or at compile time:

| Setting | Default | File |
|---------|---------|------|
| Domain | — | Configure in source |
| DC IP | — | Configure in source |
| Default OU | — | Configure in source |

*These values are intentionally left as placeholders. Set them to match your AD infrastructure before deploying.*

## Project Structure

```
ad-toolkit/
├── Sources/
│   ├── App/           # SwiftUI app (views, view models, services)
│   ├── Common/        # Shared XPC protocol
│   ├── GSSBridge/     # C/Obj-C Kerberos bridge
│   └── HelperTool/    # XPC privileged service
├── Resources/         # Plists, entitlements, launchd config
├── project.yml        # XcodeGen project specification
├── setup.sh           # Build environment setup
└── openspec/          # SDD specifications (see below)
```

## Development

This project follows **Spec-Driven Development (SDD)**. All changes are specified, designed, and verified before implementation. Artifacts live in:

- `openspec/specs/` — Functional specifications
- `openspec/changes/` — Active and archived change proposals
- `openspec/config.yaml` — SDD project configuration

## License

Internal tool — César Iglesias S.A.
