// =============================================================================
// GENERADO por scripts/generar-textos-swift.mjs desde
// ios/Trainer/Trainer/Recursos/Localizable.xcstrings
//
// NO EDITAR A MANO. Para cambiar un texto se edita el CATÁLOGO —en Xcode, como
// cualquier traducción— y se corre `npm run generar:textos`.
//
// AGENTS.md §10: ningún texto visible al usuario va hardcodeado, y fechas,
// números y unidades se formatean con el locale del sistema. Esto resuelve lo
// primero; lo segundo es de quien presenta el dato.
//
// 526 claves · idioma de autoría: es
// =============================================================================

import Foundation

/// Los textos. Una propiedad por clave del catálogo: un typo en una
/// clave deja de ser un bug de producción y pasa a ser un error de compilación.
enum Textos {

    /// DISTANCIA
    static var DISTANCIA: String { String(localized: "DISTANCIA") }

    /// Descartar
    static var Descartar: String { String(localized: "Descartar") }

    /// E
    static var E: String { String(localized: "E") }

    /// N
    static var N: String { String(localized: "N") }

    /// O
    static var O: String { String(localized: "O") }

    /// RECORRIDO
    static var RECORRIDO: String { String(localized: "RECORRIDO") }

    /// RITMO
    static var RITMO: String { String(localized: "RITMO") }

    /// Reanudar
    static var Reanudar: String { String(localized: "Reanudar") }

    /// Reloj
    static var Reloj: String { String(localized: "Reloj") }

    /// Rutas
    static var Rutas: String { String(localized: "Rutas") }

    /// S
    static var S: String { String(localized: "S") }

    /// TIEMPO
    static var TIEMPO: String { String(localized: "TIEMPO") }

    /// VELOCIDAD
    static var VELOCIDAD: String { String(localized: "VELOCIDAD") }

    /// O
    static var W: String { String(localized: "W") }

    /// Gimnasio · tren superior y core
    static var agendaGimnasio: String { String(localized: "agenda.gimnasio") }

    /// %lld ejercicios · 45 min · toca para ver la rutina
    static func agendaGimnasioDetalle(_ arg1: Int) -> String {
        String(format: String(localized: "agenda.gimnasio.detalle"), arg1)
    }

    /// Preparar bidones y geles
    static var agendaPreparar: String { String(localized: "agenda.preparar") }

    /// %1$@ con sales · %2$lld geles · aviso %3$lld min antes
    static func agendaPrepararDetalle(_ arg1: String, _ arg2: Int, _ arg3: Int) -> String {
        String(format: String(localized: "agenda.preparar.detalle"), arg1, arg2, arg3)
    }

    /// Recuperación
    static var agendaRecuperacion: String { String(localized: "agenda.recuperacion") }

    /// %1$lld g proteína + %2$lld g carbos en 45 min
    static func agendaRecuperacionDetalle(_ arg1: Int, _ arg2: Int) -> String {
        String(format: String(localized: "agenda.recuperacion.detalle"), arg1, arg2)
    }

    /// Snack pre-entreno
    static var agendaSnack: String { String(localized: "agenda.snack") }

    /// %lld g carbos · banana + avena
    static func agendaSnackDetalle(_ arg1: Int) -> String {
        String(format: String(localized: "agenda.snack.detalle"), arg1)
    }

    /// Anticipación del aviso
    static var ajustesAnticipacion: String { String(localized: "ajustes.anticipacion") }

    /// Avisos
    static var ajustesAvisos: String { String(localized: "ajustes.avisos") }

    /// Avisos durante la salida
    static var ajustesCarrera: String { String(localized: "ajustes.carrera") }

    /// Geles, sales e hidratación mientras entrenás
    static var ajustesCarreraDetalle: String { String(localized: "ajustes.carrera.detalle") }

    /// Cerrar sesión
    static var ajustesCerrarSesion: String { String(localized: "ajustes.cerrar_sesion") }

    /// Cuenta
    static var ajustesCuenta: String { String(localized: "ajustes.cuenta") }

    /// Imperial
    static var ajustesImperial: String { String(localized: "ajustes.imperial") }

    /// Métrico
    static var ajustesMetrico: String { String(localized: "ajustes.metrico") }

    /// %lld min
    static func ajustesMinutos(_ arg1: Int) -> String {
        String(format: String(localized: "ajustes.minutos"), arg1)
    }

    /// Perfil privado
    static var ajustesPerfilPrivado: String { String(localized: "ajustes.perfil_privado") }

    /// Nadie ve tus datos ni tus rutas
    static var ajustesPerfilPrivadoDetalle: String { String(localized: "ajustes.perfil_privado.detalle") }

    /// Aviso de preparación
    static var ajustesPreparacion: String { String(localized: "ajustes.preparacion") }

    /// Antes de cada sesión, para armar bidones y geles
    static var ajustesPreparacionDetalle: String { String(localized: "ajustes.preparacion.detalle") }

    /// Privacidad
    static var ajustesPrivacidad: String { String(localized: "ajustes.privacidad") }

    /// Resumen semanal
    static var ajustesResumen: String { String(localized: "ajustes.resumen") }

    /// Tu carga y tu progreso, los domingos
    static var ajustesResumenDetalle: String { String(localized: "ajustes.resumen.detalle") }

    /// Ajustes
    static var ajustesTitulo: String { String(localized: "ajustes.titulo") }

    /// Unidades
    static var ajustesUnidades: String { String(localized: "ajustes.unidades") }

    /// Cambia sólo cómo se muestran: lo guardado no cambia.
    static var ajustesUnidadesDetalle: String { String(localized: "ajustes.unidades.detalle") }

    /// Stamina %@ · beta
    static func ajustesVersion(_ arg1: String) -> String {
        String(format: String(localized: "ajustes.version"), arg1)
    }

    /// Crear cuenta gratis
    static var bienvenidaCrearCuenta: String { String(localized: "bienvenida.crear_cuenta") }

    /// Ver la foto %lld de %lld
    static func bienvenidaIrAFoto(_ arg1: Int, _ arg2: Int) -> String {
        String(format: String(localized: "bienvenida.ir_a_foto"), arg1, arg2)
    }

    /// Stamina
    static var bienvenidaMarca: String { String(localized: "bienvenida.marca") }

    /// Corredores al amanecer
    static var bienvenidaSlide1Foto: String { String(localized: "bienvenida.slide1.foto") }

    /// Estimaciones de hidratación, sales y geles para cada salida. Sin planillas.
    static var bienvenidaSlide1Texto: String { String(localized: "bienvenida.slide1.texto") }

    /// Entrená y comé según la carga del día
    static var bienvenidaSlide1Titulo: String { String(localized: "bienvenida.slide1.titulo") }

    /// Pelotón en ruta
    static var bienvenidaSlide2Foto: String { String(localized: "bienvenida.slide2.foto") }

    /// Sugerencias según tu peso, la duración y la intensidad de cada salida.
    static var bienvenidaSlide2Texto: String { String(localized: "bienvenida.slide2.texto") }

    /// Hidratate y reponé con una guía clara
    static var bienvenidaSlide2Titulo: String { String(localized: "bienvenida.slide2.titulo") }

    /// Trail en montaña
    static var bienvenidaSlide3Foto: String { String(localized: "bienvenida.slide3.foto") }

    /// El plan se ajusta a los días y horarios que realmente tenés libres.
    static var bienvenidaSlide3Texto: String { String(localized: "bienvenida.slide3.texto") }

    /// Preparate para el día de la carrera
    static var bienvenidaSlide3Titulo: String { String(localized: "bienvenida.slide3.titulo") }

    /// Ya tengo cuenta
    static var bienvenidaYaTengoCuenta: String { String(localized: "bienvenida.ya_tengo_cuenta") }

    /// Buscar por nombre o músculo
    static var catalogoBuscar: String { String(localized: "catalogo.buscar") }

    /// Equipamiento
    static var catalogoEquipamiento: String { String(localized: "catalogo.equipamiento") }

    /// Filtros
    static var catalogoFiltros: String { String(localized: "catalogo.filtros") }

    /// Limpiar filtros
    static var catalogoLimpiar: String { String(localized: "catalogo.limpiar") }

    /// Músculo
    static var catalogoMusculo: String { String(localized: "catalogo.musculo") }

    /// Sin equipo
    static var catalogoSinEquipo: String { String(localized: "catalogo.sin_equipo") }

    /// Catálogo
    static var catalogoTitulo: String { String(localized: "catalogo.titulo") }

    /// Ampliar los filtros
    static var catalogoVacioAmpliar: String { String(localized: "catalogo.vacio.ampliar") }

    /// Usar un ejercicio libre
    static var catalogoVacioLibre: String { String(localized: "catalogo.vacio.libre") }

    /// Sugerirlo para el catálogo
    static var catalogoVacioSugerir: String { String(localized: "catalogo.vacio.sugerir") }

