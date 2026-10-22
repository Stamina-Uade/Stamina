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

## Tercera ronda (19-10, noche)

- **Diagrama del backend:** `docs/diagrama-backend-stamina.png` (y `.html`). Clientes, el camino de un pedido,
  los 12 dominios con rutas y tablas, Postgres/Redis/externos, y tres recorridos: alta+login+refresh,
  generación del plan y subida de una salida del reloj. Abajo, 9 puntos a revisar encontrados en el código.
- **Arreglado en el backend:** `PUT /activities/{id}/route` tenía el tope global de 64 KB y un recorrido de
  más de ~18 min recibía 413 (y la app mandaba la salida a cuarentena). Ahora esa ruta acepta hasta 1 MB.
  `tsc --noEmit` pasa. Hay que desplegarlo.
- **Color de la app elegible** (Ajustes → Apariencia): 10 colores + uno libre con el selector del sistema, con
  vista previa en vivo y aviso de contraste. El texto encima del color se elige solo (negro o blanco, WCAG).
  Sólo el teléfono: el reloj y Android no cambian.
- **Modo claro/noche/automático** con tres teléfonos en miniatura para elegir.
- **Guía en cada pestaña** ("qué hay acá", se cierra con la X y vuelve con el "?") y **tour de 5 páginas** la
  primera vez, que se puede volver a ver desde Perfil o Ajustes.
- **Inicio:** accesos rápidos, zonas y avituallamiento explicados al tocarlos, barras de la semana tocables,
  tirar para actualizar. **Plan:** fases explicadas, semanas con anillo de km y deslizables, días que se abren
  con el detalle y el "por qué hoy". **Historial:** números de semana/mes/todo, filtro por deporte, lista por
  mes, calendario con leyenda. **Perfil:** para qué se usa cada dato, metas con cuenta regresiva, días de
  entrenamiento, accesos claros. Vibración al tocar en todas.

## Cuarta ronda (19-10, noche) — MVP, mascota y ajustes

- **Mascota** (serval de Ivan) en `Assets.xcassets`: `MascotaSaludo`, `MascotaCorriendo`, `MascotaMedalla`, con
  fondo transparente. Componente `MascotaConBocadillo` (bocadillo + animación suave, sin animación con Reducir
  movimiento). Reemplaza los íconos del tour, de la bienvenida y del cierre del alta.
- **Ajustes en páginas:** raíz con filas cortas (Aspecto, Notificaciones, Unidades, Objetivos, Ver tour, Cerrar
  sesión) y cada una abre su pantalla. Sin textos explicativos (quedan como pistas de VoiceOver).
- **Reloj en tiempo real:** el color del teléfono viaja al reloj (application context + mensaje inmediato si está
  al alcance) y el reloj se repinta sin cortar la salida en curso. El modo claro/oscuro se manda pero el reloj
  sigue siempre oscuro (watchOS no tiene modo claro).
- **MVP sólo running:** una llave, `MVP.soloRunning` (iOS: `TrainerCore/MVP.swift`; backend:
  `MVP_SOLO_RUNNING` en `motor/tipos.ts`). Bici, natación, triatlón y caminata quedan ocultos en el alta, el
  selector de metas, el entreno, el historial, el perfil y el reloj. Nada se borró. **Strava no existe en el
  código**: no había nada que filtrar.
- **Objetivo que no se guardaba:** la app mandaba `PUT /me/goals` sin `goal_date_ms` (Swift omite los nil) y el
  contrato lo exigía → 400 en cada objetivo sin fecha. Arreglado en los dos lados (contrato 1.2.1: el campo es
  opcional; la app manda `null` explícito). Además un bloque terminado con el mismo objetivo ahora arranca uno
  nuevo, y el selector del Plan ya no borra los objetivos adicionales.
- **Sesiones de bici:** el motor usaba el deporte del perfil para todas las sesiones. Con la llave, siempre
  running (+ fuerza). Triatlón olímpico se planifica como 10K. 182/182 tests unitarios del backend pasan
  (14 nuevos). Los de integración necesitan Postgres/Redis.

