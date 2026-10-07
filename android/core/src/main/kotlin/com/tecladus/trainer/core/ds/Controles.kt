package com.tecladus.trainer.core.ds

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import com.tecladus.trainer.core.tema.Tema

/**
 * 🛑 El objetivo táctil mínimo de AGENTS.md §10.1, hecho modificador.
 *
 * Está acá y no repetido en cada pantalla por un motivo medido: en
 * `design/origen/` hay 14 elementos accionables que declaran altura y **los 14
 * están por debajo del mínimo**, con piso en los switches de ajustes
 * (`design/ESPECIFICACION.md` §9.2). Eso no pasa porque a nadie le importe: pasa
 * porque el mínimo vive en un documento y el `height` vive en la pantalla.
 *
 * Un control que use este modificador no puede quedar chico. Uno que no lo use,
 * sí — por eso los componentes de acá abajo lo tienen adentro y una pantalla no
 * debería construir un control tocable a mano.
 */
fun Modifier.objetivoTactil(): Modifier = this.sizeIn(
    minWidth = Tema.tactilMinimo,
    minHeight = Tema.tactilMinimo,
)

/**
 * La etiqueta de una sección: EL PLAN PIDE, SERIES.
 *
 * Pasa el texto a mayúsculas acá, en la presentación, y no en el string: un
 * string guardado en mayúsculas no se traduce bien, y un lector de pantalla lo
 * deletrea letra por letra. Que vaya en mayúsculas lo dice el token, no la
 * pantalla.
 */
@Composable
fun EtiquetaSeccion(
    texto: String,
    modifier: Modifier = Modifier,
    color: Color = Tema.color.textoSecundario,
) {
    Text(
        text = if (Tema.texto.etiquetaSeccionEnMayusculas) texto.uppercase() else texto,
        style = Tema.texto.etiquetaSeccion,
        color = color,
        modifier = modifier,
    )
}

/** La card: el fondo más usado del producto. */
@Composable
fun Card(
    modifier: Modifier = Modifier,
    fondo: Color = Tema.color.superficie,
    borde: Color = Tema.color.bordeSuperficie,
    forma: Shape = Tema.forma.card,
    contenido: @Composable () -> Unit,
) {
    Box(
        modifier = modifier
            .background(fondo, forma)
            .border(Tema.aire.e1, borde, forma)
            .padding(horizontal = Tema.aire.e14, vertical = Tema.aire.e13),
    ) {
        contenido()
    }
}

/**
 * El botón que confirma. Lleva DOS líneas a propósito: el título dice la acción y
 * el detalle dice **lo que se va a guardar** ("Serie 3 hecha" / "8 × 45 kg"), así
 * que confirmar es un tap y no es a ciegas.
 *
 * No tiene altura fija: crece con el contenido y no puede bajar del mínimo táctil.
 */
@Composable
fun BotonPrimario(
    titulo: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    detalle: String? = null,
    habilitado: Boolean = true,
) {
    val fondo = if (habilitado) Tema.color.acento else Tema.color.superficieControl
    val frente = if (habilitado) Tema.color.sobreAcento else Tema.color.textoDeshabilitado
    Column(
        modifier = modifier
            .objetivoTactil()
            .background(fondo, Tema.forma.card)
            .clickable(enabled = habilitado, onClick = onClick)
            .padding(horizontal = Tema.aire.e14, vertical = Tema.aire.e10),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = titulo,
            style = Tema.texto.valorDato,
            color = frente,
            textAlign = TextAlign.Center,
        )
        if (detalle != null) {
            Text(
                text = detalle,
                style = Tema.texto.tituloCard,
                color = frente,
                textAlign = TextAlign.Center,
            )
        }
    }
}

/**
 * El botón de contorno: Saltear, Serie extra, +30 s.
 *
 * El borde va en `bordeSignificante` y no en el borde decorativo de card: acá el
 * borde ES el control, y WCAG 1.4.11 pide 3.0:1 para eso. El decorativo da 1.2:1.
 */
@Composable
fun BotonSecundario(
    texto: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icono: (@Composable (Color, Modifier) -> Unit)? = null,
) {
    val frente = Tema.color.textoPrimario
    Row(
        modifier = modifier
            .objetivoTactil()
            .heightIn(min = Tema.tactilMinimo)
            .border(Tema.aire.e1, Tema.color.bordeSignificante, Tema.forma.boton)
            .clickable(onClick = onClick)
            .padding(horizontal = Tema.aire.e12),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icono != null) {
            // El ícono es decoración: lo que dice el control lo dice el texto de al
            // lado, y el lector de pantalla no tiene que leerlo dos veces.
            Box(modifier = Modifier.clearAndSetSemantics { }) {
                icono(frente, Modifier.size(Iconos.tamano))
            }
            Box(modifier = Modifier.size(Tema.aire.e7))
        }
        Text(text = texto, style = Tema.texto.tituloCard, color = frente)
    }
}

