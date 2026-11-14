# RepBuzz Spanish promotional screenshots
Objective: reproduce the approved visual direction using Frameit and ImageMagick, with current real Premium screenshots.
Branch: feat/repbuzz-promo-design (base 8689c1c). Delivery: feature-branch-chain selected by the user; approximately 460 implementation/tracking lines plus generated provenance and binary assets; no remote delivery. Runner: Python unittest plus actual five-image rendering and isolated Xcode UI captures.

## Specs
- S1: “Vamos a implementar el nuevo diseño de las capturas promocionales de RepBuzz para la App Store utilizando la infraestructura Fastlane/Frameit existente en el repositorio.”
- S2: “Fondo degradado azul marino con detalles luminosos azules y naranjas.” “Icono de RepBuzz y nombre en la parte superior.” “Titular grande, blanco y destacado.” “Subtítulo descriptivo.” “iPhone grande mostrando una captura real de la aplicación.” “Estética moderna, limpia y consistente entre todas las imágenes.”
- S3: “Controla tus descansos” — “02_Timer” — “Sigue cada serie con un temporizador claro, rápido y fácil de usar”.
- S4: “Organiza tus rutinas” — “11_RoutinesCatalog” — “Crea, clasifica y encuentra tus entrenamientos en segundos”.
- S5: “Visualiza tu progreso” — “20_ProgressMonth” — “Consulta tu actividad y sigue tu evolución”.
- S6: “Personaliza tus rutinas” — “12_RoutineEditor” — “Adapta cada entrenamiento a tus objetivos”.
- S7: “Cada entrenamiento cuenta” — “05_TrainingCompleted” — “Completa tus sesiones y registra tu esfuerzo”.
- S8: “Reutiliza Fastlane Frameit y los scripts existentes siempre que sea viable.” “No desarrolles un generador nuevo desde cero.” “Extrae de los dos mockups una plantilla visual reutilizable, con textos, capturas, posiciones y fondos configurables.”
- S9: “Usa capturas reales de la versión actual de RepBuzz, no imágenes recreadas mediante IA.” “Las pantallas 4 y 5 necesitan capturas actualizadas antes de utilizarlas.” “Corrige la correspondencia entre identificadores de pantalla, imágenes y titulares.” “Evita reutilizar resultados antiguos o imágenes de versiones anteriores.”
- S10: “Mantén dimensiones compatibles con el formato de App Store correspondiente.” “Si Frameit no permite reproducir determinados efectos visuales, utiliza las herramientas gráficas existentes en el proyecto, como ImageMagick, para complementarlo.” “Conserva la automatización y facilita futuras actualizaciones de las capturas.”
- S11: “Implementa el sistema y genera las cinco imágenes inicialmente en español, con interfaz española.” “Comprueba que cada imagen utiliza la pantalla correcta y que el diseño reproduce fielmente el estilo aprobado.” “Facilítame los cinco PNG finales y un resumen de los cambios realizados en el repositorio.”
- S12: “No generes todavía los otros catorce idiomas, no subas imágenes a App Store Connect y no publiques nada.” “Primero revisaremos los cinco resultados españoles. Una vez aprobados, extenderemos el sistema a los quince idiomas.”

## Tasks
- T1 [S6-S7,S9,S11]: current Premium editor/completed originals; inline route with per-action Xcode capture worker; verified 1.3.1(4), 1 UI test/0 failures, source fingerprints checked; commit 69c96ac; native medium/under_budget.
- T2 [S1-S5,S8-S12]: configurable explicit five-screen Frameit/ImageMagick design, tests and documentation; inline route, no writer trigger; implemented, observed RED (missing implementation) then GREEN (6 tests); commit pending.
- T3 [S2-S12]: five final Spanish PNGs rendered and visually inspected; inline route; hashes/dimensions/mapping verified, legacy invalid-device differential identical; commit and native assessment pending delivery strategy decision.

## Log
- L1 — Original request (2026-11-14):

Vamos a implementar el nuevo diseño de las capturas promocionales de RepBuzz para la App Store utilizando la infraestructura Fastlane/Frameit existente en el repositorio.

**Diseño aprobado**

Adjunto dos mockups de referencia:
1. Controla tus descansos.
2. Organiza tus rutinas.

Ambos establecen la identidad visual que queremos conservar:
- Fondo degradado azul marino con detalles luminosos azules y naranjas.
- Icono de RepBuzz y nombre en la parte superior.
- Titular grande, blanco y destacado.
- Subtítulo descriptivo.
- iPhone grande mostrando una captura real de la aplicación.
- Estética moderna, limpia y consistente entre todas las imágenes.

**Imágenes que debemos generar**