    /// Probá con menos filtros, registrá un ejercicio libre para esta sesión, o sugerilo para el catálogo.
    static var catalogoVacioTexto: String { String(localized: "catalogo.vacio.texto") }

    /// No encontré lo que buscás
    static var catalogoVacioTitulo: String { String(localized: "catalogo.vacio.titulo") }

    /// Ver %lld ejercicios
    static func catalogoVer(_ arg1: Int) -> String {
        String(format: String(localized: "catalogo.ver"), arg1)
    }

    /// Enviamos un código de 6 caracteres, con números y letras, a %@. Puede tardar hasta un minuto; si no aparece, r
    static func claveCodigoTexto(_ arg1: String) -> String {
        String(format: String(localized: "clave.codigo.texto"), arg1)
    }

    /// Revisá tu correo
    static var claveCodigoTitulo: String { String(localized: "clave.codigo.titulo") }

    /// Verificar código
    static var claveCodigoVerificar: String { String(localized: "clave.codigo.verificar") }

    /// Por seguridad, el mensaje se envía aunque el correo no esté registrado.
    static var claveCorreoAntiEnumeracion: String { String(localized: "clave.correo.anti_enumeracion") }

    /// Enviarme el código
    static var claveCorreoEnviar: String { String(localized: "clave.correo.enviar") }

    /// Escribí el correo con el que creaste tu cuenta y te enviamos un código para elegir una contraseña nueva. Tu pl
    static var claveCorreoTexto: String { String(localized: "clave.correo.texto") }

    /// Recuperar tu contraseña
    static var claveCorreoTitulo: String { String(localized: "clave.correo.titulo") }

    /// Error al recuperar contraseña
    static var claveErrorTitulo: String { String(localized: "clave.error.titulo") }

    /// Cambio hecho
    static var claveListaCambioHecho: String { String(localized: "clave.lista.cambio_hecho") }

    /// Cuenta
    static var claveListaCuenta: String { String(localized: "clave.lista.cuenta") }

    /// Ir a mi inicio
    static var claveListaEntrar: String { String(localized: "clave.lista.entrar") }

    /// Ya podés entrar con tu contraseña nueva. Cerramos la sesión en los otros dispositivos: si no fuiste vos quien 
    static var claveListaTexto: String { String(localized: "clave.lista.texto") }

    /// Contraseña actualizada
    static var claveListaTitulo: String { String(localized: "clave.lista.titulo") }

    /// Las dos contraseñas coinciden.
    static var claveNuevaCoinciden: String { String(localized: "clave.nueva.coinciden") }

    /// Fuerza de la contraseña: %lld de 3 reglas cumplidas
    static func claveNuevaFuerza(_ arg1: Int) -> String {
        String(format: String(localized: "clave.nueva.fuerza"), arg1)
    }

    /// Guardar contraseña
    static var claveNuevaGuardar: String { String(localized: "clave.nueva.guardar") }

    /// Nueva contraseña
    static var claveNuevaLabel: String { String(localized: "clave.nueva.label") }

    /// Las dos contraseñas no coinciden.
    static var claveNuevaNoCoinciden: String { String(localized: "clave.nueva.no_coinciden") }

    /// Al menos 10 caracteres
    static var claveNuevaReglaLargo: String { String(localized: "clave.nueva.regla_largo") }

    /// Una letra mayúscula
    static var claveNuevaReglaMayuscula: String { String(localized: "clave.nueva.regla_mayuscula") }

    /// Un número
    static var claveNuevaReglaNumero: String { String(localized: "clave.nueva.regla_numero") }

    /// Repetir contraseña
    static var claveNuevaRepetirLabel: String { String(localized: "clave.nueva.repetir_label") }

    /// Al menos 10 caracteres, con una mayúscula y un número. Cuando la guardes vamos a cerrar la sesión en los otros
    static var claveNuevaTexto: String { String(localized: "clave.nueva.texto") }

    /// Elegí una contraseña nueva
    static var claveNuevaTitulo: String { String(localized: "clave.nueva.titulo") }

    /// Avance del registro
    static var comunAvanceRegistro: String { String(localized: "comun.avance_registro") }

    /// Cambiar correo
    static var comunCambiarCorreo: String { String(localized: "comun.cambiar_correo") }

    /// Cancelar
    static var comunCancelar: String { String(localized: "comun.cancelar") }

    /// ••••••••
    static var comunClaveMarcador: String { String(localized: "comun.clave_marcador") }

    /// Completá lo que falta para poder seguir.
    static var comunCompletaParaSeguir: String { String(localized: "comun.completa_para_seguir") }

    /// Continuar
    static var comunContinuar: String { String(localized: "comun.continuar") }

    /// Correo electrónico
    static var comunCorreoLabel: String { String(localized: "comun.correo_label") }

    /// tu@mail.com
    static var comunCorreoMarcador: String { String(localized: "comun.correo_marcador") }

    /// Listo
    static var comunListo: String { String(localized: "comun.listo") }

    /// Reenviar código
    static var comunReenviarCodigo: String { String(localized: "comun.reenviar_codigo") }

    /// Reenviar en %@
    static func comunReenviarEn(_ arg1: String) -> String {
        String(format: String(localized: "comun.reenviar_en"), arg1)
    }

    /// Volver
    static var comunVolver: String { String(localized: "comun.volver") }

    /// Faltan %lld series
    static func descansoFaltan(_ arg1: Int) -> String {
        String(format: String(localized: "descanso.faltan"), arg1)
    }

    /// ¡A la siguiente!
    static var descansoFin: String { String(localized: "descanso.fin") }

    /// Terminó el descanso de %@
    static func descansoFinDetalle(_ arg1: String) -> String {
        String(format: String(localized: "descanso.fin.detalle"), arg1)
    }

    /// +30 s
    static var descansoMas: String { String(localized: "descanso.mas") }

    /// Saltar
    static var descansoSaltar: String { String(localized: "descanso.saltar") }

    /// Descanso
    static var descansoTitulo: String { String(localized: "descanso.titulo") }

    /// Distancia
    static var editDistancia: String { String(localized: "edit.distancia") }

    /// Guardar y recalcular
    static var editGuardar: String { String(localized: "edit.guardar") }

    /// Hora
    static var editHora: String { String(localized: "edit.hora") }

    /// Cambiar esto recalcula la hidratación, los geles y los avisos.
    static var editRecalcula: String { String(localized: "edit.recalcula") }

    /// Run-Walk-Run
    static var editRunWalkRun: String { String(localized: "edit.run_walk_run") }

    /// Alterna trote y caminata. Útil si volvés después de un parate.
    static var editRunWalkRunDetalle: String { String(localized: "edit.run_walk_run.detalle") }

    /// Tipo de sesión
    static var editTipo: String { String(localized: "edit.tipo") }

    /// Fondo largo
    static var editTipoFondo: String { String(localized: "edit.tipo.fondo") }

    /// Ritmo
    static var editTipoRitmo: String { String(localized: "edit.tipo.ritmo") }

    /// Series
    static var editTipoSeries: String { String(localized: "edit.tipo.series") }

    /// Suave
    static var editTipoSuave: String { String(localized: "edit.tipo.suave") }

    /// Editar el entreno de hoy
    static var editTitulo: String { String(localized: "edit.titulo") }

    /// Zona
    static var editZona: String { String(localized: "edit.zona") }

    /// Z1 · suave
    static var editZonaZ1: String { String(localized: "edit.zona.z1") }

    /// Z2 · fondo
    static var editZonaZ2: String { String(localized: "edit.zona.z2") }

    /// Z3 · ritmo
    static var editZonaZ3: String { String(localized: "edit.zona.z3") }

    /// Z4 · series
    static var editZonaZ4: String { String(localized: "edit.zona.z4") }

    /// Z5 · máxima
    static var editZonaZ5: String { String(localized: "edit.zona.z5") }

    /// Avituallamiento
    static var entrenoAvituallamiento: String { String(localized: "entreno.avituallamiento") }

    /// Geles, sales y bebidas son un complemento, no reemplazan comer e hidratarte bien. Si tomás medicación o tenés 
    static var entrenoDescargo: String { String(localized: "entreno.descargo") }

    /// Distancia
    static var entrenoDistancia: String { String(localized: "entreno.distancia") }

    /// Duración
    static var entrenoDuracion: String { String(localized: "entreno.duracion") }

    /// Empezar
    static var entrenoEmpezar: String { String(localized: "entreno.empezar") }

    /// en curso
    static var entrenoEnCurso: String { String(localized: "entreno.en_curso") }

    /// Estructura de la sesión
    static var entrenoEstructura: String { String(localized: "entreno.estructura") }

    /// El mapa llega con el GPS, que es de otra fase.
    static var entrenoMapaNoDisponible: String { String(localized: "entreno.mapa_no_disponible") }

    /// Objetivo
    static var entrenoObjetivo: String { String(localized: "entreno.objetivo") }

    /// Pausar
    static var entrenoPausar: String { String(localized: "entreno.pausar") }

