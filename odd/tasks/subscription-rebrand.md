# Safe subscription rebranding
Objective: prepare a brand-only, version-aware subscription localization workflow without running Apple account operations.
Branch: feat/subscription-rebrand; baseline: 4a7c3a7625321cc4d675ec919554b8537d8228fb; delivery: single-pr (no remote delivery authorized); forecast: approximately 750 authored lines; runner: Python unittest.

## Specs
S1. "Primero inspecciona el proyecto", including "scripts/app_store_connect/", "subscription_texts.example.json", "Los scripts de automatización existentes." and "La configuración de autenticación con Apple." Consult "la documentación actual de la API, incluido el sistema de Subscription Versions y Subscription Localizations v2."
S2. "Consulte las suscripciones y localizaciones reales de App Store Connect." Products: "premium_monthly" and "premium_yearly". "Compare los textos actuales con los del proyecto."
S3. "Sustituya exclusivamente las referencias comerciales antiguas por RepBuzz, conservando las traducciones correspondientes." "Muestre una vista previa por suscripción e idioma, con valores anteriores y nuevos."
S4. "Permita aplicar los cambios automáticamente después de mi autorización explícita." "Compruebe posteriormente que todas las localizaciones se han actualizado."
S5. "No modificar Product IDs." "No modificar precios, duración, niveles ni condiciones de las suscripciones." "No crear suscripciones nuevas." "No eliminar localizaciones." "No modificar archivos de la aplicación innecesariamente." "No enviar nada a revisión ni publicar cambios." "No almacenar credenciales privadas en Git." "El modo inicial debe ser exclusivamente de lectura y simulación (dry-run)."
S6. "Si necesitamos configurar una API Key de Apple, explícame exactamente cómo hacerlo y cómo utilizarla de forma segura." "Implementa la automatización en el proyecto, pero no ejecutes ninguna operación de escritura contra App Store Connect." "Al finalizar, entrégame el informe de cambios propuestos y las instrucciones para ejecutar la actualización una vez autorizada."

## Tasks
- T1 | S1-S6 | inline; no writer trigger; one cohesive tool, tests and documentation | complete: local implementation and offline verification; live inventory not executed | commit: 8944161 | Risk: item 2 (Bearer-token transport and remote mutation guards); independent verification completed.

## Log
L1. User request, verbatim:
> nose, si es necesario para el siguiente prompt si si no haz el prompt directamnete: Necesito automatizar el cambio de nombre comercial de las suscripciones de mi aplicación iOS, anteriormente Gym Timer Pro y ahora RepBuzz.
>
> En App Store Connect tengo dos suscripciones existentes:
> - premium_monthly
> - premium_yearly
>
> Ambas tienen aproximadamente 15 localizaciones.
>
> Quiero actualizar automáticamente sus nombres visibles y, cuando corresponda, sus descripciones en todos los idiomas mediante la API oficial de App Store Connect.
>
> **Primero inspecciona el proyecto**, especialmente:
> - scripts/app_store_connect/
> - subscription_texts.example.json
> - Los scripts de automatización existentes.
> - La configuración de autenticación con Apple.
>
> Consulta la documentación actual de la API, incluido el sistema de Subscription Versions y Subscription Localizations v2.
>
> Prepara una solución que:
>
> 1. Consulte las suscripciones y localizaciones reales de App Store Connect.
> 2. Compare los textos actuales con los del proyecto.
> 3. Sustituya exclusivamente las referencias comerciales antiguas por RepBuzz, conservando las traducciones correspondientes.
> 4. Muestre una vista previa por suscripción e idioma, con valores anteriores y nuevos.
> 5. Permita aplicar los cambios automáticamente después de mi autorización explícita.
> 6. Compruebe posteriormente que todas las localizaciones se han actualizado.
>
> **Restricciones:**
> - No modificar Product IDs.
> - No modificar precios, duración, niveles ni condiciones de las suscripciones.
> - No crear suscripciones nuevas.
> - No eliminar localizaciones.
> - No modificar archivos de la aplicación innecesariamente.
> - No enviar nada a revisión ni publicar cambios.
> - No almacenar credenciales privadas en Git.
> - El modo inicial debe ser exclusivamente de lectura y simulación (dry-run).
>
> Si necesitamos configurar una API Key de Apple, explícame exactamente cómo hacerlo y cómo utilizarla de forma segura.
>
> Implementa la automatización en el proyecto, pero no ejecutes ninguna operación de escritura contra App Store Connect.
>
> Al finalizar, entrégame el informe de cambios propuestos y las instrucciones para ejecutar la actualización una vez autorizada.

L2. Existing generic updater inspected: full-field v1 replacements, default missing-locale creation, incomplete preview, no post-write verification. Preserve its behavior; add a separate workflow. No Apple account calls or private-key/environment-value inspection authorized or performed.
L3. Apple primary DocC schemas verified: v2 PATCH fields are name/description (not displayName); draft localizations use /v1/subscriptionVersions/{id}/localizations. Only PREPARE_FOR_SUBMISSION is treated as editable. Conservative design: no automatic draft creation or legacy writes; report and block if no unique editable draft. Remote text is authoritative; project differences are reported, never used to overwrite unrelated translations.
L4. One coherent implementation may exceed the approximate 400-line heuristic because credential transport, approval/drift checks, regression tests and safe usage documentation belong together. No artificial split or remote PR operation is planned.
L5. RED observed: unittest failed with ModuleNotFoundError before the new script existed. GREEN: 10 initial tests passed, then all 15 full-suite tests passed after drift/legacy/transport coverage. Commands: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s scripts/app_store_connect -p 'test_rebrand_subscription_localizations.py' -v; full suite uses -p 'test*.py'. --help and git diff --check passed. No live credentials, account reads or remote writes used; live proof is unavailable until an explicitly selected credential is authorized.
L6. Implemented a separate script and guide; old updater, token helper, payload and all app files remain untouched. Preview derives proposals from remote text, reports project differences and missing locales; apply confirms the exact plan digest, refuses drift, checks version and locale again before PATCH, verifies all locales, and never retries writes. Independent verification pending.
L7. Independent verifier found one blocker: explicit --confirm '' without --apply-plan was silently treated as preview. Regression RED reproduced, presence check fixed, independent focused recheck passed 3 tests with zero factory/auth/socket calls. Parent full suite: 21 passed; original app/configuration/scripts/payload bytes match baseline except README. Independent probes retained as regression tests. Native review assessment pending; no live account proof claimed.
L8. Implementation commit 8944161 contains 916 authored insertions as one coherent unit (tool, tests, docs, log). Native assessment high (security item 2); user granted candidate-scoped review through the native question. Four reviews approved the exact immutable candidate; exact acknowledgement returned action=acknowledged, authority=burned, lineage review-36b479d225580652. No scoped correction was requested. Non-blocking advisory R3-partial-apply-coverage: consider future public-CLI tests for a later PATCH failure or loss of editability after an earlier successful write; not accepted as scope expansion.
L9. All live account checks remain unexecuted: no specific credential/session was authorized, no private-key contents or environment values read, no Apple account API requests or writes performed. Local proposal: 30 example names change brand, example descriptions unchanged; actual account preview is still required before authorizing apply. External verifier scratch removed. No pushes, PRs, App Store submissions or publication performed. Local delivery is complete with the documented live-proof limitation.
