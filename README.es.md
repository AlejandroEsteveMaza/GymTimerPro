# GymTimerPro

GymTimerPro es una app iOS (SwiftUI) para controlar los descansos entre series en el gimnasio: configuras series + tiempo de descanso y arrancas un contador de forma rápida.

## Características

- Configuración de series totales y duración del descanso.
- Cuenta atrás en pantalla con actualización cada segundo.
- Live Activity (Lock Screen / Dynamic Island) con serie actual, tiempo restante y modo.
- Botón de reinicio con pulsación larga (evita reinicios accidentales).
- Persistencia del temporizador (UserDefaults) para mantener el estado al pasar a background/foreground.
- Mantiene la pantalla activa mientras la app está abierta (desactiva el idle timer).

## Live Activities / Notificaciones

- El widget (`ActivityKit`) muestra la cuenta atrás en la pantalla de bloqueo y Dynamic Island (si el dispositivo lo soporta).
- Si Live Activities no están disponibles o fallan, la app intenta programar una notificación local al finalizar el descanso (requiere permisos de notificaciones).

## Requisitos

- Xcode 16+ recomendado.
- iOS `18.4` (deployment target actual del proyecto).

## Cómo ejecutar

1. Abre `GymTimerPro.xcodeproj` en Xcode.
2. Selecciona el esquema `GymTimerPro`.
3. Ejecuta en un simulador o dispositivo.
4. (Opcional) Concede permisos de notificaciones y activa Live Activities en Ajustes.

## Estructura del proyecto

- `GymTimerPro/ContentView.swift`: UI principal y modelo del temporizador (`RestTimerModel`).
- `GymTimerPro/LiveActivityManager.swift`: gestión de Live Activity y fallback de notificación local.
- `Shared/GymTimerLiveActivityAttributes.swift`: tipos compartidos (`GymTimerAttributes`) entre app y widget.
- `GymTimerProWidget/GymTimerProWidget.swift`: UI de Live Activity (Lock Screen + Dynamic Island).

## Autor

Alejandro Esteve Maza — `https://alejandro-esteve.com`