/**
 * Un botón que es sólo texto en el color de acento: "Ya tengo cuenta",
 * "Registrate", "Cambiar correo".
 *
 * No tiene borde ni relleno, así que lo único que lo hace un control es el color y
 * la posición. Por eso lleva [objetivoTactil]: sin él serían 17 dp de alto y no se
 * podrían tocar. El diseño los dibuja con `padding:12px` y `cursor:pointer`, que en
 * una pantalla táctil no alcanza.
 *
 * @param enfasis `true` pinta el texto en el acento (la acción que el diseño
 *   destaca); `false` lo pinta en el secundario ("¿Olvidaste tu contraseña?").
 */
@Composable
fun BotonDeTexto(
    texto: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enfasis: Boolean = true,
) {
    Box(
        modifier = modifier
            .objetivoTactil()
            .clickable(onClick = onClick)
            .padding(horizontal = Tema.aire.e8),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = texto,
            style = Tema.texto.tituloCard,
            color = if (enfasis) Tema.color.acento else Tema.color.textoSecundario,
            textAlign = TextAlign.Center,
        )
    }
}

/**
 * La flecha de volver. El diseño la dibuja como un `‹` de 19 px sin área tocable;
 * acá es un cuadrado de [objetivoTactil] con la flecha centrada.
 *
 * Lleva [etiqueta] porque un chevron solo no dice nada: para un lector de pantalla
 * es un glifo, y "volver" es la única palabra que sirve.
 */
@Composable
fun BotonVolver(
    etiqueta: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .objetivoTactil()
            .clickable(onClick = onClick)
            .semantics { contentDescription = etiqueta },
        contentAlignment = Alignment.Center,
    ) {
        Iconos.ChevronIzquierda(Tema.color.textoSecundario, Modifier.size(Iconos.tamano))
    }
}

/**
 * El encabezado del registro: la flecha para volver y la barra de progreso.
 *
 * La barra NO es decoración. Un registro de trece pasos sin ninguna señal de
 * cuánto falta se abandona; el diseño la puso por eso y acá se conserva. Como una
 * barra de 3 dp no se lee con lector de pantalla, el progreso va también en
 * `stateDescription` con [descripcionDelProgreso], que la pantalla arma con un
 * string traducible ("Paso 2 de 13").
 *
 * @param paso el paso actual, empezando en 1.
 * @param total cuántos pasos son en total.
 * @param onVolver `null` en los pasos de los que NO se vuelve — el primero del
 *   flujo, y los de perfil una vez que la cuenta ya existe. En ese caso la flecha
 *   no se dibuja pero **su lugar se conserva**: si desapareciera, la barra se
 *   correría de golpe al pasar de un paso a otro y el salto se ve como un bug.
 */
@Composable
fun EncabezadoDeRegistro(
    paso: Int,
    total: Int,
    descripcionDelProgreso: String,
    etiquetaVolver: String,
    onVolver: (() -> Unit)?,
    modifier: Modifier = Modifier,
) {
    val fraccion = if (total <= 0) 0f else (paso.coerceIn(1, total).toFloat() / total)
    Row(
        modifier = modifier.padding(horizontal = Tema.aire.e14, vertical = Tema.aire.e6),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Tema.aire.e8),
    ) {
        if (onVolver != null) {
            BotonVolver(etiqueta = etiquetaVolver, onClick = onVolver)
        } else {
            Box(modifier = Modifier.objetivoTactil())
        }
        Box(
            modifier = Modifier
                .weight(1f)
                .height(Tema.aire.e3)
                .background(Tema.color.superficieHundida, Tema.forma.minimo)
                .semantics { stateDescription = descripcionDelProgreso },
        ) {
            Box(
                modifier = Modifier
                    .fillMaxHeight()
                    .fillMaxWidth(fraccion)
                    .background(Tema.color.acento, Tema.forma.minimo),
            )
        }
    }
}

/**
 * Una línea de aviso: un ícono chico y un texto.
 *
 * Existe para reemplazar a los emojis que había al principio de esos strings. Un
 * emoji en un mensaje lo dibuja el sistema: cambia de forma entre teléfonos, no se
 * puede teñir con el color del tema, y un lector de pantalla lo lee con el nombre
 * que le puso Unicode —"señal de construcción"— en el medio de la frase. Un
 * ícono de acá se tiñe, se mide y NO se lee, porque lo que dice lo dice el texto.
 *
 * @param icono el glifo de [Iconos]. Es decoración: se le saca la semántica.
 * @param tono el color del texto y del ícono. Por defecto, el terciario.
 */
@Composable
fun Nota(
    texto: String,
    icono: @Composable (Color, Modifier) -> Unit,
    modifier: Modifier = Modifier,
    tono: Color? = null,
    estilo: TextStyle? = null,
) {
    val color = tono ?: Tema.color.textoTerciario
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(Tema.aire.e7),
        verticalAlignment = Alignment.Top,
    ) {
        // Decoración: lo que dice el aviso lo dice el texto de al lado, y un lector
        // de pantalla no tiene que leerlo dos veces.
        Box(modifier = Modifier.clearAndSetSemantics { }.padding(top = Tema.aire.e1)) {
            icono(color, Modifier.size(Tema.aire.e14))
        }
        Text(text = texto, style = estilo ?: Tema.texto.nota, color = color)
    }
}