1. **Controla tus descansos**
   - Pantalla: `02_Timer`
   - Subtítulo: «Sigue cada serie con un temporizador claro, rápido y fácil de usar».

2. **Organiza tus rutinas**
   - Pantalla: `11_RoutinesCatalog`
   - Subtítulo: «Crea, clasifica y encuentra tus entrenamientos en segundos».

3. **Visualiza tu progreso**
   - Pantalla: `20_ProgressMonth`
   - Subtítulo: «Consulta tu actividad y sigue tu evolución».

4. **Personaliza tus rutinas**
   - Pantalla: `12_RoutineEditor`
   - Subtítulo: «Adapta cada entrenamiento a tus objetivos».

5. **Cada entrenamiento cuenta**
   - Pantalla: `05_TrainingCompleted`
   - Subtítulo: «Completa tus sesiones y registra tu esfuerzo».

**Implementación**

- Reutiliza Fastlane Frameit y los scripts existentes siempre que sea viable.
- No desarrolles un generador nuevo desde cero.
- Extrae de los dos mockups una plantilla visual reutilizable, con textos, capturas, posiciones y fondos configurables.
- Usa capturas reales de la versión actual de RepBuzz, no imágenes recreadas mediante IA.
- Las pantallas 4 y 5 necesitan capturas actualizadas antes de utilizarlas.
- Corrige la correspondencia entre identificadores de pantalla, imágenes y titulares.
- Evita reutilizar resultados antiguos o imágenes de versiones anteriores.
- Mantén dimensiones compatibles con el formato de App Store correspondiente.
- Si Frameit no permite reproducir determinados efectos visuales, utiliza las herramientas gráficas existentes en el proyecto, como ImageMagick, para complementarlo.
- Conserva la automatización y facilita futuras actualizaciones de las capturas.

**Primera entrega**

Implementa el sistema y genera las cinco imágenes inicialmente en español, con interfaz española.

Comprueba que cada imagen utiliza la pantalla correcta y que el diseño reproduce fielmente el estilo aprobado.

Facilítame los cinco PNG finales y un resumen de los cambios realizados en el repositorio.

No generes todavía los otros catorce idiomas, no subas imágenes a App Store Connect y no publiques nada.

Primero revisaremos los cinco resultados españoles. Una vez aprobados, extenderemos el sistema a los quince idiomas.
- L2 — Existing dirty project/ASC files and references are user state and must remain untouched. Current project is 1.3.1(4). Existing Spanish Premium references were generated this session using local StoreKit Testing; no real purchases. Keep Premium for the new screens.
- L3 — Visual tokens: deep navy #020D34/#071A46, electric blue #087BFF, warm orange #FF850B, white #FFFFFF, subtitle #E3E8F4. Large centered two-line headlines, 09:41 phone, top icon/name lockup, diagonal luminous corner accents. Reference mockups guide layout, not source pixels.
- L4 — New optional --design-config route in the existing pipeline uses Frameit easy-mode framing and an ImageMagick composition stage. Explicit five-screen manifest replaces alphabetical selection for this delivery; legacy setup is unchanged and documented separately. Real iPhone 17 Pro Max screenshots are normalized only in temporary copies to fit the cached black iPhone 14 Pro Max bezel; final RGB PNGs are 1290x2796.
- L5 — Editor/completion captures use existing local StoreKit Testing and unchanged production sources. All five inputs match approved source hashes; additional capture provenance checks current production fingerprints even within the same version/build. No AI image generation, downloads, installs, uploads or other locales.
- L6 — Checks: 6 unittest tests pass; bash -n passes; legacy invalid-device stdout/stderr/exit identical to HEAD. Frameit produced all five frames and every exported PNG/source matches manifest hashes. Final contact-sheet visual review and five browser previews completed. A temporary contact-sheet command failed due to an unset ImageMagick default font, then succeeded with explicit Arial; deliverables unaffected.
- L7 — Native assessment initially required explicit untracked scope. Selectorless STATUS supplied inventory; assessment over committed 8689c1c..69c96ac with exact inventory and untracked-scope=exclude succeeded: medium, review_due=false, under_budget. Boundary remains 8689c1c. Unrelated dirty project/ASC files are excluded from the committed range. Effective RDD is on by default; no review or consent was started.
- L8 — Risk: none. The production app, subscription implementation, existing renderer path and shared option parser are unchanged; the optional branded route is new and isolated. Native unassessable tier does not add an independent verifier by itself.
- L9 — User decision: “Sobre rama de trabajo (Recomendado)”. Created dedicated local feature branch from the original HEAD; no push, PR or publication authorized. Two coherent units: reference captures/provenance, then composition with tests/docs. The renderer unit includes its tracking record and naturally exceeds the approximate 400-line heuristic; behavior/tests/docs remain together.
