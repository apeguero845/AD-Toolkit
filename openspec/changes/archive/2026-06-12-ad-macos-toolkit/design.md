# Design: AD macOS Toolkit

## Technical Approach

Aplicación nativa de macOS con arquitectura de 3 capas:

1. **SwiftUI App** — interfaz gráfica para soporte, sin privilegios
2. **GSS Bridge** — wrapper en C/Obj-C para `GSS.framework` (cambio de password Kerberos)
3. **Privileged Helper Tool** — daemon root via SMAppService + XPC para operaciones privilegiadas

## Architecture Decisions

### Decision: GSS.framework sobre kpasswd o dscl

| Opción | Tradeoff | Decisión |
|--------|----------|----------|
| `kpasswd` via PTY/expect | Frágil, depende de output interactivo | ❌ |
| `dscl . -passwd` | No funciona con AD estricto (Error -14165) | ❌ |
| `sysadminctl` | Desincroniza (local OK, AD no) | ❌ |
| **GSS.framework** `gss_aapl_change_password()` | API nativa no interactiva, sincroniza KCM | ✅ |

**Rationale**: GSS.framework es la capa Apple que encapsula Heimdal Kerberos. No requiere shell, no es interactiva, y actualiza el credential cache de sistema (KCM) automáticamente.

### Decision: SMAppService sobre SMJobBless o AuthorizationExecuteWithPrivileges

| Opción | Tradeoff | Decisión |
|--------|----------|----------|
| `AuthorizationExecuteWithPrivileges()` | Deprecado desde 10.7 | ❌ |
| `SMJobBless()` | Deprecado en Ventura+ | ❌ |
| **SMAppService** + XPC | Moderno, Apple-approved, macOS 13+ | ✅ |

**Rationale**: Apple introdujo SMAppService como reemplazo de SMJobBless. Es el approach correcto para tener un helper con permisos root. El helper se instala como Launch Daemon y la app se comunica via NSXPCConnection.

### Decision: Swift Package Manager sobre Xcode project

**Choice**: Xcode project (por los bundles y signing del helper tool)
**Rationale**: SMAppService requiere code signing con equipo de desarrollo, y Xcode maneja la configuración de múltiples targets (app + helper) y sus Info.plist.

## Data Flow

### Password Change Flow

```
User enters passwords → SwiftUI App
    ↓
GSS Bridge (C/Obj-C)
    ├── GSSCreateName("usuario@CESARIGLESIAS.LOCAL")
    ├── gss_aapl_change_password(old, new, name)
    └── → Success / Error
    ↓ (if success)
Helper Tool (root via XPC)
    ├── sysadminctl → update mobile account
    └── SecKeychainChangePassword → update login keychain
    ↓
SwiftUI App → "Completado" / Error message
```

### Domain Join Flow

```
User fills form (name, OU, admin creds) → SwiftUI App
    ↓
App runs pre-flight checks (inline, no root needed)
    ├── DNS: nslookup / host
    ├── Time: comparison
    └── Connectivity: port check
    ↓ (all pass)
Helper Tool (root via XPC)
    └── dsconfigad -add ... -force
    ↓
SwiftUI App → "Completado" / Error message
```

## Component Architecture

```
AD-Toolkit.app/
├── App/
│   ├── ADToolkitApp.swift          ← @main entry
│   ├── Views/
│   │   ├── ContentView.swift       ← Navigation (passwd / join / diag)
│   │   ├── PasswordChangeView.swift
│   │   ├── DomainJoinView.swift
│   │   └── DiagnosticsView.swift
│   ├── ViewModels/
│   │   ├── PasswordChangeViewModel.swift
│   │   └── DomainJoinViewModel.swift
│   └── Services/
│       ├── KerberosService.swift     ← Llama al bridge C/Obj-C
│       └── XPCService.swift          ← Proxy al helper tool
├── GSSBridge/                        ← C/Obj-C wrapper
│   ├── gss_bridge.h
│   ├── gss_bridge.c
│   └── bridging-header.h
├── HelperTool/                       ← Target separado
│   ├── main.swift
│   ├── HelperToolDelegate.swift      ← SMAppService listener
│   ├── XPCServer.swift               ← NSXPCListener
│   └── Operations/
│       ├── DomainJoinOperation.swift
│       ├── LocalPasswordSyncOperation.swift
│       └── KeychainSyncOperation.swift
└── Common/
    └── XPCProtocol.swift             ← Shared protocol definition
```

## Interfaces / Contracts

### XPC Protocol

```swift
@objc protocol ADToolkitXPCProtocol {
    // Domain join
    func joinDomain(computerName: String,
                    ou: String,
                    adminUser: String,
                    adminPass: String,
                    reply: @escaping (Bool, String?) -> Void)

    // Local password sync
    func syncLocalPassword(username: String,
                           newPassword: String,
                           reply: @escaping (Bool, String?) -> Void)

    // Keychain sync
    func syncKeychain(username: String,
                      oldPassword: String,
                      newPassword: String,
                      reply: @escaping (Bool, String?) -> Void)

    // Diagnostics
    func runDiagnostics(reply: @escaping ([String: String]) -> Void)
}
```

### GSS Bridge

```c
typedef struct {
    bool success;
    int kerberos_error_code;
    const char *error_message;
} gss_password_change_result_t;

gss_password_change_result_t gss_change_password(
    const char *user_principal,  // "user@REALM"
    const char *old_password,
    const char *new_password
);
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | GSS Bridge error handling | Simular respuestas Kerberos con mocking |
| Unit | ViewModel logic | Tests unitarios de Swift sin UI |
| Integration | Helper XPC commands | Test helper tool con conexión local XPC |
| E2E | Full password flow | En Mac bound a AD de prueba |
| Manual | Domain join | Verificar con OU real en AD de prueba |

**Nota**: No hay test runner disponible (strict TDD: disabled). Las pruebas serán manuales hasta que se configure un entorno de test.

## Migration / Rollout

No migration required. Es una aplicación nueva que se distribuye como `.app` firmada.

Rollout sugerido:
1. Test en 2-3 máquinas piloto con equipo de soporte
2. Feedback de UX y errores no cubiertos
3. Distribución via MDM o instalación manual

## Open Questions

- [ ] ¿Qué versión de macOS mínima tiene el parque actual de CISA? (SMAppService requiere 13+)
- [ ] ¿El AD de CISA permite cambios de password via Kerberos en puerto 464 o está restringido?
- [ ] ¿Hay un AD de testing para pruebas antes de producción?
