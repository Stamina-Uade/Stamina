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
// 149 claves · idioma de autoría: es
// =============================================================================

import Foundation

/// Los textos. Una propiedad por clave del catálogo: un typo en una
/// clave deja de ser un bug de producción y pasa a ser un error de compilación.
enum TextosReloj {

    /// ACTUAL
    static var ACTUAL: String { String(localized: "ACTUAL") }

    /// Alertas
    static var Alertas: String { String(localized: "Alertas") }

    /// Autopausado
    static var Autopausado: String { String(localized: "Autopausado") }

    /// Bicicleta
    static var Bicicleta: String { String(localized: "Bicicleta") }

    /// Cancelar
    static var Cancelar: String { String(localized: "Cancelar") }

    /// Carrera
    static var Carrera: String { String(localized: "Carrera") }

    /// Completado
    static var Completado: String { String(localized: "Completado") }

    /// Continuar
    static var Continuar: String { String(localized: "Continuar") }

    /// Descartar
    static var Descartar: String { String(localized: "Descartar") }

    /// Deshacer
    static var Deshacer: String { String(localized: "Deshacer") }

    /// Ejercicios
    static var Ejercicios: String { String(localized: "Ejercicios") }

    /// Finalizar
    static var Finalizar: String { String(localized: "Finalizar") }

    /// Gimnasio
    static var Gimnasio: String { String(localized: "Gimnasio") }

    /// Iniciar
    static var Iniciar: String { String(localized: "Iniciar") }

    /// No
    static var No: String { String(localized: "No") }

    /// PROMEDIO
    static var PROMEDIO: String { String(localized: "PROMEDIO") }

    /// Pausado
    static var Pausado: String { String(localized: "Pausado") }

    /// Regresar
    static var Regresar: String { String(localized: "Regresar") }

    /// Repeticiones
    static var Repeticiones: String { String(localized: "Repeticiones") }

    /// SERIES
    static var SERIES: String { String(localized: "SERIES") }

    /// Serie
    static var Serie: String { String(localized: "Serie") }

    /// Unidades
    static var Unidades: String { String(localized: "Unidades") }

    /// VUELTAS
    static var VUELTAS: String { String(localized: "VUELTAS") }

    /// Compartir ubicación
    static var abrirCompartirUbicacion: String { String(localized: "abrir.compartir_ubicacion") }

    /// Bicicleta
    static var abrirDeporteBike: String { String(localized: "abrir.deporte.bike") }

    /// Ciclismo (exterior)
    static var abrirDeporteBikeExterior: String { String(localized: "abrir.deporte.bike_exterior") }

    /// Carrera
    static var abrirDeporteRun: String { String(localized: "abrir.deporte.run") }

    /// Carrera (exterior)
    static var abrirDeporteRunExterior: String { String(localized: "abrir.deporte.run_exterior") }

    /// Trekking
    static var abrirDeporteTrek: String { String(localized: "abrir.deporte.trek") }

    /// Trekking (exterior)
    static var abrirDeporteTrekExterior: String { String(localized: "abrir.deporte.trek_exterior") }

    /// %lld ejercicios
    static func abrirEjercicios(_ arg1: Int) -> String {
        String(format: String(localized: "abrir.ejercicios"), arg1)
    }

    /// Elegí un deporte
    static var abrirElegirDeporte: String { String(localized: "abrir.elegir_deporte") }

    /// Empezar entrenamiento
    static var abrirEmpezarEntrenamiento: String { String(localized: "abrir.empezar_entrenamiento") }

    /// %lld geles
    static func abrirGeles(_ arg1: Int) -> String {
        String(format: String(localized: "abrir.geles"), arg1)
    }

    /// Gimnasio
    static var abrirGimnasio: String { String(localized: "abrir.gimnasio") }

    /// Hoy te toca
    static var abrirHoy: String { String(localized: "abrir.hoy") }

    /// Inicio
    static var abrirInicio: String { String(localized: "abrir.inicio") }