## Cómo subir todo a producción y probarlo

**1. Backend (una sola línea, desde la Mac):**

```bash
cd ~/Desarrollo/Trainer && git checkout rediseno-ios-2026-10 && scripts/desplegar-backend.sh
```

Qué hace `scripts/desplegar-backend.sh`, en orden:
1. `npm ci`, `npm run build` y los tests unitarios del backend en la Mac. Si algo falla, **no despliega**.
2. Arma el paquete (`dist/`, migraciones, systemd, `shared/datos`) y lo sube por SSH al EC2
   (`honnelink` vía Cloudflare si está configurado; si no, `ubuntu@52.200.205.163:49152` con la llave
   `~/Desarrollo/Ubuntu-WorkApp.pem`).
3. En el servidor corre `backend/deploy/servidor/activar-release.sh`: instala dependencias de producción,
   aplica migraciones (en esta tanda hay **una nueva: `016_pasos_diarios.sql`**, sólo agrega una tabla), reinicia `trainer-api` y, si el health
   no responde, **vuelve solo a la versión anterior**.
4. Prueba desde afuera `https://stamina.com.ar/v1/health` y `https://honnelink.com/network/info`.

Cómo verificar que quedó lo nuevo:
- `curl https://stamina.com.ar/v1/health` → `ok`.
- Elegir un objetivo **sin fecha** desde Plan: antes daba "No se pudo guardar el objetivo"; ahora se guarda.
- El plan no trae sesiones de bici ni natación, aunque el perfil diga ciclismo o triatlón.
- Una salida de más de 20 minutos sube con su recorrido (antes el recorrido daba 413).

Si algo sale mal: el script ya vuelve atrás solo si el health falla. Para volver a mano a la versión
anterior, desplegar desde la rama de antes de hoy: `git checkout feat/ios-stamina-update && scripts/desplegar-backend.sh`.

🛑 Ojo: el EC2 es compartido con HonneLink. El script no toca nada de HonneLink, pero conviene desplegar
cuando no haya tráfico pico.

**2. App de iPhone y reloj:** abrir `ios/Trainer/Trainer.xcodeproj` en Xcode, elegir el esquema **Trainer**,
el iPhone físico como destino y ⌘R. Para el reloj, esquema **TrainerWatch** con el Apple Watch emparejado
(o instalar la app del reloj desde la app Watch del iPhone). La primera vez, en Signing & Capabilities del
target Trainer, agregar **HealthKit** si Xcode lo pide.

**3. Qué probar en el celular y el reloj:**
- Primera apertura: el tour con la mascota.
- Ajustes → Aspecto: cambiar el color y mirar el reloj: tiene que cambiar al instante.
- Barra: Inicio · Plan · ⚡ · Historial · Perfil. Sólo running en todos lados.
- Plan: elegir objetivo (por ejemplo 10K), salir y volver a entrar: tiene que seguir elegido.
- Una salida desde el reloj: termina, pasa al teléfono y aparece en Historial.

## Quinta ronda (19-10, noche) — feedback de la prueba

- **Barra de abajo** sólo en las cuatro pestañas; las pantallas secundarias (Ajustes y sus páginas, Gimnasio,
  Apto) tienen arriba la flecha y el título fijos, fuera del scroll. **Cerrar sesión** en rojo fuerte (`Paleta.peligro`).
- **Sin "?" ni guías:** se borraron `TarjetaDeGuia`/`BotonDeAyuda` y las hojas que explicaban peso/altura/edad.
- **Mascota quieta** (sólo aparece con un fundido una vez). El **tour muestra las pantallas reales** dentro de un
  teléfono, con un anillo en el elemento y la mascota señalándolo con un bocadillo. Animaciones tipo Duolingo:
  hacen falta Lottie (o secuencias PNG con alfa): saludar con la mano (1,5 s, loop), señalar (0,8 s + pausa),
  ciclo de carrera (0,67 s, loop), festejo con medalla (1,8 s), parpadeo/orejas (3 s, loop), pulgar arriba (1 s).
