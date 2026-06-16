# Proposal: Phase 4 — Hardening & Testing

## Intent

Completar la Phase 4 del AD macOS Toolkit para CISA: arreglar el bug de build que impide compilar en Xcode, limpiar code smells de seguridad, probar contra AD real, ajustar errores según resultados obtenidos, firmar con Apple ID gratuito, y obtener un verify final PASS sin warnings.

## Scope

### In Scope
- Renombrar `gss_bridge.c` → `gss_bridge.m` (Obj-C syntax en `.c`)
- Fix semáforo compartido en PasswordChangeViewModel (race condition sync local/keychain)
- Limpiar passwords en error path del ViewModel (data leak on early return)
- Build con XcodeGen + Xcode en Mac real
- Domain join testing contra AD de CISA (test accounts)
- Password change testing via GSS.framework contra KDC real
- Local + keychain sync testing post-change
- Refinar GPO error mapping según resultados reales
- Firmar con Personal Team (Apple ID gratis, development signing)
- Session log export verification
- Verify final contra specs

### Out of Scope
- Nuevas funcionalidades o refactors no solicitados
- Migrar a SecKeychainChangePassword (YA está implementado)
- Migrar a ODRecord (YA está implementado)
- Developer ID signing para distribución externa
- Unit tests (no hay test runner configurado)
- CI/CD pipeline

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `ad-password-change`: Refinar mapeo de errores GPO/password según resultados de pruebas contra AD real. Los escenarios "Falla por GPO" y "Contraseña actual incorrecta" pueden recibir mensajes más específicos.

## Approach

Three sub-phases:

1. **4a — Build fixes** (Windows, now): rename `.c` → `.m`, replace shared semaphore with two `DispatchGroup`s, add `defer { clearPasswords() }` on error paths, update `project.yml` for `.m` source. Commit, push.

2. **4b — Mac testing**: pull on Mac, `./setup.sh` → XcodeGen → build. Test domain join against CISA AD. Test password change against KDC (port 464). Verify local + keychain sync. Export session logs.

3. **4c — Refinement + verify**: adjust error messages from real AD results. Sign app + helper with Personal Team (Xcode automatic). Run verify against both specs, produce verify-report.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `Sources/GSSBridge/gss_bridge.c` | Renamed | → `gss_bridge.m` |
| `Sources/App/ViewModels/PasswordChangeViewModel.swift` | Modified | Semaphore → DispatchGroup, password cleanup on error |
| `project.yml` | Modified | Add `.m` source reference, Personal Team bundle config |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| AD production testing may affect users | Medium | Test accounts, coordinate with infra |
| GPO mapping may need more iterations | Medium | Document findings, refine in 2nd pass if needed |
| Personal Team signing expires (7 days) | Medium | Re-sign before each use — acceptable for <5 Macs |
| Port 464 blocked on corporate network | Medium | Verify with infra; document limitation |
| `project.yml` config for `.m` may need tuning | Low | Add to sources list under GSSBridge target |

## Rollback Plan

- **Build fixes**: `git revert` the 4a commit → restores `.c`, semaphore, and old cleanup.
- **Testing**: no rollback needed (read-only verification against AD).
- **Signing**: revert to unsigned dev build in Xcode scheme.
- **Error mapping**: revert to original error messages if new ones are less clear.

## Dependencies

- macOS 13+ with Xcode 15+
- CISA AD production access (test accounts)
- Network: ports 464 (Kerberos) and 389 (LDAP) reachable
- Apple ID free account for Personal Team signing
- GitHub remote configured for `apeguero845/AD-Toolkit`

## Success Criteria

- [ ] `gss_bridge.m` compila sin errores en Xcode
- [ ] Domain join funciona con la OU configurada
- [ ] Password change via GSS.framework funciona contra AD real
- [ ] Local account + keychain sincronizados post-cambio
- [ ] Mensajes de error reflejan resultados reales de AD (GPO, credenciales)
- [ ] App + helper firmados con Personal Team
- [ ] Verify report final: **PASS** (sin CRITICAL ni WARNING)