    /// %lld min
    static func abrirMinutos(_ arg1: Int) -> String {
        String(format: String(localized: "abrir.minutos"), arg1)
    }

    /// Objetivo de hoy
    static var abrirObjetivoHoy: String { String(localized: "abrir.objetivo_hoy") }

    /// Registrar
    static var abrirRegistrar: String { String(localized: "abrir.registrar") }

    /// Guía de la rutina
    static var abrirRutina: String { String(localized: "abrir.rutina") }

    /// Gimnasio y rutina de hoy
    static var abrirRutinaGimnasio: String { String(localized: "abrir.rutina_gimnasio") }

    /// No hay una sesión planificada para hoy
    static var abrirSinPlan: String { String(localized: "abrir.sin_plan") }

    /// Empezar
    static var abrirTitulo: String { String(localized: "abrir.titulo") }

    /// No compartir
    static var abrirUbicacionNo: String { String(localized: "abrir.ubicacion_no") }

    /// Compartiendo
    static var abrirUbicacionSi: String { String(localized: "abrir.ubicacion_si") }

    /// Avisos de sales y geles
    static var ajustesAvisos: String { String(localized: "ajustes.avisos") }

    /// Guía de la rutina
    static var ajustesRutina: String { String(localized: "ajustes.rutina") }

    /// Sólo para esta salida
    static var ajustesSoloEsta: String { String(localized: "ajustes.solo_esta") }

    /// Ajustes
    static var ajustesTitulo: String { String(localized: "ajustes.titulo") }

    /// Tomá 200 ml
    static var avisoAgua: String { String(localized: "aviso.agua") }

    /// Vas %1$@ de %2$@. Con 26° perdés más de lo que sentís.
    static func avisoAguaDetalle(_ arg1: String, _ arg2: String) -> String {
        String(format: String(localized: "aviso.agua.detalle"), arg1, arg2)
    }

    /// Gel + 300 ml con sales
    static var avisoGel: String { String(localized: "aviso.gel") }

    /// Vas 300 mg de sodio. Quedan 40 min de esfuerzo en Z2.
    static var avisoGelDetalle: String { String(localized: "aviso.gel.detalle") }

    /// Hecho
    static var avisoHecho: String { String(localized: "aviso.hecho") }

    /// Hidratación
    static var avisoHidratacion: String { String(localized: "aviso.hidratacion") }

    /// Listo
    static var avisoListo: String { String(localized: "aviso.listo") }

    /// Minuto %lld
    static func avisoMinuto(_ arg1: Int) -> String {
        String(format: String(localized: "aviso.minuto"), arg1)
    }

    /// Recordar en 5 min
    static var avisoRecordar: String { String(localized: "aviso.recordar") }

    /// Sin agua encima
    static var avisoSinAgua: String { String(localized: "aviso.sin_agua") }

    /// Lo que pasó
    static var avisosPaso: String { String(localized: "avisos.paso") }

    /// Todavía no hay avisos programados para esta salida.
    static var avisosSinDatos: String { String(localized: "avisos.sinDatos") }

    /// Avisos
    static var avisosTitulo: String { String(localized: "avisos.titulo") }

    /// Lo que viene
    static var avisosViene: String { String(localized: "avisos.viene") }

    /// Avisos de nutrición e hidratación
    static var avituallamientoActivar: String { String(localized: "avituallamiento.activar") }

    /// Agua (ml)
    static var avituallamientoAgua: String { String(localized: "avituallamiento.agua") }

    /// Tomá agua
    static var avituallamientoAvisoAgua: String { String(localized: "avituallamiento.aviso.agua") }

    /// Tocá para cerrar
    static var avituallamientoAvisoCerrar: String { String(localized: "avituallamiento.aviso.cerrar") }

    /// Tomá un gel
    static var avituallamientoAvisoGel: String { String(localized: "avituallamiento.aviso.gel") }

    /// Considerá las sales
    static var avituallamientoAvisoSales: String { String(localized: "avituallamiento.aviso.sales") }