- **Fondos de las tarjetas:** la foto de bici ("BienvenidaRuta" es el Tour de Francia) ya no sale en running.
  `FondosDeTarjeta` rota 20 fotos por disciplina sin repetir en 20 días (Inicio y Plan con fotos distintas).
  Prompts para generar las 60 en `docs/PROMPTS-FONDOS.md`; se agregan como `FondoRunning01…20` en Assets.
- **Clima nativo:** WeatherKit en el teléfono (aviso de calor en la hora real del entreno). La app ya no llama a
  `/weather/forecast`, y el backend lo quitó en el contrato 1.5.0. Atribución de Apple Weather en
  Notificaciones. **Pasos manuales en el portal:** activar WeatherKit en el App ID (Capabilities y App Services) y
  en Xcode → Signing & Capabilities; tarda ~30 min.
- **Pasos desde Apple Salud:** al abrir la app se leen los últimos 30 días de HealthKit (iPhone + reloj, sin
  duplicar) y se suben a la base: tabla `pasos_diarios`, `PUT /v1/me/steps` y `GET /v1/me/steps` (contrato 1.3.0).
  Con Salud funcionando, el calendario muestra "Apple Salud" y no deja editar; si no hay permiso, queda la edición
  manual y también se guarda en la base. 195/195 tests unitarios del backend.
- **Textos:** todas las keys de los dos catálogos son identificadores en inglés (`common.day`,
  `home.greeting.morning`…) con es/en/fr; el código usa `Textos.*` (iPhone) y `TextosReloj.*` (reloj). Los textos
  sueltos del reloj (Agua/Geles/Sales, "TIEMPO EN PAUSA"…) ahora también se traducen.

## Sexta ronda (20-10)

- **Assets duplicados:** `Acento.colorset` era el mismo color que `AccentColor` → se borró y el generador
  (`scripts/generar-tema.mjs`, `acento-desde-xcode.mjs`) escribe ahora `AccentColor.colorset`; `TokensAcento.nombreEnAssets`
  = "AccentColor". `LogoApp.imageset` era una copia de `AppIcon` → se borró y `LogoApp` dibuja el ícono instalado de la
  app (`CFBundleIcons`), con la inicial como respaldo.
- **Fondos:** las 20 `FondoRunning` se achicaron de 1536×2752 a 1179 px de ancho (58 MB → 5,4 MB). Los originales
  quedaron en `_to_delete/fondos-originales/`.
- **Mascota animada:** iOS no reproduce WebM (y menos con transparencia), así que los 8 `.webm` se convirtieron a
  **WebP animado con alfa** (360 px, 12 fps) dentro de los mismos `.dataset`. `MascotaAnimada` los reproduce
  decodificando sólo el cuadro que se ve (< 3 MB por mascota). Si un asset no se puede leer, muestra la pose fija.
  Para agregar animaciones nuevas: `ffmpeg -c:v libvpx-vp9 -i X.webm -an -vf "fps=12,scale=360:360" -c:v libwebp_anim
  -q:v 60 -loop 0 -pix_fmt yuva420p X.webp` y meterla en un `.dataset`.
- **Tour estilo Clippy:** encima de la app real, con un velo translúcido, la mascota animada en una esquina y el
  bocadillo junto a la boca; cambia de pestaña en cada paso. Se borraron `TourView` y `TourVistaPrevia`.
- **Inicio:** sin el botón de perfil arriba a la derecha; la hoja de zonas/hidratación mide exactamente su contenido;
  las barras de zona van alineadas abajo (como señal de celular) con bordes redondeados.
- **Ajustes:** secciones con título (CUENTA, APARIENCIA, AVISOS, PREFERENCIAS, AYUDA) como en Configuración de iOS;
  cerrar sesión pide confirmación con alerta; **Datos personales** y **Entrenamiento** editables (un solo `PATCH /me`
  con lo que cambió); 11 colores + personalizado (se agregó Lavanda).
- **Perfil:** sin opciones de Ajustes; tocar los datos del cuerpo o los días abre la página de Ajustes que los edita.

