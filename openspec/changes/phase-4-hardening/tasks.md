# Tasks: Phase 4 — Hardening & Testing

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~50-100 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Delivery strategy | ask-on-risk |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

## Phase 4a: Build Fixes

- [x] 4a.1 Renombrar `Sources/GSSBridge/gss_bridge.c` → `gss_bridge.m` (usa `__bridge`, sintaxis ObjC)
- [x] 4a.2 Actualizar `project.yml` — agregar `gss_bridge.m` como fuente ObjC en target ADToolkit
- [x] 4a.3 Reemplazar `DispatchSemaphore` compartido en `PasswordChangeViewModel` con dos `DispatchGroup` independientes para syncLocal y syncKeychain
- [x] 4a.4 Agregar `defer { clearPasswords() }` en `changePassword()` para limpiar passwords en error path

## Phase 4b: Mac Testing

- [ ] 4b.1 Clonar repo en Mac, ejecutar `./setup.sh` + XcodeGen, build con Xcode
- [ ] 4b.2 Probar domain join contra AD de CISA con OU real (`OU=CISA_Laptops,...`)
- [ ] 4b.3 Probar password change via GSS.framework contra KDC real (puerto 464)
- [ ] 4b.4 Probar sync de cuenta local + keychain post-cambio
- [ ] 4b.5 Verificar export de session log
- [ ] 4b.6 Documentar errores reales de AD (códigos minor status de GSS) para refinar GPO mapping

## Phase 4c: Refinement + Signing + Verify

- [ ] 4c.1 Refinar mensajes de error en `gss_bridge.c` según resultados de testing (GPO, credenciales, timeout 464, password history)
- [ ] 4c.2 Firmar app + helper con Personal Team (Apple ID gratis, signing automático de Xcode)
- [ ] 4c.3 Ejecutar verify formal contra specs base y delta — producir verify-report
- [ ] 4c.4 Crear PR final con todos los cambios de Phase 4 en `main`