    /// Geles
    static var avituallamientoGeles: String { String(localized: "avituallamiento.geles") }

    /// Sales
    static var avituallamientoSales: String { String(localized: "avituallamiento.sales") }

    /// Lo que llevás
    static var avituallamientoTitulo: String { String(localized: "avituallamiento.titulo") }

    /// Volver
    static var comunVolver: String { String(localized: "comun.volver") }

    /// Ajustes
    static var controlesAjustes: String { String(localized: "controles.ajustes") }

    /// Bloquear
    static var controlesBloquear: String { String(localized: "controles.bloquear") }

    /// Finalizar
    static var controlesFinalizar: String { String(localized: "controles.finalizar") }

    /// Pausar
    static var controlesPausar: String { String(localized: "controles.pausar") }

    /// Reanudar
    static var controlesReanudar: String { String(localized: "controles.reanudar") }

    /// Controles
    static var controlesTitulo: String { String(localized: "controles.titulo") }

    /// Vuelta
    static var controlesVuelta: String { String(localized: "controles.vuelta") }

    /// El entrenamiento está pausado. Guardalo o seguí entrenando.
    static var finalizarDetalle: String { String(localized: "finalizar.detalle") }

    /// Guardar
    static var finalizarGuardar: String { String(localized: "finalizar.guardar") }

    /// Reanudar
    static var finalizarReanudar: String { String(localized: "finalizar.reanudar") }

    /// ¿Finalizar?
    static var finalizarTitulo: String { String(localized: "finalizar.titulo") }

    /// + Serie
    static var gimnasioAgregarSerie: String { String(localized: "gimnasio.agregar_serie") }

    /// ¿Seguro que quieres descartar estos datos?
    static var gimnasioDescartarConfirmacion: String { String(localized: "gimnasio.descartar.confirmacion") }

    /// Desmarcar serie
    static var gimnasioDesmarcarSerie: String { String(localized: "gimnasio.desmarcar_serie") }

    /// Serie hecha
    static var gimnasioHecha: String { String(localized: "gimnasio.hecha") }

    /// reps
    static var gimnasioReps: String { String(localized: "gimnasio.reps") }

    /// Descartar
    static var gimnasioResumenDescartar: String { String(localized: "gimnasio.resumen.descartar") }

    /// Guardar
    static var gimnasioResumenGuardar: String { String(localized: "gimnasio.resumen.guardar") }

    /// Regresar
    static var gimnasioResumenRegresar: String { String(localized: "gimnasio.resumen.regresar") }

    /// Entrenamiento finalizado
    static var gimnasioResumenTitulo: String { String(localized: "gimnasio.resumen.titulo") }

    /// Serie %1$lld de %2$lld
    static func gimnasioSerie(_ arg1: Int, _ arg2: Int) -> String {
        String(format: String(localized: "gimnasio.serie"), arg1, arg2)
    }

    /// Técnica y movimiento
    static var gimnasioTecnica: String { String(localized: "gimnasio.tecnica") }

    /// Error al iniciar sesión
    static var loginErrorTitulo: String { String(localized: "login.error.titulo") }

    /// El recorrido llega con el GPS.
    static var mapaSinGps: String { String(localized: "mapa.sin_gps") }

    /// Recorrido
    static var mapaTitulo: String { String(localized: "mapa.titulo") }

    /// Tu ubicación
    static var mapaTuUbicacion: String { String(localized: "mapa.tu_ubicacion") }

    /// Pantalla bloqueada · apretá dos veces el botón lateral
    static var metricasBloqueada: String { String(localized: "metricas.bloqueada") }

    /// En curso
    static var metricasEnCurso: String { String(localized: "metricas.en_curso") }

    /// En pausa
    static var metricasEnPausa: String { String(localized: "metricas.en_pausa") }

    /// km
    static var metricasKm: String { String(localized: "metricas.km") }

    /// parcial
    static var metricasParcial: String { String(localized: "metricas.parcial") }

