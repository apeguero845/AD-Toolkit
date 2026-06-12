# Delta for ad-password-change

## MODIFIED Requirements

### Requirement: Cambio de contraseña en AD via Kerberos

The system MUST change the user's AD password using `gss_aapl_change_password()` from GSS.framework.

The system MUST authenticate to the Kerberos KDC using the user's current credentials before attempting the password change.

The system MUST validate that the new password meets AD complexity policies (GPO) before sending to the server.

The system SHALL use `GSSCreateName()` with the format `userPrincipal@REALM` (e.g., `usuario@CESARIGLESIAS.LOCAL`).

The system SHOULD map specific GSS minor status codes from real AD responses to distinct user-facing messages, rather than falling back to a generic GSS error.
(Previously: Generic GSS error mapping; refined to map real AD error codes post-testing)

#### Scenario: Cambio exitoso con sync completo

- GIVEN the user is connected to the corporate network (AD reachable)
- AND the user knows their current password
- WHEN the user enters current password, new password, and confirms new password
- AND the new password meets GPO complexity requirements
- THEN the password is changed in AD via `gss_aapl_change_password()`
- AND the local mobile account password is updated via OpenDirectory
- AND the login keychain password is updated via `SecKeychainChangePassword()`
- AND the app shows "Contraseña actualizada correctamente" with green checkmark

#### Scenario: Falla por política de complejidad (GPO)

- GIVEN the user enters a new password that does NOT meet AD complexity policies
- WHEN the system calls `gss_aapl_change_password()`
- THEN the GSS framework returns `GSS_S_FAILURE` with a minor status indicating password policy rejection (minor status code mapped from real AD testing)
- AND the app SHOWs: "La contraseña no cumple con las políticas de seguridad de la empresa"
- AND the local account and keychain are NOT modified (transactional rollback)
- AND the user is prompted to try a different password

#### Scenario: Red/KDC no disponible

- GIVEN the Mac is not connected to the corporate network or VPN
- WHEN the user attempts to change password
- THEN the app detects connectivity failure via LDAP ping or Kerberos ticket check
- AND the app SHOWs: "No se puede conectar con el servidor de dominio. Verificá que estés en la red corporativa o conectado a VPN."
- AND no changes are made to any system

#### Scenario: Contraseña actual incorrecta

- GIVEN the user enters an incorrect current password
- WHEN the system calls `gss_aapl_change_password()`
- THEN the GSS framework returns `GSS_S_FAILURE` with a minor status indicating invalid credentials (error code mapped from real AD testing)
- AND the app SHOWs: "La contraseña actual no es correcta. Intentá de nuevo."
- AND no changes are made

#### Scenario: Timeout de KDC en puerto 464

- GIVEN the Mac has network connectivity (LDAP ping succeeds) but the KDC does not respond on port 464 (Kerberos password change service)
- WHEN the system calls `gss_aapl_change_password()`
- THEN the GSS framework returns a timeout or unreachable error
- AND the app SHOWs: "El servidor de dominio no respondió en el puerto de cambio de contraseña (464). Verificá que el puerto esté accesible en la red corporativa o VPN."
- AND no changes are made to any system

#### Scenario: Rechazo por historial de contraseñas

- GIVEN the user enters a new password that matches a recently used password (AD password history policy)
- WHEN the system calls `gss_aapl_change_password()`
- THEN the GSS framework returns `GSS_S_FAILURE` with a minor status indicating password history violation
- AND the app SHOWs: "La contraseña ya fue usada recientemente. Elegí una contraseña que no hayas usado antes."
- AND no changes are made to local account or keychain
- AND the user is prompted to try a different password
