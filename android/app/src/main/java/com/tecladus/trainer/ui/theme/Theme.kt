package com.tecladus.trainer.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable

/**
 * La app es oscura siempre: se entrena de madrugada y de noche, y el contraste alto
 * sobre fondo casi negro es lo que mejor se lee al sol y lo que menos batería consume.
 */
private val TrainerColors = darkColorScheme(
    primary = Effort,
    onPrimary = EffortInk,
    primaryContainer = Surface2,
    onPrimaryContainer = TextHigh,
    secondary = Hydration,
    onSecondary = HydrationInk,
    secondaryContainer = HydrationSurface,
    onSecondaryContainer = HydrationSoft,
    tertiary = Nutrition,
    onTertiary = NutritionInk,
    tertiaryContainer = Surface2,
    onTertiaryContainer = TextHigh,
    background = Base,
    onBackground = TextHigh,
    surface = Surface1,
    onSurface = TextHigh,
    surfaceVariant = Surface3,
    onSurfaceVariant = TextLow,
    outline = Line,
    outlineVariant = LineSoft,
    error = Destructive,
    onError = EffortInk,
    errorContainer = DestructiveSurface,
    onErrorContainer = Destructive,
    inverseSurface = InverseSurface,
    inverseOnSurface = InverseText
)

@Composable
fun TrainerTheme(
    darkTheme: Boolean = true,
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = TrainerColors,
        typography = TrainerTypography,
        content = content
    )
}
