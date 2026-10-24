package com.tecladus.trainer.core.red

import java.net.URLEncoder
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Los endpoints del contrato 1.1.0 que no son de la sesión —plan, nutrición, gimnasio y
 * catálogo—, leídos contra respuestas REALES.
 *
 * Los JSON de `src/test/resources/respuestas-1.1.0/` se capturaron de staging el
 * 2026-09-10 y no se tocan a mano. Una respuesta escrita a mano prueba lo que quien la
 * escribió cree que manda el servidor, que es justo el error que esto busca: un campo que
 * se llama distinto, un enum que el cliente no conoce, un opcional que viene ausente. Si
 * el servidor cambia, se vuelven a capturar.
 *
 * Además de leer, cada test mira lo que SALE: método, ruta, token y, donde hace falta, la
 * clave de idempotencia. Ninguno habla con un servidor de verdad.
 */
class ApiDelPlanYElGimnasioTest {

    private fun respuestaReal(nombre: String): String =
        requireNotNull(javaClass.getResource("/respuestas-1.1.0/$nombre.json")) {
            "falta src/test/resources/respuestas-1.1.0/$nombre.json"
        }.readText()

    /** Una API con una sesión guardada, contra un servidor que contesta [contestar]. */
    private fun conSesion(contestar: suspend (PedidoHttp) -> RespuestaHttp): Pair<ApiTrainer, ServidorDeMentira> {
        val servidor = ServidorDeMentira(contestar)
        val cliente = ClienteApi(BASE, AlmacenDeSesionEnMemoria(sesionDePrueba(1)), servidor, reloj = { AHORA })
        return ApiTrainer(cliente) to servidor
    }

    private fun <T> ok(r: Resultado<T>): T {
        assertTrue("se esperaba Ok y llegó $r", r is Resultado.Ok)
        return (r as Resultado.Ok).dato
    }

    private fun serieDePrueba(numero: Int = 1, pesoG: Int? = 12_000) = SerieDeGimnasioEntrada(
        exerciseId = "estocada-deficit",
        number = numero,
        done = true,
        reps = 10,
        weightG = pesoG,
        skipped = false,
        isExtra = false,
        recordedAtMs = 1_789_033_482_979,
        device = DispositivoDeOrigen.TELEFONO,
    )

    // ----------------------------------------------------------------- plan --

    @Test
    fun `el plan se lee entero de la respuesta real`() = runBlocking {
        val (api, servidor) = conSesion { RespuestaHttp(200, respuestaReal("plan")) }
        api.restaurarSesion()

        val plan = ok(api.plan())

        val pedido = servidor.pedidos.single()
        assertEquals("GET", pedido.metodo)
        assertEquals("/plan", pedido.ruta)
        assertEquals("sale con el token de la sesión", "acceso-1", pedido.acceso)
        assertEquals(Objetivo.MEDIA_MARATON, plan.goal)
        assertEquals(11, plan.totalWeeks)
        assertEquals(plan.totalWeeks, plan.weeks.size)
        assertEquals(71, plan.days.size)
        assertEquals(
            listOf(Fase.BASE, Fase.CONSTRUCCION, Fase.PICO, Fase.AFINAMIENTO, Fase.CARRERA),
            plan.phases.map { it.phase },
        )
        // Si el servidor suma un tipo de día que el cliente no conoce, esto deja de leer y
        // lo dice acá, y no en el teléfono de alguien.
        assertTrue(plan.days.any { it.type == TipoDeSesion.DESCANSO })
        assertTrue(plan.days.any { it.type == TipoDeSesion.FUERZA && it.sport == DeporteDeSesion.FUERZA })
        val primero = plan.days.first()
        assertEquals(plan.startDateMs, primero.dateMs)
        assertEquals("suave_en_los_dias_restantes", primero.reasons.first().code)
        assertTrue("el avituallamiento viene en los días que lo llevan", primero.fueling != null)
        assertTrue("y no en los que no", plan.days.any { it.fueling == null })
    }

    @Test
    fun `sin perfil completo el plan dice profile_incomplete, que no es falta de red`() = runBlocking {
        val (api, _) = conSesion { RespuestaHttp(400, respuestaReal("error-profile-incomplete")) }
        api.restaurarSesion()

        val r = api.plan()

        assertTrue("$r", r is Resultado.Rechazado)
        assertEquals("profile_incomplete", (r as Resultado.Rechazado).codigo)
    }

