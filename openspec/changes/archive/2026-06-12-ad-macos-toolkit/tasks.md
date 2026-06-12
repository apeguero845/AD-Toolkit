# Tasks: AD macOS Toolkit

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 1800–2500 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1: Foundation + GSS Bridge → PR 2: Helper Tool + Domain Join → PR 3: Password Flow + UI |
| Delivery strategy | ask-always |
| Chain strategy | pending |

```
Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High
```

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Xcode project + GSS Bridge + Base App | PR 1 | Estructura del proyecto, bridging header, gss_bridge.c, XPC protocol, UI skeleton |
| 2 | Helper Tool + Domain Join + Diagnostics | PR 2 | SMAppService setup, XPC server, dsconfigad wrapper, pre-flight checks |
| 3 | Password Change Flow + Keychain Sync | PR 3 | GSS bridge integration, local sync, keychain sync, full UI wiring |

## Phase 1: Foundation & GSS Bridge

- [x] 1.0 Crear `ad-toolkit/` con estructura de directorios y `.gitignore`
- [x] 1.1 Crear `GSSBridge/gss_bridge.h` y `gss_bridge.c` con `gss_change_password()`
- [x] 1.2 Crear `Common/XPCProtocol.swift` con protocolo `ADToolkitXPCProtocol`
- [x] 1.3 Crear `HelperTool/main.swift`, `HelperToolDelegate.swift`, `XPCServer.swift`
- [x] 1.4 Crear `HelperTool/Operations/` con operation stubs (join, sync, keychain)
- [x] 1.5 Crear `App/ADToolkitApp.swift` con TabView de 3 pestañas
- [x] 1.6 Crear `App/Views/` con PasswordChangeView, DomainJoinView, DiagnosticsView
- [x] 1.7 Crear `App/ViewModels/` con PasswordChangeViewModel y DomainJoinViewModel
- [x] 1.8 Crear `App/Services/KerberosService.swift` y `XPCService.swift`
- [x] 1.9 Crear Info.plists: App-Info.plist, HelperTool-Info.plist, launchd.plist
- [x] 1.10 Crear `setup.sh` con instrucciones para generar el proyecto Xcode

## Phase 2: Helper Tool & Domain Join

NOTA: Todo el código de Phase 2 ya fue escrito en PR 1 (inline en XPCServer.swift y las vistas).
Pendiente: refinamiento de validación XPC, hardening y PR final.

- [x] 2.1 Crear `HelperTool/main.swift` con `NSXPCListener` service
- [x] 2.2 Crear `HelperTool/XPCServer.swift` con manejo de conexiones XPC
- [x] 2.3 Crear wrapper de `dsconfigad` (inline en XPCServer.swift)
- [x] 2.4 Crear vista `App/Views/DomainJoinView.swift`
- [x] 2.5 Crear `App/ViewModels/DomainJoinViewModel.swift`
- [x] 2.6 Implementar pre-flight checks inline (dns, time, ldap, kdc, bind)
- [x] 2.7 Crear `App/Views/DiagnosticsView.swift`
- [x] 2.8 Manejar errores conocidos en XPCServer.swift (OU, creds, duplicados)
- [x] 2.9 Refinar validación de conexión XPC (SecCodeCopyGuestWithAttributes + PID audit)
- [x] 2.10 Migrar passwords de shell args a environment variables en XPCServer.swift
- [x] 2.11 Agregar XcodeGen project.yml para build automatizado
- [x] 2.12 Agregar App.entitlements y actualizar setup.sh

## Phase 3: Password Change Flow

NOTA: Todo el código de Phase 3 ya fue escrito en PR 1 (flujo completo implementado en PasswordChangeViewModel).
Pendiente: testing en hardware real y refinamiento de mensajes de error.

- [x] 3.1 Conectar `KerberosService` con `GSSBridge` via bridging header
- [x] 3.2 Sincronización local via sysadminctl (inline en XPCServer.swift)
- [x] 3.3 Sincronización keychain via security CLI (inline en XPCServer.swift)
- [x] 3.4 Crear `App/Views/PasswordChangeView.swift`
- [x] 3.5 Crear `App/ViewModels/PasswordChangeViewModel.swift`
- [x] 3.6 Flujo transaccional completo GSS → local → keychain
- [x] 3.7 Manejo de errores Kerberos, GPO, red
- [x] 3.8 Session log exportable para auditoría

## Phase 4: Hardening & Testing

- [ ] 4.1 Verificar código en Mac real con Xcode
- [ ] 4.2 Probar join a dominio con AD de producción controlado
- [ ] 4.3 Probar cambio de contraseña AD via GSS.framework
- [ ] 4.4 Probar sync local y keychain post-cambio
- [ ] 4.5 Ajustar mensajes de error según resultados de prueba
- [ ] 4.6 Firmar app + helper tool con Developer ID
- [ ] 4.7 Ejecutar verify contra specs