    /// promedio
    static var metricasPromedio: String { String(localized: "metricas.promedio") }

    /// pulso
    static var metricasPulso: String { String(localized: "metricas.pulso") }

    /// ritmo
    static var metricasRitmo: String { String(localized: "metricas.ritmo") }

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

    /// Unidades de distancia
    static var portadaAjustesDistancia: String { String(localized: "portada.ajustes.distancia") }

    /// Imperial · mi
    static var portadaAjustesImperial: String { String(localized: "portada.ajustes.imperial") }

    /// Métrico · km
    static var portadaAjustesMetrico: String { String(localized: "portada.ajustes.metrico") }

    /// Ajustes
    static var portadaAjustesTitulo: String { String(localized: "portada.ajustes.titulo") }

    /// Error en el registro
    static var registroErrorTitulo: String { String(localized: "registro.error.titulo") }

    /// Distancia
    static var resumenDistancia: String { String(localized: "resumen.distancia") }

    /// Duración
    static var resumenDuracion: String { String(localized: "resumen.duracion") }

    /// Guardar
    static var resumenGuardar: String { String(localized: "resumen.guardar") }

    /// Listo
    static var resumenListo: String { String(localized: "resumen.listo") }

    /// Ritmo
    static var resumenRitmo: String { String(localized: "resumen.ritmo") }

    /// Terminaste
    static var resumenTitulo: String { String(localized: "resumen.titulo") }

    /// Hoy no hay rutina
    static var rutinaSinRutina: String { String(localized: "rutina.sin_rutina") }

    /// Es un día de descanso. Disfrutalo.
    static var rutinaSinRutinaDetalle: String { String(localized: "rutina.sin_rutina.detalle") }

    /// Rutina de hoy
    static var rutinaTitulo: String { String(localized: "rutina.titulo") }

    /// Abrí Stamina en el iPhone para vincular tu cuenta al reloj.
    static var salidaIniciarEnTelefono: String { String(localized: "salida.iniciarEnTelefono") }

    /// Permití ubicación y Salud para registrar esta salida.
    static var salidaPermisoDenegado: String { String(localized: "salida.permisoDenegado") }

    /// Tu sesión ha expirado. Por favor, inicia sesión nuevamente para continuar.
    static var sesionExpiradaMensaje: String { String(localized: "sesion.expirada.mensaje") }

    /// Sesión expirada
    static var sesionExpiradaTitulo: String { String(localized: "sesion.expirada.titulo") }

    /// Cerrar y reanudar
    static var sinMovimientoCerrar: String { String(localized: "sin_movimiento.cerrar") }

    /// Descartar
    static var sinMovimientoDescartar: String { String(localized: "sin_movimiento.descartar") }

    /// No se puede guardar esta actividad porque no se detectan cambios en la ubicación.
    static var sinMovimientoDetalle: String { String(localized: "sin_movimiento.detalle") }

    /// Reanudar
    static var sinMovimientoReanudar: String { String(localized: "sin_movimiento.reanudar") }

    /// Sin movimiento
    static var sinMovimientoTitulo: String { String(localized: "sin_movimiento.titulo") }

    /// Asegúrate de que tu iPhone esté cerca y con Bluetooth encendido.
    static var sinTelefonoDesconectado: String { String(localized: "sin_telefono.desconectado") }

    /// Asegúrate de que tu teléfono esté cerca y de que hayas iniciado sesión en Stamina.
    static var sinTelefonoDetalle: String { String(localized: "sin_telefono.detalle") }

    /// Volver a intentar
    static var sinTelefonoReintentar: String { String(localized: "sin_telefono.reintentar") }

    /// Inicia sesión en Stamina desde tu iPhone para continuar.
    static var sinTelefonoSinSesion: String { String(localized: "sin_telefono.sin_sesion") }

    /// Sin teléfono cerca
    static var sinTelefonoTitulo: String { String(localized: "sin_telefono.titulo") }
}
