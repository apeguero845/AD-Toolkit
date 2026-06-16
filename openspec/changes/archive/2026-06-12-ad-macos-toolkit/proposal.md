# Proposal: AD macOS Toolkit

## Intent

Soporte de CISA necesita una herramienta unificada para unir Macs al dominio y cambiar contraseñas AD sin depender de comandos manuales (dsconfigad, kpasswd) o scripts frágiles. La app debe ser transparente para cualquier técnico de soporte: GUI clara, logs legibles, manejo de errores conocido.

## Scope

### In Scope

- SwiftUI app con pantallas: cambio de contraseña, unión a dominio, diagnóstico/logs
- Bridge C/Obj-C a GSS.framework para cambio de password Kerberos (`gss_aapl_change_password`)
- Privileged Helper Tool vía SMAppService + XPC para operaciones root (dsconfigad, sysadminctl)
- Sync de cuenta mobile local (OpenDirectory) + Keychain (SecKeychainChangePassword)
- Manejo de errores conocidos: DNS, time sync, OU no encontrada, computadora duplicada, GPO policy
- Logs detallados por paso para auditoría de soporte

### Out of Scope

- MDM / Configuration Profiles para bind automático (iniciativa separada)
- Recovery key de FileVault
- Self-service portal para usuarios finales
- Soporte Windows o Linux
- Integración con Entra ID (Azure AD)

## Capabilities

### New Capabilities

- `ad-password-change`: Cambiar contraseña AD via Kerberos (GSS.framework), sincronizar cuenta mobile local y login keychain. Flujo transaccional: si falla AD, no toca nada local.
- `domain-join`: Unir macOS a Active Directory con OU configurable. Incluye diagnóstico pre-vuelo (DNS, time sync, conectividad) y manejo de errores documentados.

### Modified Capabilities

None. This is a new project with no existing capabilities.

## Approach

Arquitectura de 3 capas:

```
┌──────────────────────────────────────────┐
│  Capa 1: SwiftUI App                     │
│  - Cambio de contraseña (3 fields UI)    │
│  - Unión a dominio (formulario OU/creds) │
│  - Diagnóstico (checklist pre-vuelo)     │
│  - Logs de sesión exportables            │
├──────────────────────────────────────────┤
│  Capa 2: GSS Bridge (C/Obj-C)            │
│  - gss_aapl_change_password()            │
│  - GSSCreateName() / gss_release_name()  │
│  - Manejo de errores Kerberos            │
├──────────────────────────────────────────┤
│  Capa 3: Helper Tool (root via XPC)      │
│  - SMAppService + NSXPCConnection        │
│  - dsconfigad wrapper                    │
│  - sysadminctl wrapper                   │
│  - SecKeychainChangePassword             │
└──────────────────────────────────────────┘
```

Referencia principal: [xcreds (Twocanoes)](https://github.com/twocanoes/xcreds) para el flujo GSS + keychain. [SwiftAuthorizationSample](https://github.com/trilemma-dev/SwiftAuthorizationSample) para SMAppService + XPC.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `ad-toolkit/` | New | Proyecto Xcode con app SwiftUI |
| `ad-toolkit/GSSBridge/` | New | C/Obj-C bridge para GSS.framework |
| `ad-toolkit/HelperTool/` | New | Helper tool con SMAppService + XPC |
| `ad-toolkit/HelperTool/XPCServer.swift` | New | XPC service definition |
| `ad-toolkit/App/Screens/PasswordChangeView.swift` | New | UI cambio de contraseña |
| `ad-toolkit/App/Screens/DomainJoinView.swift` | New | UI unión a dominio |
| `ad-toolkit/App/Screens/DiagnosticsView.swift` | New | UI diagnóstico |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Apple Developer Program required for helper signing | High | Usar signing con certificado de empresa o MDM |
| SMAppService requiere aprobación manual en Settings > Login Items | Medium | Documentar en la UI el paso exacto |
| GPO policies de AD pueden rechazar cambios vía GSS | Medium | Validar con infraestructura; el flujo ya reporta error al usuario |
| macOS 13+ (Ventura) mínimo por SMAppService | Medium | Verificar versión en parque actual de CISA |
| Keychain desync si el proceso se interrumpe | Low | Flujo transaccional: AD → local → keychain con rollback parcial |

## Rollback Plan

- **Domain join**: `sudo dsconfigad -remove -force -computer <name> -username <admin>`. App puede generar el comando automáticamente.
- **Password change**: AD es fuente de verdad. Si falla la sync local, la cuenta sigue funcionando con el nuevo password al reconectar. Keychain se puede reparar manualmente desde Keychain Access.

## Dependencies

- Apple Developer Program signing certificate (o certificado interno)
- macOS 13+ (Ventura) — SMAppService requiere esta versión mínima
- Acceso de red al KDC/AD (tcp/464 kpasswd, tcp/389 LDAP)
- Referencia: código fuente de xcreds (Twocanoes) y SwiftAuthorizationSample

## Success Criteria

- [ ] Password change funciona cumpliendo políticas GPO de complejidad de CISA
- [ ] Cuenta mobile local + login keychain quedan sincronizados post-cambio
- [ ] Domain join funciona con la OU configurada
- [ ] Cada error conocido (DNS, time, OU, duplicado) muestra mensaje accionable al técnico
- [ ] Los logs de la sesión son exportables para auditoría de soporte
- [ ] Toda la funcionalidad opera sin intervención del usuario fuera de la GUI de la app