    /// Próximo aviso
    static var entrenoProximoAviso: String { String(localized: "entreno.proximo_aviso") }

    /// Reanudar
    static var entrenoReanudar: String { String(localized: "entreno.reanudar") }

    /// Ritmo
    static var entrenoRitmo: String { String(localized: "entreno.ritmo") }

    /// Hoy no hay una salida en el plan.
    static var entrenoSinSesion: String { String(localized: "entreno.sin_sesion") }

    /// Terminar
    static var entrenoTerminar: String { String(localized: "entreno.terminar") }

    /// Ahora no
    static var entrenoPermisoCancelar: String { String(localized: "entrenoPermisoCancelar") }

    /// Continuar
    static var entrenoPermisoContinuar: String { String(localized: "entrenoPermisoContinuar") }

    /// Al iniciar la salida, Stamina usará tu ubicación para dibujar el mapa y medir distancia y ritmo, incluso con l
    static var entrenoPermisoDetalle: String { String(localized: "entrenoPermisoDetalle") }

    /// Registrar tu recorrido
    static var entrenoPermisoTitulo: String { String(localized: "entrenoPermisoTitulo") }

    /// Para registrar el recorrido, permití el acceso a la ubicación en Ajustes.
    static var entrenoUbicacionDenegada: String { String(localized: "entrenoUbicacionDenegada") }

    /// Ese pedido no tiene la forma que el servidor espera. Es un bug, no vos.
    static var errorBadRequest: String { String(localized: "error.bad_request") }

    /// El código venció. Pedí uno nuevo.
    static var errorCodeExpired: String { String(localized: "error.code_expired") }

    /// Recién te mandamos uno. Esperá un momento antes de pedir otro.
    static var errorCodeResendTooSoon: String { String(localized: "error.code_resend_too_soon") }

    /// No se pudo. El servidor contestó «%@».
    static func errorCodigoDesconocido(_ arg1: String) -> String {
        String(format: String(localized: "error.codigo_desconocido"), arg1)
    }

    /// Lo anterior todavía se está guardando. Probá de nuevo en un momento.
    static var errorConflict: String { String(localized: "error.conflict") }

    /// Se rompió algo del lado del servidor. No es culpa tuya.
    static var errorInternal: String { String(localized: "error.internal") }

    /// Ese código no es correcto o ya venció. Pedí uno nuevo.
    static var errorInvalidCode: String { String(localized: "error.invalid_code") }

    /// El correo o la contraseña no coinciden.
    static var errorInvalidCredentials: String { String(localized: "error.invalid_credentials") }

    /// Se venció la sesión. Entrá de nuevo.
    static var errorInvalidRefreshToken: String { String(localized: "error.invalid_refresh_token") }

    /// Se venció el registro. Empezá de nuevo desde el correo.
    static var errorInvalidRegistrationToken: String { String(localized: "error.invalid_registration_token") }

    /// Se venció el pedido de contraseña nueva. Empezá de nuevo desde el correo.
    static var errorInvalidResetToken: String { String(localized: "error.invalid_reset_token") }

    /// Hay que aceptar el aviso de salud para crear la cuenta.
    static var errorLegalNotAccepted: String { String(localized: "error.legal_not_accepted") }

    /// El aviso cambió mientras completabas el registro. Leelo de nuevo, por favor.
    static var errorLegalVersionStale: String { String(localized: "error.legal_version_stale") }

    /// Esa dirección no existe en el servidor.
    static var errorNotFound: String { String(localized: "error.not_found") }

    /// Falta un dato del perfil para poder armar el plan.
    static var errorProfileIncomplete: String { String(localized: "error.profile_incomplete") }

    /// Demasiados intentos. Esperá un momento antes de volver a probar.
    static var errorRateLimited: String { String(localized: "error.rate_limited") }

    /// El servidor contestó algo inesperado. Es un bug, no vos.
    static var errorRespuestaRara: String { String(localized: "error.respuesta_rara") }

    /// El servidor no está respondiendo. Probá de nuevo en un momento.
    static var errorServidor: String { String(localized: "error.servidor") }

    /// Se cerró la sesión desde otro lado. Entrá de nuevo.
    static var errorSessionRevoked: String { String(localized: "error.session_revoked") }

    /// No hay conexión. Lo que escribiste queda guardado; probá de nuevo cuando vuelva.
    static var errorSinConexion: String { String(localized: "error.sin_conexion") }

    /// Se venció la sesión. Entrá de nuevo.
    static var errorUnauthorized: String { String(localized: "error.unauthorized") }

    /// Hay un dato que el servidor no aceptó. Revisá lo que cargaste.
    static var errorValidationFailed: String { String(localized: "error.validation_failed") }

    /// Esa contraseña es fácil de adivinar. Probá una más larga o menos común.
    static var errorWeakPassword: String { String(localized: "error.weak_password") }

    /// Músculo principal
    static var fichaMusculoPrincipal: String { String(localized: "ficha.musculo_principal") }

    /// Secundarios
    static var fichaMusculoSecundario: String { String(localized: "ficha.musculo_secundario") }

    /// Patrón de movimiento
    static var fichaPatron: String { String(localized: "ficha.patron") }

    /// Ver sustitutos
    static var fichaSustitutos: String { String(localized: "ficha.sustitutos") }

    /// Usar este ejercicio
    static var fichaUsar: String { String(localized: "ficha.usar") }

    /// + Serie
    static var gimnasioAgregarSerie: String { String(localized: "gimnasio.agregar_serie") }

    /// ¿Seguro que quieres descartar estos datos?
    static var gimnasioDescartarConfirmacion: String { String(localized: "gimnasio.descartar.confirmacion") }

    /// Desmarcar serie
    static var gimnasioDesmarcarSerie: String { String(localized: "gimnasio.desmarcar_serie") }

    /// Descartar
    static var gimnasioResumenDescartar: String { String(localized: "gimnasio.resumen.descartar") }

    /// Guardar
    static var gimnasioResumenGuardar: String { String(localized: "gimnasio.resumen.guardar") }

    /// Regresar
    static var gimnasioResumenRegresar: String { String(localized: "gimnasio.resumen.regresar") }

    /// Entrenamiento finalizado
    static var gimnasioResumenTitulo: String { String(localized: "gimnasio.resumen.titulo") }

    /// Técnica y movimiento
    static var gimnasioTecnica: String { String(localized: "gimnasio.tecnica") }

    /// Agregar ejercicio
    static var gymAgregar: String { String(localized: "gym.agregar") }

    /// %lld s de descanso
    static func gymDescanso(_ arg1: Int) -> String {
        String(format: String(localized: "gym.descanso"), arg1)
    }

    /// Hoy corrés a la tarde: la sesión es de fuerza liviana, sin llegar al fallo, para no comprometer el fondo.
    static var gymNota: String { String(localized: "gym.nota") }

    /// Por qué
    static var gymPorQue: String { String(localized: "gym.por_que") }

    /// La vez anterior: %@
    static func gymPrevia(_ arg1: String) -> String {
        String(format: String(localized: "gym.previa"), arg1)
    }

    /// %1$lld/%2$lld series
    static func gymProgreso(_ arg1: Int, _ arg2: Int) -> String {
        String(format: String(localized: "gym.progreso"), arg1, arg2)
    }

    /// Serie %lld
    static func gymSerieNumero(_ arg1: Int) -> String {
        String(format: String(localized: "gym.serie_numero"), arg1)
    }

    /// series completadas · 45 min estimados
    static var gymSeriesCompletadas: String { String(localized: "gym.series_completadas") }

    /// Jue 28 ago · tren superior y core
    static var gymSubtitulo: String { String(localized: "gym.subtitulo") }

    /// Terminar sesión de gimnasio
    static var gymTerminar: String { String(localized: "gym.terminar") }

    /// Rutina de hoy
    static var gymTitulo: String { String(localized: "gym.titulo") }

    /// Cargando…
    static var historialCargando: String { String(localized: "historial.cargando") }

    /// Cerrar
    static var historialCerrar: String { String(localized: "historial.cerrar") }

    /// No se pudo cargar el historial. Probá de nuevo.
    static var historialError: String { String(localized: "historial.error") }

    /// Cargar más
    static var historialMas: String { String(localized: "historial.mas") }

    /// Esta actividad no tiene recorrido GPS guardado.
    static var historialSinRecorrido: String { String(localized: "historial.sinRecorrido") }

    /// Mis actividades
    static var historialTitulo: String { String(localized: "historial.titulo") }

    /// Todavía no hay actividades guardadas.
    static var historialVacio: String { String(localized: "historial.vacio") }

    /// Buscando lo último…
    static var homeDatosCargando: String { String(localized: "home.datos.cargando") }

    /// No pudimos traer esto del servidor. Probá de nuevo en un rato.
    static var homeDatosError: String { String(localized: "home.datos.error") }

