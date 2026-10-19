# Rediseño iOS — octubre 2026

Rama: `rediseno-ios-2026-10` (sale de `feat/ios-stamina-update`). **Nada de esto se compiló todavía**: en la
sesión no había compilador Swift. Se verificó con un parser de Swift (cero errores de sintaxis nuevos), tres
revisiones independientes símbolo por símbolo, `verificar-tokens` (0 errores) y los 74 tests de `scripts/`.
**Lo primero es abrir Xcode y compilar** (⌘B), y correr los tests (⌘U).

## Qué cambió

**Design system (TrainerCore/Tema)**
- Superficies neutras sobre negro puro en modo noche (antes tenían tinte verde del acento lima). Es una
  divergencia sólo de iOS, anotada en `Paleta.swift`; Android sigue con `tokens.json`.
- La app arranca en modo noche (`ModoApariencia.predeterminado`). Quien ya eligió en Ajustes conserva su elección.
- `tokens.json` ahora tiene el acento rosa `#FF23A7` (el de Xcode). Antes decía verde y `npm run generar:tema`
  habría vuelto la app verde. Android no cambia: su acento sale de `colors.xml`.
- Roles tipográficos nuevos en `tokens.json`: `display`, `metrica_heroe`, `unidad_heroe`, `metrica_media`, `titulo_seccion`.
- Piezas nuevas en `PiezasDelRediseno.swift`: `EncabezadoDePestana`, `PildoraDeEstado`, `MetricaHeroe`,
  `TarjetaMetrica`, `TarjetaHeroe`, `BotonCircular`, `BotonTonal`, `EncabezadoDeSeccion`.
- Botón primario en cápsula; barra de pestañas flotante con el botón central rosa con halo (ícono rayo).

**Pantallas**: Inicio, Plan, Entreno en vivo, Resumen, Historial, Reproductor, Perfil, Ajustes, Nutrición,
Gimnasio, Calendario, alta, login, recuperar clave y bienvenida, con el lenguaje del mockup. Se cambió la
presentación, no la lógica. Lo que el mockup muestra y la app no tiene (clima, apto físico, audio del coach,
pulso en vivo en el teléfono) **no se inventó**.

**Orden del código**
- `EntrenoView.swift` bajó de 1644 a ~740 líneas: el mapa se mudó a `MapaDeSalida.swift`,
  `MapaGestorDeInstancia.swift`, `MapaAnotaciones.swift`, `MapaControles.swift`, `EntrenoFilaDeBloque.swift`.
- Inicio, Plan, Resumen e Historial partidos en piezas (`InicioPiezas.swift`, `PlanSelectorDeMetasView.swift`,
  `ResumenPiezasCompartidas.swift`).
- Cinco copias de `nombreDeporte` que no coincidían → `DeporteDeSesion.nombreVisible`. Cuatro `iconoDeporte` muertas, borradas.
- Cientos de `.font(.system(size: N))` sueltos → roles `.estilo(...)`.

## Seguridad y datos (lo más importante)

1. **Datos falsos en producción**: con el almacén vacío se sembraban ~19 actividades inventadas y rutas GPS falsas,
   y el calendario tenía un botón "Añadir 1 km". Ahora sólo en `DEBUG`. Lo ya guardado no se borró.
2. **Historial de salud en `UserDefaults` en texto plano y compartido entre cuentas**: ahora va a
   `Application Support/hitos/usuario-<id>.json` con protección de archivo, separado por cuenta. Migración de
   una sola vez desde `UserDefaults` (la clave vieja se borra sólo después de escribir el archivo).
3. **Cerrar sesión borraba salidas sin subir** (las del teléfono y las del reloj): ahora quedan con su dueño y se
   suben cuando esa cuenta vuelve. Las rutas GPS en caché sí se borran al salir (están en el servidor).
4. **El reloj quedaba vinculado después de cerrar sesión** si no estaba al alcance.
5. **Una salida rechazada (4xx) trababa la cola de subida para siempre**: ahora va a cuarentena en disco y la cola sigue.
6. **Un archivo que no se podía leer se sobrescribía vacío** (salidas, series, bandeja del reloj): ahora se aparta como `.corrupto-<ms>`.
7. **Pausa desde 1970** al recuperar una salida después de un cierre inesperado.
8. Saltos de GPS descartados que igual sumaban distancia; escritura a disco en cada punto GPS (ahora cada 10 s / 20 puntos
   y siempre al pausar/terminar/ir a segundo plano); GPS y brújula prendidos sin entrenar.
9. Descanso del gimnasio que se congelaba con el teléfono bloqueado (ahora cuenta contra una hora de fin).
10. El target iOS no tenía entitlements de HealthKit; los textos de permiso de salud del reloj estaban cruzados.

## Pendiente para una persona

- **Compilar en Xcode.** Si algo no compila, el error va a estar en pantallas, no en lógica.
- Activar **HealthKit** en Signing & Capabilities del target iOS (el archivo `Trainer.entitlements` ya está).
- Las actividades "ejemplo-*" que versiones anteriores ya sembraron siguen en los teléfonos donde se instaló.
- Cerrar sesión todavía borra series de gimnasio sin subir (`series.borrar()`): hace falta guardarlas por cuenta.
- Las salidas en cuarentena se guardan pero no se reintentan solas.
- Los textos nuevos usan `String(localized:)`: falta pasarlos a `Localizable.xcstrings` y correr `npm run generar:textos`.
- Cambios de comportamiento a confirmar: en Entreno se puede terminar sin pausar (pide confirmación); el botón
  Historial de Plan pasó al encabezado.

## Segunda ronda (19-10, tarde) — pedido de Ivan

- **Barra de abajo:** Inicio · Plan · (rayo: Entreno) · Historial · Perfil. **Nutrición salió de la app**
  (`NutricionView` y `RegistrarComidaView` borradas). Los datos de nutrición del servidor se siguen leyendo en
  `EstadoHome`, pero ninguna pantalla los muestra; se pueden sacar del todo cuando se decida.
- **Historial es una pestaña** (`HistorialDeActividadesView(esPestana: true)`) y tiene el calendario de actividad,
  que salió de Inicio y de Perfil.
- **Inicio como el mockup:** Stamina · racha · avatar, fecha, "Buen día, <nombre>", píldora del apto, tarjeta con
  foto de la próxima carrera ("23 días para tu media maratón", píldora "Dom 8 nov · 21 km"), tarjeta HOY con hora
  sugerida, zona, clima del servidor (si lo manda) y "Preparar salida", píldoras de hidratación.
  **Siempre hay un objetivo a la vista:** sin plan o con el plan terminado aparece "Ingresá tu nuevo objetivo",
  que lleva al selector de metas de Plan.
- **Apto físico** (pantalla 1 del mockup): archivo (PDF o foto), vencimiento, declaración jurada, aviso 30 días
  antes. Se abre desde la píldora del inicio y desde Perfil. 🛑 Se guarda **sólo en el teléfono**, por cuenta y
  con protección de archivo: el servidor no tiene dónde guardarlo. Subirlo es una decisión de producto/legal.
- Plan cuenta **días** a la carrera cuando el servidor manda `event_date_ms`.
- **El reloj no se tocó en esta ronda.** De la primera quedaron dos arreglos invisibles de sincronización
  (la salida a medias no cambia de dueño al cerrar sesión, y el reloj se entera del cierre de sesión).
