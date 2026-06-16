# Exploration: AD macOS Toolkit

## Current State

### Domain Join
Actualmente se usa `dsconfigad` manualmente desde terminal:

```bash
sudo dsconfigad -add <DOMINIO> -computer "<NOMBRE_EQUIPO>" \
  -username "<USUARIO_ADMIN>" \
  -ou "<OU_DESTINO>" -force
```

El comando funciona pero requiere que soporte:
1. Conozca los parámetros exactos (OU, dominio, usuario admin)
2. Ejecute manualmente con `sudo`
3. Maneje errores como los documentados (DNS, time sync, container not exist)

### Password Change
El flujo de cambio de contraseña tiene estas limitaciones:

| Método | Resultado | Problema |
|--------|-----------|----------|
| `dscl . -passwd` | Error -14165 | GPO complexity policy |
| `sysadminctl` | "Éxito" local | **NO** cambia en AD — desincroniza |
| `kpasswd usuario@CESARIGLESIAS.LOCAL` | ✅ Funciona | Interactivo (abre /dev/tty) |
| System Settings > Users & Groups | ✅ Funciona | Requiere conexión al dominio |

La causa raíz: el AD tiene políticas estrictas (posiblemente LDAPS requerido) y las herramientas de macOS no pueden negociar correctamente el cambio. `kpasswd` con Kerberos es el único camino confiable por CLI.

## Affected Areas

| Componente | Rol |
|---|---|
| `Kerberos.framework` | Framework nativo de Apple para autenticación Kerberos. Incluye `krb5_change_password()` |
| `dsconfigad` | Herramienta de DirectoryService para bind/unbind a AD |
| `sysadminctl` | Herramienta moderna de Apple para gestión de usuarios locales |
| `OpenDirectory.framework` | Framework para interacción con directorios (AD, LDAP) |
| `SMAppService` | API moderna (macOS 13+) para instalar privileged helper tools |
| Keychain (`~/Library/Keychains/`) | Almacena contraseñas cifradas; debe sincronizarse tras cambio |
| `/private/var/db/dslocal/` | Cache local de credenciales para cuentas mobile |

## Approaches

### Approach 1: Swift App + Privileged Helper con API Kerberos nativa (RECOMENDADA)

Arquitectura:
```
┌─────────────────────────────────────┐
│  SwiftUI App (frontend UI)          │
│  - Interfaz para cambio de clave    │
│  - Interfaz para unión a dominio    │
│  - Logs transparentes para soporte  │
└──────────────┬──────────────────────┘
               │ XPC (IPC seguro)
┌──────────────▼──────────────────────┐
│  Privileged Helper Tool (root)      │
│  - C helper con Kerberos.framework  │
│    → krb5_change_password()         │
│  - dsconfigad via NSTask            │
│  - sysadminctl para sync local      │
└─────────────────────────────────────┘
```

- **Pros**: Más robusto, sin passwords en CLI, manejo de errores centralizado, Apple-approved (SMAppService)
- **Cons**: Mayor complejidad inicial, requiere signing (Apple Developer Program), macOS 13+ para SMAppService
- **Esfuerzo**: Alto (2-3 semanas)

### Approach 2: Swift App con `expect` para `kpasswd` + AuthorizationExecuteWithPrivileges

```
┌─────────────────────────────────────┐
│  SwiftUI App                        │
│  - Llama expect script embebido     │
│  - dsconfigad via AuthExec          │
└─────────────────────────────────────┘
```

- **Pros**: Simple, sin helper tool, funciona en macOS 11+
- **Cons**: Frágil (expect depende del output de kpasswd), poco seguro (passwords en pipes), AuthorizationExecuteWithPrivileges deprecated
- **Esfuerzo**: Medio (1 semana)

### Approach 3: CLI Tool en bash + `expect` (menos ambicioso)

```
ad-tool
├── ad-tool join     → dsconfigad wrapper
├── ad-tool passwd   → expect + kpasswd
└── ad-tool status   → diagnóstico
```

- **Pros**: Rápido de implementar, funciona en cualquier macOS
- **Cons**: Sin interfaz gráfica, menos transparente para soporte, expect es frágil
- **Esfuerzo**: Bajo (2-3 días)

## Recommendation

**Approach 1** es la recomendada para producción. Razones:

1. **Transparencia para soporte** → GUI nativa SwiftUI, con logs claros, barras de progreso, y pasos guiados
2. **Seguridad** → XPC con helper firmado, sin passwords en argumentos de CLI
3. **Robustez** → `krb5_change_password()` es la API oficial de MIT Kerberos, no un script frágil
4. **Futuro-proof** → `SMAppService` es el reemplazo moderno de `SMJobBless`, Apple-approved
5. **Sync completo** → Podemos coordinar: AD → local → Keychain en un solo flujo

Sin embargo, para **entrega rápida** podemos hacer un MVP en Approach 3 (CLI tool) y después wrappearlo en la GUI.

## Risks

| Riesgo | Mitigación |
|--------|------------|
| Apple Developer Program requerido para signing del helper | Usar signing con certificado interno o MDM |
| SMAppService requiere aprobación manual en Settings > Login Items | Documentar el paso en la UI de la app |
| `krb5_change_password()` requiere C/ObjC bridging | Crear un pequeño wrapper en C, embebido como helper |
| macOS 13+ requerido para SMAppService (Ventura/Sonoma/Sequoia) | Verificar qué versión de macOS usan en CISA |
| La política GPO de AD puede rechazar cambios vía Kerberos | Validar con el equipo de infraestructura de AD |
| Keychain desync si el cambio falla a mitad del flujo | Diseñar el flujo como transacción: AD → local → keychain, con rollback |

## Ready for Proposal

**Yes**. Pasamos a la fase de propuesta para definir la arquitectura en detalle y crear los specs.
