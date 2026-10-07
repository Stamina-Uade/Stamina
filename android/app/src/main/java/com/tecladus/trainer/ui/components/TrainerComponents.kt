package com.tecladus.trainer.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.animateIntAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.tecladus.trainer.R

/** Mapeo explícito de nombre lógico a recurso, para no depender de getIdentifier(). */
object TrainerIcons {
    fun res(name: String): Int = when (name) {
        "ic_home" -> R.drawable.ic_home
        "ic_calendar" -> R.drawable.ic_calendar
        "ic_run" -> R.drawable.ic_run
        "ic_bike" -> R.drawable.ic_bike
        "ic_swim" -> R.drawable.ic_swim
        "ic_mountain" -> R.drawable.ic_mountain
        "ic_food" -> R.drawable.ic_food
        "ic_profile" -> R.drawable.ic_profile
        "ic_water" -> R.drawable.ic_water
        "ic_salt" -> R.drawable.ic_salt
        "ic_gel" -> R.drawable.ic_gel
        "ic_play" -> R.drawable.ic_play
        "ic_pause" -> R.drawable.ic_pause
        "ic_stop" -> R.drawable.ic_stop
        "ic_check" -> R.drawable.ic_check
        "ic_back" -> R.drawable.ic_back
        "ic_add" -> R.drawable.ic_add
        "ic_search" -> R.drawable.ic_search
        "ic_chart" -> R.drawable.ic_chart
        "ic_settings" -> R.drawable.ic_settings
        "ic_notification" -> R.drawable.ic_notification
        "ic_edit" -> R.drawable.ic_edit
        "ic_flag" -> R.drawable.ic_flag
        "ic_trending" -> R.drawable.ic_trending
        "ic_heart" -> R.drawable.ic_heart
        "ic_close" -> R.drawable.ic_close
        "ic_chevron_right" -> R.drawable.ic_chevron_right
        "ic_timer" -> R.drawable.ic_timer
        else -> R.drawable.ic_heart
    }
}

@Composable
fun TrainerIcon(
    resName: String,
    modifier: Modifier = Modifier,
    tint: Color = MaterialTheme.colorScheme.onSurface,
    size: Int = 20
) {
    Icon(
        painter = painterResource(id = TrainerIcons.res(resName)),
        contentDescription = null,
        tint = tint,
        modifier = modifier.size(size.dp)
    )
}

/**
 * Tarjeta base: sin bordes. La jerarquía la da el tono de la superficie, y [accent]
 * la tiñe apenas cuando el bloque pertenece a un dominio (hidratación, nutrición).
 */
@Composable
fun TrainerCard(
    modifier: Modifier = Modifier,
    contentPadding: PaddingValues = PaddingValues(18.dp),
    accent: Color? = null,
    onClick: (() -> Unit)? = null,
    /** Color de fondo propio: se usa para las tarjetas que flotan sobre el mapa. */
    containerColor: Color = MaterialTheme.colorScheme.surface,
    content: @Composable ColumnScope.() -> Unit
) {
    val shape = RoundedCornerShape(22.dp)
    var base = modifier.fillMaxWidth().clip(shape)
    if (onClick != null) base = base.clickable { onClick() }
    Surface(
        modifier = base,
        shape = shape,
        color = containerColor
    ) {
        Box(modifier = Modifier.background(accent?.copy(alpha = 0.10f) ?: Color.Transparent)) {
            Column(modifier = Modifier.padding(contentPadding), content = content)
        }
    }
}

/** Etiqueta de sección: versalitas chicas en gris. Como máximo dos por pantalla. */
@Composable
fun SectionTitle(text: String, modifier: Modifier = Modifier, action: (@Composable () -> Unit)? = null) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = text.uppercase(),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        action?.invoke()
    }
}

@Composable
fun StatTile(
    label: String,
    value: String,
    unit: String = "",
    modifier: Modifier = Modifier,
    color: Color = MaterialTheme.colorScheme.onSurface
) {
    Column(modifier = modifier) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                text = value,
                style = MaterialTheme.typography.headlineSmall,
                color = color,
                fontWeight = FontWeight.Bold
            )
            if (unit.isNotEmpty()) {
                Spacer(Modifier.width(3.dp))
                Text(
                    text = unit,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(bottom = 3.dp)
                )
            }
        }
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

/** Anillo de progreso dibujado con Canvas (sin dependencias externas). */
@Composable
fun ProgressRing(
    progress: Float,
    modifier: Modifier = Modifier,
    color: Color = MaterialTheme.colorScheme.primary,
    trackColor: Color = MaterialTheme.colorScheme.surfaceVariant,
    strokeWidth: Float = 22f,
    animated: Boolean = true,
    centerContent: @Composable () -> Unit = {}
) {
    // El anillo se llena solo al entrar a la pantalla: da lectura del progreso sin distraer.
    val target = progress.coerceIn(0f, 1f)
    val animatedProgress by animateFloatAsState(
        targetValue = target,
        animationSpec = tween(durationMillis = if (animated) 750 else 0, easing = FastOutSlowInEasing),
        label = "ring"
    )
    Box(modifier = modifier, contentAlignment = Alignment.Center) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val stroke = Stroke(width = strokeWidth, cap = StrokeCap.Round)
            val inset = strokeWidth / 2f
            val arcSize = Size(size.width - strokeWidth, size.height - strokeWidth)
            drawArc(
                color = trackColor,
                startAngle = 135f,
                sweepAngle = 270f,
                useCenter = false,
                topLeft = Offset(inset, inset),
                size = arcSize,
                style = stroke
            )
            drawArc(
                color = color,
                startAngle = 135f,
                sweepAngle = 270f * animatedProgress,
                useCenter = false,
                topLeft = Offset(inset, inset),
                size = arcSize,
                style = stroke
            )
        }
        centerContent()
    }
}

