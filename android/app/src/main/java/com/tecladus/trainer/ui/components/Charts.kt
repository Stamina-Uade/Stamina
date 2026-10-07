package com.tecladus.trainer.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.tecladus.trainer.core.Formatters
import com.tecladus.trainer.domain.model.Split

/** Barras verticales para la carga semanal o el volumen de las últimas semanas. */
@Composable
fun BarChart(
    values: List<Double>,
    labels: List<String>,
    modifier: Modifier = Modifier,
    barColor: Color = MaterialTheme.colorScheme.primary,
    highlightLast: Boolean = true
) {
    val max = (values.maxOrNull() ?: 0.0).coerceAtLeast(1.0)
    Column(modifier = modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(110.dp),
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            values.forEachIndexed { index, value ->
                val fraction = (value / max).toFloat().coerceIn(0.02f, 1f)
                val color = if (highlightLast && index == values.lastIndex) barColor
                else barColor.copy(alpha = 0.45f)
                Column(
                    modifier = Modifier.weight(1f),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height((100 * fraction).dp)
                            .clip(RoundedCornerShape(topStart = 8.dp, topEnd = 8.dp))
                            .background(color)
                    )
                }
            }
        }
        Spacer(Modifier.height(6.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            labels.forEach { label ->
                Text(
                    text = label,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.weight(1f),
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center
                )
            }
        }
    }
}

/** Lista de parciales por kilómetro con barra proporcional al ritmo. */
@Composable
fun SplitsList(splits: List<Split>, modifier: Modifier = Modifier) {
    if (splits.isEmpty()) return
    val fastest = splits.minOf { it.paceSecPerKm }.coerceAtLeast(1)
    val slowest = splits.maxOf { it.paceSecPerKm }.coerceAtLeast(fastest + 1)
    Column(modifier = modifier.fillMaxWidth()) {
        splits.forEach { split ->
            val fraction = 1f - ((split.paceSecPerKm - fastest).toFloat() / (slowest - fastest).toFloat())
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 5.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "${split.index}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.width(22.dp)
                )
                Box(modifier = Modifier.weight(1f)) {
                    ProgressBarLine(
                        progress = 0.25f + 0.75f * fraction.coerceIn(0f, 1f),
                        heightDp = 14
                    )
                }
                Spacer(Modifier.width(10.dp))
                Text(
                    text = Formatters.pace(split.paceSecPerKm),
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.width(52.dp),
                    textAlign = androidx.compose.ui.text.style.TextAlign.End
                )
            }
        }
    }
}