    /// No se pudo actualizar: esto es lo que se guardó %@.
    static func homeDatosGuardadoConError(_ arg1: String) -> String {
        String(format: String(localized: "home.datos.guardado_con_error"), arg1)
    }

    /// Sin conexión: esto es lo que se guardó %@.
    static func homeDatosGuardadoSinRed(_ arg1: String) -> String {
        String(format: String(localized: "home.datos.guardado_sin_red"), arg1)
    }

    /// Esto se calcula con tu perfil, y le faltan datos: completalo desde el inicio.
    static var homeDatosPerfilIncompleto: String { String(localized: "home.datos.perfil_incompleto") }

    /// Reintentar
    static var homeDatosReintentar: String { String(localized: "home.datos.reintentar") }

    /// Sin conexión, y en este teléfono todavía no hay nada guardado para mostrar. Se carga solo cuando vuelva la señ
    static var homeDatosSinRed: String { String(localized: "home.datos.sin_red") }

    /// Todavía no hay nada para mostrar acá.
    static var homeDatosVacio: String { String(localized: "home.datos.vacio") }

    /// Completar perfil
    static var homePerfilIncompletoBoton: String { String(localized: "home.perfil_incompleto.boton") }

    /// A tu perfil le faltan datos que usa el plan.
    static var homePerfilIncompletoTexto: String { String(localized: "home.perfil_incompleto.texto") }

    /// Ajustes
    static var homeTabAjustes: String { String(localized: "home.tab.ajustes") }

    /// Entreno
    static var homeTabEntreno: String { String(localized: "home.tab.entreno") }

    /// Gimnasio
    static var homeTabGimnasio: String { String(localized: "home.tab.gimnasio") }

    /// Inicio
    static var homeTabInicio: String { String(localized: "home.tab.inicio") }

    /// Nutrición
    static var homeTabNutricion: String { String(localized: "home.tab.nutricion") }

    /// Perfil
    static var homeTabPerfil: String { String(localized: "home.tab.perfil") }

    /// Plan
    static var homeTabPlan: String { String(localized: "home.tab.plan") }

    /// iPhone
    static var iPhone: String { String(localized: "iPhone") }

    /// Ahora mismo
    static var inicioAhoraMismo: String { String(localized: "inicio.ahora_mismo") }

    /// Carga semanal
    static var inicioCargaSemanal: String { String(localized: "inicio.carga_semanal") }

    /// para tu %1$@ de %2$@ · %3$@
    static func inicioCuentaRegresiva(_ arg1: String, _ arg2: String, _ arg3: String) -> String {
        String(format: String(localized: "inicio.cuenta_regresiva"), arg1, arg2, arg3)
    }

    /// de %@ previstos
    static func inicioDePrevistos(_ arg1: String) -> String {
        String(format: String(localized: "inicio.de_previstos"), arg1)
    }

    /// Editar
    static var inicioEditar: String { String(localized: "inicio.editar") }

    /// %1$@ · semana %2$lld/%3$lld
    static func inicioFecha(_ arg1: String, _ arg2: Int, _ arg3: Int) -> String {
        String(format: String(localized: "inicio.fecha"), arg1, arg2, arg3)
    }

    /// %1$lld ml/h y %2$lld g de carbos/h · %3$@ es intensidad %4$@
    static func inicioNotaHidratacion(_ arg1: Int, _ arg2: Int, _ arg3: String, _ arg4: String) -> String {
        String(format: String(localized: "inicio.nota_hidratacion"), arg1, arg2, arg3, arg4)
    }

    /// Preparar salida
    static var inicioPrepararSalida: String { String(localized: "inicio.preparar_salida") }

    /// Hoy no hay nada planificado
    static var inicioSinPlanHoy: String { String(localized: "inicio.sin_plan_hoy") }

    /// Tu día
    static var inicioTuDia: String { String(localized: "inicio.tu_dia") }

    /// Ver plan
    static var inicioVerPlan: String { String(localized: "inicio.ver_plan") }

    /// Ver la rutina
    static var inicioVerRutina: String { String(localized: "inicio.ver_rutina") }

    /// Este registro ya se usó: lo más probable es que tu cuenta ya exista. Probá entrar con tu correo y tu contraseñ
    static var legalAltaYaCreada: String { String(localized: "legal.alta_ya_creada") }

    /// Estamos trayendo el aviso de salud del servidor.
    static var legalCargando: String { String(localized: "legal.cargando") }

    /// Crear mi cuenta
    static var legalCrearCuenta: String { String(localized: "legal.crear_cuenta") }

    /// Ya hay una cuenta con este correo.
    static var legalCuentaExistente: String { String(localized: "legal.cuenta_existente") }

    /// Empezar de nuevo desde el correo
    static var legalEmpezarDeNuevo: String { String(localized: "legal.empezar_de_nuevo") }

    /// Entrar con ese correo
    static var legalEntrarConEseCorreo: String { String(localized: "legal.entrar_con_ese_correo") }

    /// Marcá que leíste el aviso para poder crear la cuenta.
    static var legalFaltaAceptar: String { String(localized: "legal.falta_aceptar") }

    /// Ya tengo cuenta, iniciar sesión
    static var legalIrAlLogin: String { String(localized: "legal.ir_al_login") }

    /// Probar de nuevo
    static var legalReintentar: String { String(localized: "legal.reintentar") }

    /// Este texto todavía no lo revisó nadie con formación legal. Es un borrador y se va a reemplazar.
    static var legalSinRevisar: String { String(localized: "legal.sin_revisar") }

    /// No pudimos traer el aviso de salud. Sin leerlo no se puede crear la cuenta. Probá de nuevo cuando tengas señal
    static var legalSinTexto: String { String(localized: "legal.sin_texto") }

    /// Aviso de salud
    static var legalTitulo: String { String(localized: "legal.titulo") }

    /// Leer los términos y condiciones
    static var legalVerTerminos: String { String(localized: "legal.ver_terminos") }

    /// Cargar a mano
    static var logAMano: String { String(localized: "log.a_mano") }

    /// Analizando la foto
    static var logAnalizando: String { String(localized: "log.analizando") }

    /// La cámara no existe en el simulador. Se usa una foto de ejemplo.
    static var logCamaraSimulador: String { String(localized: "log.camara_simulador") }

    /// %lld %% de certeza
    static func logCerteza(_ arg1: Int) -> String {
        String(format: String(localized: "log.certeza"), arg1)
    }

    /// Sacar una foto
    static var logConFoto: String { String(localized: "log.con_foto") }

    /// Frecuentes
    static var logFrecuentes: String { String(localized: "log.frecuentes") }

    /// Guardar comida
    static var logGuardar: String { String(localized: "log.guardar") }

    /// Ingredientes
    static var logIngredientes: String { String(localized: "log.ingredientes") }

    /// Ingresá los valores de tu comida o su etiqueta. Stamina guarda exactamente lo que cargás.
    static var logManualDetalle: String { String(localized: "log.manual.detalle") }

    /// Completá el nombre y todos los valores con números válidos.
    static var logManualIncompleta: String { String(localized: "log.manual.incompleta") }

    /// No es esto
    static var logNoEsEsto: String { String(localized: "log.no_es_esto") }

    /// Nombre de la comida
    static var logNombre: String { String(localized: "log.nombre") }

    /// Calculando calorías y macros
    static var logPasoCalcular: String { String(localized: "log.paso.calcular") }

    /// Estimando porciones
    static var logPasoPorciones: String { String(localized: "log.paso.porciones") }

    /// Reconociendo el plato
    static var logPasoReconocer: String { String(localized: "log.paso.reconocer") }

    /// Porción
    static var logPorcion: String { String(localized: "log.porcion") }

    /// Reconocido
    static var logReconocido: String { String(localized: "log.reconocido") }

    /// En el simulador no hay cámara: se usa una foto de ejemplo.
    static var logSinCamara: String { String(localized: "log.sin_camara") }

    /// Registrar comida
    static var logTitulo: String { String(localized: "log.titulo") }

    /// Sacar foto
    static var logTomarFoto: String { String(localized: "log.tomar_foto") }

    /// Continuar con Apple
    static var loginApple: String { String(localized: "login.apple") }

    /// Contraseña
    static var loginClaveLabel: String { String(localized: "login.clave_label") }

    /// Error al iniciar sesión
    static var loginErrorTitulo: String { String(localized: "login.error.titulo") }

    /// Continuar con Google
    static var loginGoogle: String { String(localized: "login.google") }

    /// Ingresar
    static var loginIngresar: String { String(localized: "login.ingresar") }

    /// ¿No tenés cuenta?
    static var loginNoTenesCuenta: String { String(localized: "login.no_tenes_cuenta") }

    /// o
    static var loginO: String { String(localized: "login.o") }

    /// ¿Olvidaste tu contraseña?
    static var loginOlvidaste: String { String(localized: "login.olvidaste") }

    /// Registrate
    static var loginRegistrate: String { String(localized: "login.registrate") }

    /// Google y Apple todavía no: el servidor no tiene ese camino.
    static var loginSocialFalta: String { String(localized: "login.social_falta") }

