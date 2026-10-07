package com.tecladus.trainer.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import java.time.LocalDate

/** Campo numérico con etiqueta y sufijo (kg, cm, años...). */
@Composable
fun NumberField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    suffix: String = "",
    decimal: Boolean = false
) {
    OutlinedTextField(
        value = value,
        onValueChange = { input ->
            val filtered = input.filter { it.isDigit() || (decimal && (it == '.' || it == ',')) }
                .replace(',', '.')
            onValueChange(filtered)
        },
        label = { Text(if (suffix.isEmpty()) label else "$label ($suffix)") },
        singleLine = true,
        keyboardOptions = KeyboardOptions(
            keyboardType = if (decimal) KeyboardType.Decimal else KeyboardType.Number
        ),
        modifier = modifier.fillMaxWidth()
    )
}

@Composable
fun TextField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        singleLine = true,
        modifier = modifier.fillMaxWidth()
    )
}

/** Selector de fecha simple con tres campos: evita APIs experimentales de Material 3. */
@Composable
fun DateInputRow(
    label: String,
    date: LocalDate?,
    onDateChange: (LocalDate?) -> Unit,
    modifier: Modifier = Modifier
) {
    var day by remember(date) { mutableStateOf(date?.dayOfMonth?.toString() ?: "") }
    var month by remember(date) { mutableStateOf(date?.monthValue?.toString() ?: "") }
    var year by remember(date) { mutableStateOf(date?.year?.toString() ?: "") }

    fun emit() {
        val d = day.toIntOrNull()
        val m = month.toIntOrNull()
        val y = year.toIntOrNull()
        if (d != null && m != null && y != null && d in 1..31 && m in 1..12 && y in 2020..2100) {
            onDateChange(runCatching { LocalDate.of(y, m, d) }.getOrNull())
        } else {
            onDateChange(null)
        }
    }

    Column(modifier = modifier.fillMaxWidth()) {
        Text(label, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(6.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            NumberField(
                label = "Día",
                value = day,
                onValueChange = { day = it.take(2); emit() },
                modifier = Modifier.weight(1f)
            )
            NumberField(
                label = "Mes",
                value = month,
                onValueChange = { month = it.take(2); emit() },
                modifier = Modifier.weight(1f)
            )
            NumberField(
                label = "Año",
                value = year,
                onValueChange = { year = it.take(4); emit() },
                modifier = Modifier.weight(1.3f)
            )
        }
    }
}

/** Slider con etiqueta y valor formateado. */
@Composable
fun LabeledSlider(
    label: String,
    value: Float,
    range: ClosedFloatingPointRange<Float>,
    onValueChange: (Float) -> Unit,
    modifier: Modifier = Modifier,
    steps: Int = 0,
    valueLabel: String = value.toInt().toString()
) {
    Column(modifier = modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(label, style = MaterialTheme.typography.bodyMedium)
            Text(
                valueLabel,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.primary
            )
        }
        Slider(
            value = value,
            onValueChange = onValueChange,
            valueRange = range,
            steps = steps
        )
    }
}

/**
 * Fila de opciones excluyentes con chips, agrupadas de a [perRow] por fila.
 * Se evita FlowRow para no depender de APIs experimentales de layout.
 */
@Composable
fun <T> ChipSelector(
    options: List<T>,
    selected: T,
    labelOf: (T) -> String,
    onSelect: (T) -> Unit,
    modifier: Modifier = Modifier,
    perRow: Int = 2
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        options.chunked(perRow).forEach { rowOptions ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                rowOptions.forEach { option ->
                    SelectableChip(
                        text = labelOf(option),
                        selected = option == selected,
                        onClick = { onSelect(option) },
                        modifier = Modifier.weight(1f)
                    )
                }
                repeat(perRow - rowOptions.size) {
                    Spacer(Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
fun FieldSpacer() {
    Spacer(Modifier.height(14.dp))
}

@Composable
fun HSpacer(width: Int) {
    Spacer(Modifier.width(width.dp))
}
