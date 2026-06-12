# AD Password Change Specification

## Purpose

Permitir al equipo de soporte cambiar la contraseña de un usuario en Active Directory desde una Mac, asegurando que el cambio se refleje en AD, en la cuenta mobile local, y en el login keychain del usuario. Todo el proceso debe ser transparente, con feedback claro en cada paso.

## Requirements

### Requirement: Cambio de contraseña en AD via Kerberos

The system MUST change the user's AD password using `gss_aapl_change_password()` from GSS.framework.

The system MUST authenticate to the Kerberos KDC using the user's current credentials before attempting the password change.

The system MUST validate that the new password meets AD complexity policies (GPO) before sending to the server.

The system SHALL use `GSSCreateName()` with the format `userPrincipal@REALM` (e.g., `usuario@CESARIGLESIAS.LOCAL`).

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
- THEN the server returns a Kerberos error indicating password quality check failed
- AND the app SHOWs the specific error: "La contraseña no cumple con las políticas de seguridad de la empresa"
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
- WHEN the system attempts Kerberos authentication with the current password
- THEN Kerberos authentication fails with invalid credentials error
- AND the app SHOWs: "La contraseña actual no es correcta. Intentá de nuevo."
- AND no changes are made

### Requirement: Sincronización de cuenta mobile local

After a successful AD password change, the system MUST update the locally cached mobile account password in `/private/var/db/dslocal/`.

The system MUST use the OpenDirectory framework (`ODRecord`) to change the local password.

If the local sync fails AFTER the AD change succeeded, the system SHOULD log the error and report it to the user, but the AD change is NOT rolled back (AD is source of truth).

#### Scenario: Sync local exitoso

- GIVEN the AD password was changed successfully
- WHEN the system updates the local OD record
- THEN the local password matches the new AD password
- AND the user can log in with the new password even without network connectivity

#### Scenario: Sync local falla

- GIVEN the AD password was changed successfully
- WHEN the local OD record update fails (e.g., permission error)
- THEN the app SHOWs: "La contraseña se cambió en AD pero no se pudo sincronizar localmente. El usuario deberá conectarse a la red corporativa e iniciar sesión para sincronizar."
- AND the failure is logged

### Requirement: Sincronización de login keychain

After updating the local mobile account password, the system MUST update the login keychain password using `SecKeychainChangePassword()`.

If the keychain old password does not match (e.g., user had previously changed it locally), the system SHOULD offer to create a new login keychain as fallback.

#### Scenario: Keychain sync exitoso

- GIVEN the local password was updated successfully
- WHEN the system calls `SecKeychainChangePassword()`
- THEN the login keychain password matches the new account password
- AND the user does NOT see keychain prompts after login

#### Scenario: Keychain desincronizado previo

- GIVEN the user's login keychain has a different password than their account (pre-existing desync)
- WHEN `SecKeychainChangePassword()` fails with "incorrect old password"
- THEN the app SHOWs: "No se pudo actualizar el llavero automáticamente. ¿Querés crear un llavero nuevo? (Esto borrará las contraseñas guardadas actuales)"
- AND the app offers "Crear nuevo" / "Omitir" buttons