    /// Iniciar sesión
    static var loginTitulo: String { String(localized: "login.titulo") }

    /// ciclismo
    static var notificacionEntrenamientoCiclismo: String { String(localized: "notificacion.entrenamiento.ciclismo") }

    /// Hiciste %1$@ durante %2$@ y recorriste %3$@. ¡Gran trabajo!
    static func notificacionEntrenamientoCuerpo(_ arg1: String, _ arg2: String, _ arg3: String) -> String {
        String(format: String(localized: "notificacion.entrenamiento.cuerpo"), arg1, arg2, arg3)
    }

    /// %@ km
    static func notificacionEntrenamientoDistancia(_ arg1: String) -> String {
        String(format: String(localized: "notificacion.entrenamiento.distancia"), arg1)
    }

    /// fuerza
    static var notificacionEntrenamientoFuerza: String { String(localized: "notificacion.entrenamiento.fuerza") }

    /// natación
    static var notificacionEntrenamientoNatacion: String { String(localized: "notificacion.entrenamiento.natacion") }

    /// un entrenamiento
    static var notificacionEntrenamientoOtro: String { String(localized: "notificacion.entrenamiento.otro") }

    /// running
    static var notificacionEntrenamientoRunning: String { String(localized: "notificacion.entrenamiento.running") }

    /// ¡Entrenamiento completado!
    static var notificacionEntrenamientoTitulo: String { String(localized: "notificacion.entrenamiento.titulo") }

    /// trekking
    static var notificacionEntrenamientoTrekking: String { String(localized: "notificacion.entrenamiento.trekking") }

    /// Tu entrenamiento de %1$@ es en este momento. ¡A darlo todo!
    static func notificacionRecordatorioHoraCuerpo(_ arg1: String) -> String {
        String(format: String(localized: "notificacion.recordatorio.hora.cuerpo"), arg1)
    }

    /// ¡Hora de entrenar!
    static var notificacionRecordatorioHoraTitulo: String { String(localized: "notificacion.recordatorio.hora.titulo") }

    /// Buen día, hoy es día de entreno. Hoy a las %1$@ toca hacer %2$@.
    static func notificacionRecordatorioMananaCuerpo(_ arg1: String, _ arg2: String) -> String {
        String(format: String(localized: "notificacion.recordatorio.manana.cuerpo"), arg1, arg2)
    }

    /// Entrenamiento de hoy
    static var notificacionRecordatorioMananaTitulo: String { String(localized: "notificacion.recordatorio.manana.titulo") }

    /// Anoche dormiste
    static var nutricionAnocheDormiste: String { String(localized: "nutricion.anoche_dormiste") }

    /// Carbos
    static var nutricionCarbos: String { String(localized: "nutricion.carbos") }

    /// Cena de recuperación
    static var nutricionCena: String { String(localized: "nutricion.cena") }

    /// 640 kcal · 25 g proteína · sugerida
    static var nutricionCenaDetalle: String { String(localized: "nutricion.cena.detalle") }

    /// Comidas
    static var nutricionComidas: String { String(localized: "nutricion.comidas") }

    /// Comidas de hoy
    static var nutricionComidasDeHoy: String { String(localized: "nutricion.comidas_de_hoy") }

    /// de %@ kcal
    static func nutricionDeObjetivo(_ arg1: String) -> String {
        String(format: String(localized: "nutricion.de_objetivo"), arg1)
    }

    /// Días de descanso
    static var nutricionDescanso: String { String(localized: "nutricion.descanso") }

    /// Dos días sin correr por semana es lo previsto.
    static var nutricionDescansoNota: String { String(localized: "nutricion.descanso.nota") }

    /// Descanso y sueño
    static var nutricionDescansoYSueno: String { String(localized: "nutricion.descanso_y_sueno") }

    /// Durante el entreno
    static var nutricionDuranteEntreno: String { String(localized: "nutricion.durante_entreno") }

    /// %1$lld geles · %2$lld g carbos/h
    static func nutricionDuranteEntrenoDetalle(_ arg1: Int, _ arg2: Int) -> String {
        String(format: String(localized: "nutricion.durante_entreno.detalle"), arg1, arg2)
    }

    /// esta semana
    static var nutricionEstaSemana: String { String(localized: "nutricion.esta_semana") }

    /// Grasa
    static var nutricionGrasa: String { String(localized: "nutricion.grasa") }

    /// Hidratación
    static var nutricionHidratacion: String { String(localized: "nutricion.hidratacion") }

    /// %1$@ / %2$@
    static func nutricionHidratacionDe(_ arg1: String, _ arg2: String) -> String {
        String(format: String(localized: "nutricion.hidratacion.de"), arg1, arg2)
    }

    /// Sumá %@ durante el entreno de esta tarde.
    static func nutricionHidratacionNota(_ arg1: String) -> String {
        String(format: String(localized: "nutricion.hidratacion.nota"), arg1)
    }

    /// %@ para hoy
    static func nutricionHidratacionObjetivo(_ arg1: String) -> String {
        String(format: String(localized: "nutricion.hidratacion.objetivo"), arg1)
    }

    /// Día de carga: te faltan carbohidratos para el fondo de esta tarde.
    static var nutricionHint: String { String(localized: "nutricion.hint") }

    /// %@ h
    static func nutricionHoras(_ arg1: String) -> String {
        String(format: String(localized: "nutricion.horas"), arg1)
    }

    /// %@ kcal restantes
    static func nutricionKcalRestantes(_ arg1: String) -> String {
        String(format: String(localized: "nutricion.kcal_restantes"), arg1)
    }

    /// %1$lld kcal · %2$lld g carbos · %3$lld g prote
    static func nutricionMacrosFila(_ arg1: Int, _ arg2: Int, _ arg3: Int) -> String {
        String(format: String(localized: "nutricion.macros_fila"), arg1, arg2, arg3)
    }

    /// Registrar
    static var nutricionPendiente: String { String(localized: "nutricion.pendiente") }

    /// Proteína
    static var nutricionProteina: String { String(localized: "nutricion.proteina") }

    /// Números provisionales: todavía no los revisó un profesional.
    static var nutricionProvisional: String { String(localized: "nutricion.provisional") }

    /// Quitar
    static var nutricionQuitar: String { String(localized: "nutricion.quitar") }

    /// Registrar comida
    static var nutricionRegistrar: String { String(localized: "nutricion.registrar") }

    /// %1$lld de %2$lld registradas
    static func nutricionResumenComidas(_ arg1: Int, _ arg2: Int) -> String {
        String(format: String(localized: "nutricion.resumen_comidas"), arg1, arg2)
    }

    /// Durante el embarazo o la lactancia no calculamos objetivos: lo mejor es seguirlo con tu equipo de salud.
    static var nutricionSinObjetivosEmbarazoOLactancia: String { String(localized: "nutricion.sin_objetivos.embarazo_o_lactancia") }

    /// Todavía no sabemos si estás embarazada o en lactancia, y eso cambia los números. Hasta saberlo, no los calcula
    static var nutricionSinObjetivosFaltaEmbarazoOLactancia: String { String(localized: "nutricion.sin_objetivos.falta_embarazo_o_lactancia") }

    /// Antes de los 18 no calculamos objetivos de calorías: en esa etapa conviene que te acompañe un profesional.
    static var nutricionSinObjetivosMenorDeEdad: String { String(localized: "nutricion.sin_objetivos.menor_de_edad") }

    /// Faltan datos de tu perfil para calcularlos. Lo que comas se sigue anotando igual.
    static var nutricionSinObjetivosPerfilIncompleto: String { String(localized: "nutricion.sin_objetivos.perfil_incompleto") }

    /// Para calcularlos hace falta el sexo biológico: la fórmula lo usa, y no la promediamos.
    static var nutricionSinObjetivosSexoSinDeclarar: String { String(localized: "nutricion.sin_objetivos.sexo_sin_declarar") }

    /// Hoy no hay objetivos de calorías
    static var nutricionSinObjetivosTitulo: String { String(localized: "nutricion.sin_objetivos.titulo") }

    /// Jueves 28 de agosto · día de carga
    static var nutricionSubtitulo: String { String(localized: "nutricion.subtitulo") }

    /// Sueño
    static var nutricionSueno: String { String(localized: "nutricion.sueno") }

    /// Suficiente para una semana de carga.
    static var nutricionSuenoNotaOk: String { String(localized: "nutricion.sueno.nota_ok") }

    /// Con menos de 7 h, la recuperación se resiente.
    static var nutricionSuenoNotaPoco: String { String(localized: "nutricion.sueno.nota_poco") }

    /// sugerida
    static var nutricionSugerida: String { String(localized: "nutricion.sugerida") }

    /// Nutrición de hoy
    static var nutricionTitulo: String { String(localized: "nutricion.titulo") }

    /// Altura
    static var perfilAltura: String { String(localized: "perfil.altura") }