    @Test
    fun `la rutina se pide con el instante y trae la prescripcion serie por serie`() = runBlocking {
        val (api, servidor) = conSesion { RespuestaHttp(200, respuestaReal("rutina-del-dia")) }
        api.restaurarSesion()

        val rutina = ok(api.rutinaDelDia(AHORA))

        assertEquals("/plan/routine?date_ms=$AHORA", servidor.rutas().single())
        assertEquals("gym-2026-09-10", rutina.sessionId)
        assertEquals(1_789_009_200_000L, rutina.dateMs)
        assertFalse(rutina.planned)
        assertEquals(listOf("mancuernas", "banco", "ninguno"), rutina.equipmentAssumed)
        assertEquals(6, rutina.exercises.size)
        val extension = rutina.exercises[1]
        assertEquals("extension-lumbar", extension.exerciseId)
        assertEquals(75, extension.restS)
        assertEquals(listOf(1, 2, 3), extension.sets.map { it.number })
        assertEquals(listOf(10, 10, 10), extension.sets.map { it.reps })
        assertNull("el motor no prescribe carga", extension.sets.first().weightG)
        assertTrue("sin historial la columna PREVIA viene vacía", extension.previousSets.isEmpty())
    }

    @Test
    fun `la rutina con historial trae la columna PREVIA, con peso y con peso corporal`() = runBlocking {
        val (api, _) = conSesion { RespuestaHttp(200, respuestaReal("rutina-con-series-previas")) }
        api.restaurarSesion()

        val rutina = ok(api.rutinaDelDia(AHORA))

        assertEquals("gym-2026-09-11", rutina.sessionId)
        val zancada = rutina.exercises.first { it.exerciseId == "estocada-deficit" }
        assertEquals(listOf(1, 2), zancada.previousSets.map { it.number })
        assertEquals(12_000, zancada.previousSets[0].weightG)
        assertNull("sin weight_g es peso corporal, no cero", zancada.previousSets[1].weightG)
        assertEquals(8, zancada.previousSets[1].reps)
        assertFalse(zancada.previousSets[1].skipped)
        val plancha = rutina.exercises.first { it.exerciseId == "plancha-pies-elevados" }
        assertEquals("con tiempo, las repeticiones son segundos", "tiempo", plancha.unit)
        assertEquals(40, plancha.sets.first().reps)
    }

    // ------------------------------------------------------------ nutrición --

    @Test
    fun `la nutricion del dia trae los objetivos y lo comido`() = runBlocking {
        val (api, servidor) = conSesion { RespuestaHttp(200, respuestaReal("nutricion-del-dia")) }
        api.restaurarSesion()

        val dia = ok(api.nutricionDelDia(AHORA))

        assertEquals("/nutrition/day?date_ms=$AHORA", servidor.rutas().single())
        val objetivos = requireNotNull(dia.targets)
        assertEquals(2750, objetivos.kcal)
        assertEquals(CargaDelDia.BAJA, objetivos.dayLoad)
        assertTrue(objetivos.provisional)
        assertNull(dia.unavailableReason)
        assertEquals(420, dia.consumed.kcal)
        assertEquals("Avena con banana", dia.meals.single().name)
    }

    @Test
    fun `sin objetivos viene el motivo y ningun numero`() = runBlocking {
        val (api, _) = conSesion { RespuestaHttp(200, respuestaReal("nutricion-sin-objetivos")) }
        api.restaurarSesion()

        val dia = ok(api.nutricionDelDia(AHORA))

        assertNull("§9.2: sin objetivos no hay un número inventado", dia.targets)
        assertEquals(MotivoSinObjetivos.FALTA_EMBARAZO_O_LACTANCIA, dia.unavailableReason)
        assertEquals("lo comido se ve igual", 1, dia.meals.size)
    }

    @Test
    fun `los objetivos de una mujer se leen con sus propios numeros`() = runBlocking {
        val (api, _) = conSesion { RespuestaHttp(200, respuestaReal("nutricion-con-objetivos-mujer")) }
        api.restaurarSesion()

        val objetivos = requireNotNull(ok(api.nutricionDelDia(AHORA)).targets)

        assertEquals(2526, objetivos.kcal)
        assertEquals(70, objetivos.fatG)
        assertFalse(objetivos.adjusted)
        assertNull(objetivos.adjustmentReason)
    }