/** Barra de progreso lineal propia. */
@Composable
fun ProgressBarLine(
    progress: Float,
    modifier: Modifier = Modifier,
    color: Color = MaterialTheme.colorScheme.primary,
    trackColor: Color = MaterialTheme.colorScheme.surfaceVariant,
    heightDp: Int = 10,
    animated: Boolean = true
) {
    val target = progress.coerceIn(0f, 1f)
    val animatedProgress by animateFloatAsState(
        targetValue = target,
        animationSpec = tween(durationMillis = if (animated) 600 else 0, easing = FastOutSlowInEasing),
        label = "bar"
    )
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(heightDp.dp)
            .clip(RoundedCornerShape(50))
            .background(trackColor)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth(animatedProgress)
                .fillMaxHeight()
                .clip(RoundedCornerShape(50))
                .background(color)
        )
    }
}

@Composable
fun MacroRow(
    label: String,
    consumed: Double,
    target: Int,
    unit: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(label, style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold)
            Text(
                "${consumed.toInt()} / $target $unit",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        Spacer(Modifier.height(6.dp))
        ProgressBarLine(
            progress = if (target > 0) (consumed / target).toFloat() else 0f,
            color = color
        )
    }
}

/** Chip seleccionable propio (sin APIs experimentales de Material 3). */
@Composable
fun SelectableChip(
    text: String,
    selected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    val bg by animateColorAsState(
        targetValue = if (selected) MaterialTheme.colorScheme.primary
        else MaterialTheme.colorScheme.surfaceVariant,
        animationSpec = tween(220),
        label = "chipBg"
    )
    val fg by animateColorAsState(
        targetValue = if (selected) MaterialTheme.colorScheme.onPrimary
        else MaterialTheme.colorScheme.onSurfaceVariant,
        animationSpec = tween(220),
        label = "chipFg"
    )
    val scale by animateFloatAsState(
        targetValue = if (selected) 1.03f else 1f,
        animationSpec = tween(220, easing = FastOutSlowInEasing),
        label = "chipScale"
    )
    Box(
        modifier = modifier
            .scale(scale)
            .clip(RoundedCornerShape(50))
            .background(bg)
            .clickable { onClick() }
            .padding(horizontal = 14.dp, vertical = 9.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.labelLarge,
            color = fg,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
fun Pill(text: String, color: Color, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(50))
            .background(color.copy(alpha = 0.16f))
            .padding(horizontal = 10.dp, vertical = 4.dp)
    ) {
        Text(text = text, style = MaterialTheme.typography.labelSmall, color = color, fontSize = 11.sp)
    }
}

@Composable
fun EmptyState(title: String, message: String, iconRes: String = "ic_chart", modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .size(64.dp)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.surfaceVariant),
            contentAlignment = Alignment.Center
        ) {
            TrainerIcon(iconRes, tint = MaterialTheme.colorScheme.onSurfaceVariant, size = 28)
        }
        Spacer(Modifier.height(14.dp))
        Text(title, style = MaterialTheme.typography.titleMedium, textAlign = TextAlign.Center)
        Spacer(Modifier.height(6.dp))
        Text(
            message,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
fun ScreenHeader(
    title: String,
    subtitle: String? = null,
    onBack: (() -> Unit)? = null,
    trailing: (@Composable () -> Unit)? = null
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (onBack != null) {
            Box(
                modifier = Modifier
                    .size(38.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.surfaceVariant)
                    .clickable { onBack() },
                contentAlignment = Alignment.Center
            ) {
                TrainerIcon("ic_back", tint = MaterialTheme.colorScheme.onSurface, size = 18)
            }
            Spacer(Modifier.width(12.dp))
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.headlineSmall)
            if (subtitle != null) {
                Text(
                    subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        trailing?.invoke()
    }
}

/** Número que transiciona al cambiar, para que el usuario vea el efecto de lo que registró. */
@Composable
fun AnimatedNumber(
    value: Int,
    modifier: Modifier = Modifier,
    style: androidx.compose.ui.text.TextStyle = MaterialTheme.typography.titleLarge,
    color: Color = MaterialTheme.colorScheme.onSurface,
    suffix: String = ""
) {
    val animated by animateIntAsState(
        targetValue = value,
        animationSpec = tween(durationMillis = 550, easing = FastOutSlowInEasing),
        label = "number"
    )
    Text(text = "$animated$suffix", style = style, color = color, modifier = modifier)
}

/** Punto con pulso suave: indica que la sesión se está grabando. */
@Composable
fun PulsingDot(
    color: Color,
    modifier: Modifier = Modifier,
    size: Int = 10,
    active: Boolean = true
) {
    val transition = rememberInfiniteTransition(label = "pulse")
    val alpha by transition.animateFloat(
        initialValue = 1f,
        targetValue = 0.25f,
        animationSpec = infiniteRepeatable(
            animation = tween(900, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulseAlpha"
    )
    Box(
        modifier = modifier
            .size(size.dp)
            .alpha(if (active) alpha else 1f)
            .clip(CircleShape)
            .background(color)
    )
}

/** Línea de 1 dp: separa filas de una lista sin encerrarlas en tarjetas. */
@Composable
fun HairLine(modifier: Modifier = Modifier, color: Color = MaterialTheme.colorScheme.outlineVariant) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(color)
    )
}

/** Métrica grande con su etiqueta debajo, para las filas de números de la sesión. */
@Composable
fun MetricBlock(
    value: String,
    label: String,
    modifier: Modifier = Modifier,
    color: Color = MaterialTheme.colorScheme.onSurface
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = value,
            style = MaterialTheme.typography.headlineSmall,
            color = color,
            fontWeight = FontWeight.Bold
        )
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}