    /// %lld años
    static func perfilAnios(_ arg1: Int) -> String {
        String(format: String(localized: "perfil.anios"), arg1)
    }

    /// Deporte y nivel
    static var perfilDeporte: String { String(localized: "perfil.deporte") }

    /// Días y horarios
    static var perfilDias: String { String(localized: "perfil.dias") }

    /// Edad
    static var perfilEdad: String { String(localized: "perfil.edad") }

    /// Cambiar foto
    static var perfilEditarFoto: String { String(localized: "perfil.editar_foto") }

    /// Objetivo
    static var perfilObjetivo: String { String(localized: "perfil.objetivo") }

    /// Peso
    static var perfilPeso: String { String(localized: "perfil.peso") }

    /// Sin foto
    static var perfilSinFoto: String { String(localized: "perfil.sin_foto") }

    /// Tu perfil y tus datos
    static var perfilSubtitulo: String { String(localized: "perfil.subtitulo") }

    /// Ajustes
    static var perfilVerAjustes: String { String(localized: "perfil.ver_ajustes") }

    /// Faltan %lld semanas
    static func planFaltanSemanas(_ arg1: Int) -> String {
        String(format: String(localized: "plan.faltan_semanas"), arg1)
    }

    /// Afinamiento
    static var planFaseAfinamiento: String { String(localized: "plan.fase.afinamiento") }

    /// Base
    static var planFaseBase: String { String(localized: "plan.fase.base") }

    /// Carrera
    static var planFaseCarrera: String { String(localized: "plan.fase.carrera") }

    /// Construcción
    static var planFaseConstruccion: String { String(localized: "plan.fase.construccion") }

    /// Pico
    static var planFasePico: String { String(localized: "plan.fase.pico") }

    /// Hecho
    static var planHecho: String { String(localized: "plan.hecho") }

    /// HOY
    static var planHoy: String { String(localized: "plan.hoy") }

    /// %1$@ de %2$@
    static func planKmDe(_ arg1: String, _ arg2: String) -> String {
        String(format: String(localized: "plan.km_de"), arg1, arg2)
    }

    /// Semana %lld
    static func planSemana(_ arg1: Int) -> String {
        String(format: String(localized: "plan.semana"), arg1)
    }

    /// S%lld
    static func planSemanaChip(_ arg1: Int) -> String {
        String(format: String(localized: "plan.semana.chip"), arg1)
    }

    /// Semana %lld · en curso
    static func planSemanaEnCurso(_ arg1: Int) -> String {
        String(format: String(localized: "plan.semana.en_curso"), arg1)
    }

    /// Sin fecha de carrera
    static var planSinFecha: String { String(localized: "plan.sin_fecha") }

    /// %1$@ · semana %2$lld de %3$lld
    static func planSubtitulo(_ arg1: String, _ arg2: Int, _ arg3: Int) -> String {
        String(format: String(localized: "plan.subtitulo"), arg1, arg2, arg3)
    }

    /// Y antes de salir
    static var previewAntesEtiqueta: String { String(localized: "preview.antes_etiqueta") }

    /// Aviso 45 min antes para preparar bidones, geles y el snack pre-entreno.
    static var previewAntesTexto: String { String(localized: "preview.antes_texto") }

    /// 1 gel c/45′
    static var previewChipGel: String { String(localized: "preview.chip_gel") }

    /// 750 ml/h
    static var previewChipLiquido: String { String(localized: "preview.chip_liquido") }

    /// 600 mg sodio
    static var previewChipSodio: String { String(localized: "preview.chip_sodio") }

    /// Armemos tu plan en 2 minutos
    static var previewCtaTitulo: String { String(localized: "preview.cta_titulo") }

    /// Empezar
    static var previewEmpezar: String { String(localized: "preview.empezar") }

    /// Tu plan en carrera
    static var previewEtiqueta: String { String(localized: "preview.etiqueta") }

    /// Iniciar sesión
    static var previewIniciarSesion: String { String(localized: "preview.iniciar_sesion") }

    /// Fondo largo · 14 km · 26°
    static var previewSesion: String { String(localized: "preview.sesion") }

    /// ¿Ya tenés cuenta?
    static var previewYaTenesCuenta: String { String(localized: "preview.ya_tenes_cuenta") }

    /// de quienes dejaron de entrenar lo hizo por falta de tiempo
    static var problemaDato1: String { String(localized: "problema.dato1") }

    /// de los corredores sufre calambres: pérdidas de 3 a 5 % del peso ya generan debilidad y desorientación
    static var problemaDato2: String { String(localized: "problema.dato2") }

    /// de quienes practican deporte compite en carreras organizadas
    static var problemaDato3: String { String(localized: "problema.dato3") }

    /// Seguir
    static var problemaSeguir: String { String(localized: "problema.seguir") }

    /// El problema no es el entusiasmo
    static var problemaTitulo: String { String(localized: "problema.titulo") }

    /// ¡Fueguito encendido! Completaste tu entrenamiento de hoy.
    static var rachaDetalleActiva: String { String(localized: "racha.detalle_activa") }

    /// Hoy es día de descanso en tu plan. Tu racha se mantiene intacta.
    static var rachaDetalleDescanso: String { String(localized: "racha.detalle_descanso") }

    /// Hoy te toca entrenar. ¡Completá tu sesión para mantener vivo el fueguito!
    static var rachaDetallePendiente: String { String(localized: "racha.detalle_pendiente") }

    /// No tenés una racha activa. ¡Entrená en tu próximo día para encender el fueguito!
    static var rachaDetallePerdida: String { String(localized: "racha.detalle_perdida") }

    /// días
    static var rachaDias: String { String(localized: "racha.dias") }

    /// Tu racha solo cuenta los días que tu plan dice que tenés que entrenar. Si no entrenás un día programado, el fu
    static var rachaExplicacion: String { String(localized: "racha.explicacion") }

    /// Racha de entrenamientos
    static var rachaTitulo: String { String(localized: "racha.titulo") }

    /// Apellido (opcional)
    static var regApellidoLabel: String { String(localized: "reg.apellido.label") }

    /// Benítez
    static var regApellidoMarcador: String { String(localized: "reg.apellido.marcador") }

    /// Esta pantalla NO está en el diseño: los 13 pasos nunca piden contraseña y el contrato la exige. Es un hueco de
    static var regClaveHueco: String { String(localized: "reg.clave.hueco") }

    /// Al menos %lld caracteres, con una mayúscula y un número. Es la única contraseña que te vamos a pedir: con ella
    static func regClaveTexto(_ arg1: Int) -> String {
        String(format: String(localized: "reg.clave.texto"), arg1)
    }

    /// Elegí una contraseña
    static var regClaveTitulo: String { String(localized: "reg.clave.titulo") }

    /// Enviamos un código de 6 caracteres, con números y letras, a %@. Puede tardar hasta un minuto en llegar; si no 
    static func regCodigoTexto(_ arg1: String) -> String {
        String(format: String(localized: "reg.codigo.texto"), arg1)
    }

    /// Validá tu correo
    static var regCodigoTitulo: String { String(localized: "reg.codigo.titulo") }

    /// Validar
    static var regCodigoValidar: String { String(localized: "reg.codigo.validar") }

    /// Completar después
    static var regCompletarDespues: String { String(localized: "reg.completar_despues") }

    /// Enviarme el código
    static var regCorreoEnviar: String { String(localized: "reg.correo.enviar") }

    /// Ese correo no parece válido: revisá que tenga @ y dominio.
    static var regCorreoInvalido: String { String(localized: "reg.correo.invalido") }

    /// Al continuar aceptás los términos y la política de privacidad. No mandamos publicidad.
    static var regCorreoLegal: String { String(localized: "reg.correo.legal") }

    /// Se ve bien. Te mandamos un código de 6 caracteres.
    static var regCorreoOk: String { String(localized: "reg.correo.ok") }

    /// Lo validamos antes de pedirte cualquier otro dato, así no completás todo el registro para descubrir al final q
    static var regCorreoTexto: String { String(localized: "reg.correo.texto") }

    /// Empecemos por tu correo
    static var regCorreoTitulo: String { String(localized: "reg.correo.titulo") }

    /// Poné una altura entre 50 y 260 cm.
    static var regCuerpoAlturaFueraDeRango: String { String(localized: "reg.cuerpo.altura_fuera_de_rango") }

    /// Altura (cm)
    static var regCuerpoAlturaLabel: String { String(localized: "reg.cuerpo.altura_label") }

    /// 178
    static var regCuerpoAlturaMarcador: String { String(localized: "reg.cuerpo.altura_marcador") }

    /// Poné un peso entre 20 y 400 kg.
    static var regCuerpoPesoFueraDeRango: String { String(localized: "reg.cuerpo.peso_fuera_de_rango") }

    /// Peso (kg)
    static var regCuerpoPesoLabel: String { String(localized: "reg.cuerpo.peso_label") }