    @Test
    fun `guardar una comida es un PUT con el id que eligio el cliente`() = runBlocking {
        val (api, servidor) = conSesion { RespuestaHttp(200, respuestaReal("comida")) }
        api.restaurarSesion()
        val id = "063349d2-0a4b-45c5-9cf6-c54d692ea7ad"
        val comida = ComidaEntrada(
            eatenAtMs = 1_789_033_542_979,
            name = "Avena con banana",
            kcal = 420,
            carbsG = 72,
            proteinG = 12,
            fatG = 9,
        )

        val registrada = ok(api.guardarComida(id, comida))

        val pedido = servidor.pedidos.single()
        assertEquals("PUT", pedido.metodo)
        assertEquals("/meals/$id", pedido.ruta)
        val cuerpo = Json.parseToJsonElement(requireNotNull(pedido.cuerpo)).jsonObject
        assertEquals(setOf("eaten_at_ms", "name", "kcal", "carbs_g", "protein_g", "fat_g"), cuerpo.keys)
        assertEquals(id, registrada.id)
        assertEquals(1_789_033_544_452L, registrada.createdAtMs)
    }

    @Test
    fun `borrar una comida es un DELETE sin cuerpo que contesta 204`() = runBlocking {
        val (api, servidor) = conSesion { RespuestaHttp(204, "") }
        api.restaurarSesion()

        assertEquals(Resultado.Ok(Unit), api.borrarComida("063349d2-0a4b-45c5-9cf6-c54d692ea7ad"))

        val pedido = servidor.pedidos.single()
        assertEquals("DELETE", pedido.metodo)
        assertEquals("/meals/063349d2-0a4b-45c5-9cf6-c54d692ea7ad", pedido.ruta)
        assertNull(pedido.cuerpo)
    }

    @Test
    fun `marcar un dia como hecho es un PUT con el instante que contesta 204`() = runBlocking {
        val (api, servidor) = conSesion { RespuestaHttp(204, "") }
        api.restaurarSesion()

        assertEquals(Resultado.Ok(Unit), api.marcarDiaHecho(1_789_033_542_979, clave = "clave-1"))

        val pedido = servidor.pedidos.single()
        assertEquals("PUT", pedido.metodo)
        assertEquals("/plan/days/done", pedido.ruta)
        val cuerpo = Json.parseToJsonElement(requireNotNull(pedido.cuerpo)).jsonObject
        assertEquals(setOf("date_ms"), cuerpo.keys)
    }

    // ------------------------------------------------------------- gimnasio --

    @Test
    fun `subir series manda la clave y el cuerpo del contrato, y lee la sesion fusionada`() = runBlocking {
        val (api, servidor) = conSesion { RespuestaHttp(200, respuestaReal("series-sincronizadas")) }
        api.restaurarSesion()
        val series = listOf(serieDePrueba(1), serieDePrueba(2, pesoG = null))

        val sesion = ok(api.sincronizarSeries("gym-2026-09-10", series, clave = "intento-1"))

        val pedido = servidor.pedidos.single()
        assertEquals("POST", pedido.metodo)
        assertEquals("/gym/sessions/gym-2026-09-10/sets", pedido.ruta)
        assertEquals("intento-1", pedido.headers["Idempotency-Key"])
        val cuerpo = Json.parseToJsonElement(requireNotNull(pedido.cuerpo)).jsonObject
        assertEquals("el contrato no admite nada más que sets", setOf("sets"), cuerpo.keys)
        val enviadas = cuerpo.getValue("sets").jsonArray.map { it.jsonObject }
        assertEquals("12000", enviadas[0].getValue("weight_g").jsonPrimitive.content)
        assertFalse("sin peso el campo no viaja: ausente es peso corporal", "weight_g" in enviadas[1])
        assertEquals("telefono", enviadas[0].getValue("device").jsonPrimitive.content)
        assertEquals("1789033482979", enviadas[0].getValue("recorded_at_ms").jsonPrimitive.content)

        assertEquals("gym-2026-09-10", sesion.sessionId)
        assertEquals(1_789_009_200_000L, sesion.dateMs)
        assertEquals(listOf(1, 2), sesion.sets.map { it.number })
        assertEquals(1_789_033_543_346L, sesion.sets[0].receivedAtMs)
        assertTrue(sesion.sets[0].done)
        assertEquals(DispositivoDeOrigen.RELOJ, sesion.sets[1].device)
        assertNull(sesion.sets[1].weightG)
    }

