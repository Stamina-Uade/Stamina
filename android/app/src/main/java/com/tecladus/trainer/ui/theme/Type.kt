package com.tecladus.trainer.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

private val base = Typography()

/**
 * Escala tipográfica del sistema: pocos tamaños, bien separados.
 *
 * Los números mandan (headline / display, con interletrado negativo) y el texto de
 * apoyo baja a 13 sp en gris. Las etiquetas de sección son 10,5 sp en versalitas:
 * ese es el piso de tamaño de toda la app.
 */
val TrainerTypography = Typography(
    displaySmall = base.displaySmall.copy(
        fontWeight = FontWeight.Bold,
        fontSize = 34.sp,
        letterSpacing = (-1).sp
    ),
    headlineMedium = base.headlineMedium.copy(
        fontWeight = FontWeight.Bold,
        fontSize = 26.sp,
        letterSpacing = (-0.6).sp
    ),
    headlineSmall = base.headlineSmall.copy(
        fontWeight = FontWeight.Bold,
        fontSize = 21.sp,
        letterSpacing = (-0.4).sp
    ),
    titleLarge = base.titleLarge.copy(fontWeight = FontWeight.Bold, fontSize = 19.sp),
    titleMedium = base.titleMedium.copy(fontWeight = FontWeight.SemiBold, fontSize = 15.sp),
    bodyMedium = base.bodyMedium.copy(fontSize = 14.sp),
    bodySmall = base.bodySmall.copy(fontSize = 13.sp, lineHeight = 19.sp),
    labelLarge = base.labelLarge.copy(fontWeight = FontWeight.SemiBold, fontSize = 13.sp),
    labelMedium = base.labelMedium.copy(fontWeight = FontWeight.SemiBold, fontSize = 11.sp),
    labelSmall = base.labelSmall.copy(
        fontWeight = FontWeight.SemiBold,
        fontSize = 10.5.sp,
        letterSpacing = 0.9.sp
    )
)

/** Cronómetro y métricas grandes de la sesión en vivo. */
val MetricNumberStyle = TextStyle(
    fontFamily = FontFamily.Default,
    fontWeight = FontWeight.Bold,
    fontSize = 56.sp,
    letterSpacing = (-2).sp
)
