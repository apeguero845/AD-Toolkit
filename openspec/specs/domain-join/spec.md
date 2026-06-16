# Domain Join Specification

## Purpose

Permitir al equipo de soporte unir una Mac al dominio Active Directory de forma automatizada, con diagnóstico previo, feedback claro de cada paso, y manejo de los errores conocidos documentados.

## Requirements

### Requirement: Diagnóstico pre-vuelo

Before attempting to join the domain, the system MUST run pre-flight checks:
1. DNS resolution: resolve the AD domain
2. Time sync: compare system time with the domain controller
3. Network connectivity: reach the KDC on port 464 and LDAP on port 389
4. Existing bind: check if the computer is already bound to AD

Each check MUST display a clear pass/fail status in real time.

If ANY check fails, the system SHALL NOT proceed with domain join and MUST show an actionable error message.

#### Scenario: All pre-flight checks pass

- GIVEN the Mac has network access to the domain
- AND DNS resolves correctly
- AND time is within 5 minutes of the DC time
- WHEN the user clicks "Iniciar diagnóstico"
- THEN each check shows a green checkmark
- AND the "Unir al dominio" button becomes enabled

#### Scenario: DNS resolution fails

- GIVEN the Mac cannot resolve the AD domain
- WHEN the DNS check runs
- THEN the check shows a red X
- AND the app SHOWs: "No se puede resolver el dominio. Verificá que el DNS esté configurado correctamente en Redes > DNS."
- AND the join button stays disabled

#### Scenario: Time sync fails

- GIVEN the Mac's clock differs from the DC by more than 5 minutes
- WHEN the time check runs
- THEN the check shows a red X
- AND the app SHOWs: "El reloj del Mac está desincronizado. Diferencia: X minutos. Se recomienda sincronizar con: `sudo sntp -sS <IP_DEL_DC>`"
- AND optionally offers a "Sincronizar ahora" button that runs `sntp`

### Requirement: Unión al dominio con dsconfigad

The system MUST join the Mac to the configured AD domain using `dsconfigad` executed via the Privileged Helper Tool (root).

The system MUST accept the following parameters (with sensible defaults for CISA):
- **Computer name**: defaults to current hostname, editable
- **OU path**: defaults to the configured AD OU, editable
- **Admin username**: text input for AD admin account
- **Admin password**: secure text input

The system MUST use the helper tool's XPC service to execute the command as root:
```
dsconfigad -add <DOMINIO> -computer "{name}" -username "{admin}" -ou "{ou}" -force
```

After successful join, the system SHOULD present summary info: domain, computer name (normalized to lowercase by Apple), OU path.

#### Scenario: Domain join exitoso

- GIVEN all pre-flight checks pass
- AND the user has entered valid admin credentials
- WHEN the user clicks "Unir al dominio"
- THEN the helper tool executes dsconfigad with the provided parameters
- AND dsconfigad returns success
- AND the app SHOWs: "Equipo unido al dominio exitosamente" with summary details
- AND the app recommends restarting the session

#### Scenario: OU no existe

- GIVEN the specified OU path does not exist in AD
- WHEN dsconfigad runs with `-ou "OU=Invalid,DC=cesariglesias,DC=local"`
- THEN dsconfigad returns "Container does not exist" error
- AND the app SHOWs: "La OU especificada no existe. Verificá la ruta con el equipo de infraestructura."
- AND suggests the correct OU format (configurable per environment)

#### Scenario: Credenciales inválidas

- GIVEN the admin credentials are incorrect
- WHEN dsconfigad authenticates
- THEN the server returns "Invalid credentials supplied" (Error 5002)
- AND the app SHOWs: "Credenciales inválidas. Verificá el usuario y contraseña del administrador de dominio."

#### Scenario: Equipo ya existe en AD

- GIVEN the computer already exists as an object in AD
- WHEN dsconfigad tries to create the computer account
- THEN the command can be re-run with `-force` flag (already included)
- AND the bind proceeds (existing account is overwritten)
- AND the app SHOWs a warning: "El equipo ya existía en AD. Se actualizó el registro existente."

### Requirement: Remover del dominio

The system SHOULD support removing the Mac from the domain using the helper tool.

The system MUST execute:
```
dsconfigad -remove -force -computer "{name}" -username "{admin}"
```

#### Scenario: Removal exitoso

- GIVEN the Mac is currently bound to the domain
- WHEN the user clicks "Remover del dominio"
- AND confirms the action
- THEN dsconfigad removes the bind
- AND the app SHOWs: "Equipo removido del dominio exitosamente"
- AND recommends restart