    /// 72
    static var regCuerpoPesoMarcador: String { String(localized: "reg.cuerpo.peso_marcador") }

    /// El peso es la base del cálculo: litros de líquido por hora, miligramos de sodio y gramos de carbohidrato que t
    static var regCuerpoTexto: String { String(localized: "reg.cuerpo.texto") }

    /// Tu peso y tu altura
    static var regCuerpoTitulo: String { String(localized: "reg.cuerpo.titulo") }

    /// Ciclismo
    static var regDeporteCiclismo: String { String(localized: "reg.deporte.ciclismo") }

    /// Ruta, gravel o MTB
    static var regDeporteCiclismoDetalle: String { String(localized: "reg.deporte.ciclismo.detalle") }

    /// Running
    static var regDeporteRunning: String { String(localized: "reg.deporte.running") }

    /// Calle, pista o trail
    static var regDeporteRunningDetalle: String { String(localized: "reg.deporte.running.detalle") }

    /// Cada disciplina consume líquido y carbohidrato de forma distinta: en bici podés tomar más y comer sólido, corr
    static var regDeporteTexto: String { String(localized: "reg.deporte.texto") }

    /// ¿Cuál es tu deporte principal?
    static var regDeporteTitulo: String { String(localized: "reg.deporte.titulo") }

    /// Trekking
    static var regDeporteTrekking: String { String(localized: "reg.deporte.trekking") }

    /// Montaña y travesías
    static var regDeporteTrekkingDetalle: String { String(localized: "reg.deporte.trekking.detalle") }

    /// Triatlón
    static var regDeporteTriatlon: String { String(localized: "reg.deporte.triatlon") }

    /// Nado, bici y carrera
    static var regDeporteTriatlonDetalle: String { String(localized: "reg.deporte.triatlon.detalle") }

    /// Vas a recibir %lld avisos por semana, 45 min antes de cada sesión.
    static func regDiasAviso(_ arg1: Int) -> String {
        String(format: String(localized: "reg.dias.aviso"), arg1)
    }

    /// Hora de %@
    static func regDiasHoraDe(_ arg1: String) -> String {
        String(format: String(localized: "reg.dias.hora_de"), arg1)
    }

    /// Elegí al menos un día para activar los avisos.
    static var regDiasSinDias: String { String(localized: "reg.dias.sin_dias") }

    /// Esto no es un dato de perfil: es lo que dispara los avisos. Te escribimos 45 minutos antes de cada sesión para
    static var regDiasTexto: String { String(localized: "reg.dias.texto") }

    /// ¿Qué días y a qué hora entrenás?
    static var regDiasTitulo: String { String(localized: "reg.dias.titulo") }

    /// Deporte
    static var regListoDeporte: String { String(localized: "reg.listo.deporte") }

    /// Días
    static var regListoDias: String { String(localized: "reg.listo.dias") }

    /// Ir a mi inicio
    static var regListoIrAInicio: String { String(localized: "reg.listo.ir_a_inicio") }

    /// Nacimiento
    static var regListoNacimiento: String { String(localized: "reg.listo.nacimiento") }

    /// Nivel
    static var regListoNivel: String { String(localized: "reg.listo.nivel") }

    /// Objetivo
    static var regListoObjetivo: String { String(localized: "reg.listo.objetivo") }

    /// Plan de base
    static var regListoPlanDeBase: String { String(localized: "reg.listo.plan_de_base") }

    /// Tu perfil quedó completo. Con estos datos ya calculamos hidratación, sales y carbohidratos para cada sesión, y
    static var regListoTexto: String { String(localized: "reg.listo.texto") }

    /// Todo listo, %@
    static func regListoTitulo(_ arg1: String) -> String {
        String(format: String(localized: "reg.listo.titulo"), arg1)
    }

    /// Ahora no
    static var regMedicionAhoraNo: String { String(localized: "reg.medicion.ahora_no") }

    /// Apple Watch y Salud
    static var regMedicionApple: String { String(localized: "reg.medicion.apple") }

    /// Pulso, pasos y entrenamientos
    static var regMedicionAppleDetalle: String { String(localized: "reg.medicion.apple.detalle") }

    /// Reloj Garmin
    static var regMedicionGarmin: String { String(localized: "reg.medicion.garmin") }

    /// Ritmo, pulso y altimetría
    static var regMedicionGarminDetalle: String { String(localized: "reg.medicion.garmin.detalle") }

    /// GPS del teléfono
    static var regMedicionGps: String { String(localized: "reg.medicion.gps") }

    /// Ritmo y distancia, sin accesorios
    static var regMedicionGpsDetalle: String { String(localized: "reg.medicion.gps.detalle") }

    /// Cargo todo a mano
    static var regMedicionManual: String { String(localized: "reg.medicion.manual") }

    /// Estimamos con peso, clima y ritmo objetivo
    static var regMedicionManualDetalle: String { String(localized: "reg.medicion.manual.detalle") }

    /// Esta respuesta todavía no se guarda: el contrato no tiene dónde. Está anotado como B-006 y no bloquea nada: po
    static var regMedicionNoSeGuarda: String { String(localized: "reg.medicion.no_se_guarda") }

    /// Si conectás tu reloj o el GPS del teléfono, ajustamos hidratación y geles con el ritmo y la frecuencia cardíac
    static var regMedicionTexto: String { String(localized: "reg.medicion.texto") }

    /// ¿Con qué medís tus salidas?
    static var regMedicionTitulo: String { String(localized: "reg.medicion.titulo") }

    /// año
    static var regNacimientoAnio: String { String(localized: "reg.nacimiento.anio") }

    /// día
    static var regNacimientoDia: String { String(localized: "reg.nacimiento.dia") }

    /// Mové la rueda hasta tu fecha de nacimiento para seguir.
    static var regNacimientoFaltaElegir: String { String(localized: "reg.nacimiento.falta_elegir") }

    /// Orden según tu idioma (%@): %@
    static func regNacimientoFormato(_ arg1: String, _ arg2: String) -> String {
        String(format: String(localized: "reg.nacimiento.formato"), arg1, arg2)
    }

    /// mes
    static var regNacimientoMes: String { String(localized: "reg.nacimiento.mes") }

    /// ¡Hola, %@!
    static func regNacimientoSaludo(_ arg1: String) -> String {
        String(format: String(localized: "reg.nacimiento.saludo"), arg1)
    }

    /// La edad define tus zonas de frecuencia cardíaca, el ritmo de sudoración estimado y cuántas calorías necesitás 
    static var regNacimientoTexto: String { String(localized: "reg.nacimiento.texto") }

    /// %@ ¿Cuándo naciste?
    static func regNacimientoTitulo(_ arg1: String) -> String {
        String(format: String(localized: "reg.nacimiento.titulo"), arg1)
    }

    /// Avanzado
    static var regNivelAvanzado: String { String(localized: "reg.nivel.avanzado") }

    /// Más de 3 años, con competencias en el calendario
    static var regNivelAvanzadoDetalle: String { String(localized: "reg.nivel.avanzado.detalle") }

    /// Intermedio
    static var regNivelIntermedio: String { String(localized: "reg.nivel.intermedio") }

    /// 1 a 3 años entrenando de forma regular
    static var regNivelIntermedioDetalle: String { String(localized: "reg.nivel.intermedio.detalle") }

    /// Principiante
    static var regNivelPrincipiante: String { String(localized: "reg.nivel.principiante") }

    /// Menos de un año entrenando o volviendo después de un parate
    static var regNivelPrincipianteDetalle: String { String(localized: "reg.nivel.principiante.detalle") }

    /// Define desde qué volumen arranca tu plan y cuánto puede crecer por semana sin exponerte a lesiones. Si volvés 
    static var regNivelTexto: String { String(localized: "reg.nivel.texto") }

    /// ¿Hace cuánto entrenás?
    static var regNivelTitulo: String { String(localized: "reg.nivel.titulo") }

    /// Nombre
    static var regNombreLabel: String { String(localized: "reg.nombre.label") }

    /// Iván
    static var regNombreMarcador: String { String(localized: "reg.nombre.marcador") }

    /// Usamos tu nombre para hablarte en las notificaciones y en el resumen de cada semana. El apellido solo aparece 
    static var regNombreTexto: String { String(localized: "reg.nombre.texto") }

    /// Correo validado. ¿Cómo te llamás?
    static var regNombreTitulo: String { String(localized: "reg.nombre.titulo") }

    /// 10 km
    static var regObjetivoC10k: String { String(localized: "reg.objetivo.c10k") }

    /// 10 km
    static var regObjetivoC10kDetalle: String { String(localized: "reg.objetivo.c10k.detalle") }

    /// 5 km
    static var regObjetivoC5k: String { String(localized: "reg.objetivo.c5k") }

    /// 5 km · plan de 4 semanas
    static var regObjetivoC5kDetalle: String { String(localized: "reg.objetivo.c5k.detalle") }