## Séptima ronda (22-10) — "Entrar y registrarse" y lo general

Rama `cambios-entrada-ios` (sale de `rediseno-ios-2026-10`). Compilado con Xcode 26.6 (iPhone y reloj);
154/154 tests unitarios del iPhone, 168/168 de `TrainerCore`, 232/232 unitarios del backend.

- **Contrato 1.6.0** (`shared/api/openapi.yaml`): `details` en el sobre de error; `too_many_attempts`
  (5 contraseñas equivocadas bloquean el correo 15 min, y un tope por IP); `code_attempts_exceeded`
  (5 códigos equivocados) distinto de `code_expired`; `password_not_set` con el proveedor; vincular
  Google/Apple (`account_link_available` + `POST /auth/social/link`); desactivar (`POST /me/deactivate`)
  y borrar con 30 días de gracia (`POST /me/delete`), con `account_deactivated` /
  `account_pending_deletion` y `POST /auth/reactivate`; cambiar la contraseña ya NO cierra las otras
  sesiones (`POST /auth/logout/others`) y manda un correo de aviso; `weak_password` sólo por las tres
  reglas. Migración `019_desactivar_y_borrar_con_gracia.sql`. `npm run purgar` borra las vencidas.
- **Alertas**: `AlertaApilada` (TrainerCore) reemplaza al `.alert` en toda la app: botones apilados,
  cancelar abajo y en negrita, destructivos en rojo, azul del sistema (no el color de la app), en una
  ventana propia. Copia la alerta de iOS 26 (y la clásica antes de iOS 26). "Listo" → "Ok".
- **Entrar**: botones habilitados sólo con datos válidos; los errores son alertas con título y mensaje
  (`FlujoEntrada.alerta`); el único rojo es "Las contraseñas no coinciden", al tocar.
- **Alta en 11 pasos** (10 con Google/Apple y el correo validado): Crea tu cuenta → Valida tu correo →
  **Antes de empezar** (texto de la app, dos casillas, hoja legal; reemplaza aviso, términos y "Antes de
  arrancar") → Nacimiento (18+) → Sexo → Peso y altura → Deporte → Nivel → Objetivo (fecha obligatoria si
  es carrera) → Días y horarios (con la notificación para prepararte) → **Tu apto físico**. Se borraron
  `ProblemaView`, `PreviewPlanView`, `RegClaveView`, `RegNombreView`, `ClaveListaView`, `RegAvisoView`,
  `RegTerminosView`, `RegSaludView`, `RegMedicionView` y `RegListoView`.
- **Notificación para prepararte**: se guarda en el teléfono (`AvisoDePreparacion`: claves
  `ajuste_notif_recordatorio_antes` y `ajuste_notif_recordatorio_minutos`, 5–60 min, 30 de entrada), el
  mismo lugar que el resto de los avisos; el servidor no programa avisos.
- **Textos**: español de "tú" en los dos catálogos, los legales (versión 1.1.0) y los correos; francés
  tuteado y frases que estaban en inglés traducidas. Sin emojis (el ⚡ es el botón dibujado en el texto).
- **Bienvenida** con tres fotos fijas (01, 09, 20). Las otras 17 `FondoRunning` siguen en el catálogo:
  las usan las tarjetas de Inicio y Plan (`FondosDeTarjeta`).

### Pendiente para una persona

- **Desplegar el backend** con la migración 019 (`scripts/desplegar-backend.sh`) y programar `npm run
  purgar` a diario si el timer no lo corre (borra las cuentas con el plazo vencido).
- 3 tests de `backend/test/integracion.api.test.ts` esperan el comportamiento de antes de la 1.6.0 (3
  códigos, el reset que revoca, el borrado en el acto). El archivo tiene cambios sin commitear de otra
  persona y no se tocó; los comportamientos nuevos están cubiertos en `integracion.cuenta-1-6.test.ts`.
- Los tests de UI no se corrieron enteros en esta ronda (ver el resumen de la sesión).
- `docs/diagrama-backend-stamina.html` todavía dice que cambiar la contraseña revoca las otras sesiones.
