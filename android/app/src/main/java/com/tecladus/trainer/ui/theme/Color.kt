package com.tecladus.trainer.ui.theme

import androidx.compose.ui.graphics.Color

/**
 * Paleta del sistema visual.
 *
 * Regla: cada color significa algo y sólo aparece donde eso pasa.
 *  - Naranja  -> esfuerzo y acción (el único botón lleno de cada pantalla)
 *  - Azul     -> hidratación (agua, sudor, sales)
 *  - Verde    -> nutrición y estado en orden
 *  - Ámbar    -> atención (déficit, riesgo de carga)
 *  - Rojo     -> destructivo (finalizar, borrar)
 * Todo lo secundario vive en gris; la jerarquía la da el tono, no los bordes.
 */
val Effort = Color(0xFFFF6B35)
val EffortSoft = Color(0xFFFF8A5C)
val EffortInk = Color(0xFF0B0E13)

val Hydration = Color(0xFF4EA1FF)
val HydrationSoft = Color(0xFF6FB5FF)
val HydrationSurface = Color(0xFF0F2033)
val HydrationSurfaceHigh = Color(0xFF14304C)
val HydrationInk = Color(0xFF06121F)

val Nutrition = Color(0xFF46C98B)
val NutritionInk = Color(0xFF06180F)

val Attention = Color(0xFFFFB020)
val Destructive = Color(0xFFFF6B6B)
val DestructiveSurface = Color(0xFF2A1215)

val Base = Color(0xFF0B0E13)
val Surface1 = Color(0xFF141A22)
val Surface2 = Color(0xFF171E28)
val Surface3 = Color(0xFF1B2530)
val Line = Color(0xFF232C38)
val LineSoft = Color(0xFF1A222C)
val NavSurface = Color(0xFF0E131A)

val TextHigh = Color(0xFFEEF2F6)
val TextMid = Color(0xFFC3CEDB)
val TextLow = Color(0xFF8B98A8)
val TextFaint = Color(0xFF5F6C7C)

val InverseSurface = Color(0xFFE7EDF4)
val InverseText = Color(0xFF10151D)
val White = Color(0xFFFFFFFF)