    @Test
    fun `el reintento despues de renovar la sesion sale con la misma clave y el mismo cuerpo`() = runBlocking {
        // Es el mismo intento: con otra clave el servidor lo escribiría dos veces, y con la
        // misma clave y otro cuerpo contestaría 409.
        val renovada = sesionDePrueba(2)
        val (api, servidor) = conSesion { pedido ->
            when {
                pedido.ruta == "/auth/refresh" -> respuestaConSesion(renovada)
                pedido.acceso == renovada.accessToken -> RespuestaHttp(200, respuestaReal("series-sincronizadas"))
                else -> rechazo(401, "unauthorized")
            }
        }
        api.restaurarSesion()

        ok(api.sincronizarSeries("gym-2026-09-10", listOf(serieDePrueba()), clave = "intento-7"))

        val envios = servidor.deLaRuta("/gym/sessions/gym-2026-09-10/sets")
        assertEquals(2, envios.size)
        assertEquals(listOf("intento-7", "intento-7"), envios.map { it.headers["Idempotency-Key"] })
        assertEquals(envios[0].cuerpo, envios[1].cuerpo)
    }

    @Test
    fun `leer una sesion de gimnasio`() = runBlocking {
        val (api, servidor) = conSesion { RespuestaHttp(200, respuestaReal("sesion-de-gimnasio")) }
        api.restaurarSesion()

        val sesion = ok(api.sesionDeGimnasio("gym-2026-09-10"))

        val pedido = servidor.pedidos.single()
        assertEquals("GET", pedido.metodo)
        assertEquals("/gym/sessions/gym-2026-09-10", pedido.ruta)
        assertEquals(1_789_033_543_346L, sesion.updatedAtMs)
        assertEquals(listOf(10, 8), sesion.sets.map { it.reps })
    }

    @Test
    fun `una sesion en la que nadie registro nada contesta not_found`() = runBlocking {
        val (api, _) = conSesion { RespuestaHttp(404, respuestaReal("error-not-found")) }
        api.restaurarSesion()

        assertEquals(
            Resultado.Rechazado("not_found", "Gym session not found", 404),
            api.sesionDeGimnasio("gym-2026-09-11"),
        )
    }

    @Test
    fun `un id con barras no cambia la ruta del pedido`() = runBlocking {
        val (api, servidor) = conSesion { RespuestaHttp(404, respuestaReal("error-not-found")) }
        api.restaurarSesion()

        api.sesionDeGimnasio("gym/../../me")

        assertEquals("/gym/sessions/gym%2F..%2F..%2Fme", servidor.rutas().single())
    }

    // ------------------------------------------------------------- catálogo --

    @Test
    fun `el catalogo pagina con el cursor tal cual vino, codificado`() = runBlocking {
        val paginas = ArrayDeque(listOf("ejercicios-pagina-1", "ejercicios-pagina-2"))
        val (api, servidor) = conSesion { RespuestaHttp(200, respuestaReal(paginas.removeFirst())) }
        api.restaurarSesion()

        val primera = ok(api.ejercicios(limite = 3))

        assertEquals("/exercises?limit=3", servidor.rutas().last())
        assertEquals(
            listOf("abduccion-cadera-maquina", "aduccion-cadera-maquina", "aperturas-mancuernas"),
            primera.datos.map { it.id },
        )
        assertEquals(RolDeMusculo.PRINCIPAL, primera.datos.first().muscles.first().role)
        assertTrue(primera.paginacion.hasMore)
        val cursor = requireNotNull(primera.paginacion.nextCursor)

        val segunda = ok(api.ejercicios(limite = 3, cursor = cursor))

        assertEquals(
            "/exercises?limit=3&cursor=${URLEncoder.encode(cursor, "UTF-8")}",
            servidor.rutas().last(),
        )
        assertEquals("bicho-muerto", segunda.datos.first().id)
        assertEquals(TipoDeSustituto.MISMO_PATRON, segunda.datos.first().substitutes.first().kind)
    }

    @Test
    fun `un cursor con caracteres de URL viaja codificado`() = runBlocking {
        val (api, servidor) = conSesion { RespuestaHttp(200, respuestaReal("ejercicios-pagina-2")) }
        api.restaurarSesion()

        ok(api.ejercicios(cursor = "a+b/c=="))

        assertEquals("/exercises?cursor=a%2Bb%2Fc%3D%3D", servidor.rutas().single())
    }

    @Test
    fun `una lista sin pagination es una respuesta rara y no una lista completa`() = runBlocking {
        val (api, _) = conSesion { RespuestaHttp(200, """{"data":[]}""") }
        api.restaurarSesion()

        assertTrue(api.ejercicios() is Resultado.RespuestaRara)
    }
}