    /// %@ · faltan %lld semanas
    static func regObjetivoConFecha(_ arg1: String, _ arg2: Int) -> String {
        String(format: String(localized: "reg.objetivo.con_fecha"), arg1, arg2)
    }

    /// Elegí tu objetivo
    static var regObjetivoElegi: String { String(localized: "reg.objetivo.elegi") }

    /// Maratón
    static var regObjetivoMaraton: String { String(localized: "reg.objetivo.maraton") }

    /// 42,2 km
    static var regObjetivoMaratonDetalle: String { String(localized: "reg.objetivo.maraton.detalle") }

    /// Media maratón
    static var regObjetivoMediaMaraton: String { String(localized: "reg.objetivo.media_maraton") }

    /// 21,1 km
    static var regObjetivoMediaMaratonDetalle: String { String(localized: "reg.objetivo.media_maraton.detalle") }

    /// Mes anterior
    static var regObjetivoMesAnterior: String { String(localized: "reg.objetivo.mes_anterior") }

    /// Mes siguiente
    static var regObjetivoMesSiguiente: String { String(localized: "reg.objetivo.mes_siguiente") }

    /// Todavía sin fecha: vamos a armar un plan de base.
    static var regObjetivoSinFecha: String { String(localized: "reg.objetivo.sin_fecha") }

    /// Con la fecha del evento armamos la cuenta regresiva y repartimos las semanas de carga, descarga y afinamiento.
    static var regObjetivoTexto: String { String(localized: "reg.objetivo.texto") }

    /// ¿Para qué estás entrenando?
    static var regObjetivoTitulo: String { String(localized: "reg.objetivo.titulo") }

    /// Trail de montaña
    static var regObjetivoTrailMontana: String { String(localized: "reg.objetivo.trail_montana") }

    /// 25-50 km
    static var regObjetivoTrailMontanaDetalle: String { String(localized: "reg.objetivo.trail_montana.detalle") }

    /// Triatlón olímpico
    static var regObjetivoTriatlonOlimpico: String { String(localized: "reg.objetivo.triatlon_olimpico") }

    /// 1,5 / 40 / 10 km
    static var regObjetivoTriatlonOlimpicoDetalle: String { String(localized: "reg.objetivo.triatlon_olimpico.detalle") }

    /// Volver a entrenar sin lesiones
    static var regObjetivoVolverSinLesiones: String { String(localized: "reg.objetivo.volver_sin_lesiones") }

    /// sin distancia fija
    static var regObjetivoVolverSinLesionesDetalle: String { String(localized: "reg.objetivo.volver_sin_lesiones.detalle") }

    /// Entiendo que Stamina da sugerencias generales y que ante cualquier síntoma tengo que parar y consultar.
    static var regSaludAcepto: String { String(localized: "reg.salud.acepto") }

    /// Marcá que entendiste el descargo para poder seguir.
    static var regSaludFaltaAceptar: String { String(localized: "reg.salud.falta_aceptar") }

    /// Pará y consultá si aparece
    static var regSaludParaYConsulta: String { String(localized: "reg.salud.para_y_consulta") }

    /// Dolor u opresión en el pecho
    static var regSaludSintoma1: String { String(localized: "reg.salud.sintoma1") }

    /// Dificultad respiratoria grave o mareos
    static var regSaludSintoma2: String { String(localized: "reg.salud.sintoma2") }

    /// Dolor articular que empeora mientras corrés
    static var regSaludSintoma3: String { String(localized: "reg.salud.sintoma3") }

    /// No somos médicos y esta app no reemplaza una consulta. Si tenés alguna condición previa, tomás medicación o ha
    static var regSaludTexto: String { String(localized: "reg.salud.texto") }

    /// Antes de arrancar, una sola cosa
    static var regSaludTitulo: String { String(localized: "reg.salud.titulo") }

    /// Femenino
    static var regSexoFemenino: String { String(localized: "reg.sexo.femenino") }

    /// Menor tasa de sudoración media y distinta pérdida de sodio
    static var regSexoFemeninoDetalle: String { String(localized: "reg.sexo.femenino.detalle") }

    /// Masculino
    static var regSexoMasculino: String { String(localized: "reg.sexo.masculino") }

    /// Mayor tasa de sudoración media para el mismo peso y ritmo
    static var regSexoMasculinoDetalle: String { String(localized: "reg.sexo.masculino.detalle") }

    /// Prefiero no decirlo
    static var regSexoSinDeclarar: String { String(localized: "reg.sexo.sin_declarar") }

    /// Sin este dato, algunas partes del plan pueden no estar disponibles
    static var regSexoSinDeclararDetalle: String { String(localized: "reg.sexo.sin_declarar.detalle") }

    /// Las tasas de sudoración, la pérdida de sodio y el gasto calórico difieren bastante entre hombres y mujeres con
    static var regSexoTexto: String { String(localized: "reg.sexo.texto") }

    /// ¿Con qué sexo biológico calculamos tu sudoración?
    static var regSexoTitulo: String { String(localized: "reg.sexo.titulo") }

    /// Error en el registro
    static var registroErrorTitulo: String { String(localized: "registro.error.titulo") }

    /// Listo
    static var resumenGuardarCerrar: String { String(localized: "resumen.guardar_cerrar") }

    /// Pulso máx
    static var resumenPulsoMax: String { String(localized: "resumen.pulso_max") }

    /// Pulso medio
    static var resumenPulsoMedio: String { String(localized: "resumen.pulso_medio") }

    /// ¡Mantuviste tu racha de fueguito!
    static var resumenRachaMantenida: String { String(localized: "resumen.racha_mantenida") }

    /// Resumen del entrenamiento
    static var resumenSalidaTitulo: String { String(localized: "resumen.salida_titulo") }

    /// Serie %1$lld hecha · %2$@
    static func serieConfirmar(_ arg1: Int, _ arg2: String) -> String {
        String(format: String(localized: "serie.confirmar"), arg1, arg2)
    }

    /// Corregir la serie %lld
    static func serieCorregir(_ arg1: Int) -> String {
        String(format: String(localized: "serie.corregir"), arg1)
    }

    /// Serie extra
    static var serieExtra: String { String(localized: "serie.extra") }

    /// Peso
    static var seriePeso: String { String(localized: "serie.peso") }

    /// Repeticiones
    static var serieRepeticiones: String { String(localized: "serie.repeticiones") }

    /// Salteada
    static var serieSalteada: String { String(localized: "serie.salteada") }

    /// Saltear
    static var serieSaltear: String { String(localized: "serie.saltear") }

    /// Segundos
    static var serieSegundos: String { String(localized: "serie.segundos") }

    /// Ir al ejercicio siguiente
    static var serieSiguiente: String { String(localized: "serie.siguiente") }

    /// Serie %1$lld de %2$lld
    static func serieTitulo(_ arg1: Int, _ arg2: Int) -> String {
        String(format: String(localized: "serie.titulo"), arg1, arg2)
    }

    /// Tu sesión ha expirado. Por favor, inicia sesión nuevamente para continuar.
    static var sesionExpiradaMensaje: String { String(localized: "sesion.expirada.mensaje") }

    /// Sesión expirada
    static var sesionExpiradaTitulo: String { String(localized: "sesion.expirada.titulo") }

    /// Mismo patrón de movimiento
    static var sustitutosMismoPatron: String { String(localized: "sustitutos.mismo_patron") }

    /// Reemplazar
    static var sustitutosReemplazar: String { String(localized: "sustitutos.reemplazar") }

    /// Sustitutos de %@
    static func sustitutosTitulo(_ arg1: String) -> String {
        String(format: String(localized: "sustitutos.titulo"), arg1)
    }

    /// Actualizar
    static var versionActualizar: String { String(localized: "version.actualizar") }

    /// Ahora no
    static var versionAhoraNo: String { String(localized: "version.ahora_no") }

    /// Podés seguir usando esta, pero conviene actualizar.
    static var versionRecomendadaTexto: String { String(localized: "version.recomendada.texto") }

    /// Hay una versión nueva de Stamina
    static var versionRecomendadaTitulo: String { String(localized: "version.recomendada.titulo") }

    /// Esta versión ya no puede hablar con el servidor. Actualizá desde la App Store para seguir.
    static var versionRequeridaTexto: String { String(localized: "version.requerida.texto") }

    /// Hay que actualizar Stamina
    static var versionRequeridaTitulo: String { String(localized: "version.requerida.titulo") }

    /// alta
    static var zonaAlta: String { String(localized: "zona.alta") }

    /// baja
    static var zonaBaja: String { String(localized: "zona.baja") }

    /// máxima
    static var zonaMaxima: String { String(localized: "zona.maxima") }

    /// moderada
    static var zonaModerada: String { String(localized: "zona.moderada") }

    /// moderada-alta
    static var zonaModeradaAlta: String { String(localized: "zona.moderada_alta") }

    /// Zona %lld
    static func zonaVoiceover(_ arg1: Int) -> String {
        String(format: String(localized: "zona.voiceover"), arg1)
    }
}
