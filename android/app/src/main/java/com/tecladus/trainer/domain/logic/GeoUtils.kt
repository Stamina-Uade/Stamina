package com.tecladus.trainer.domain.logic

import com.tecladus.trainer.domain.model.Split
import com.tecladus.trainer.domain.model.TrackPoint
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

/** Utilidades geográficas para el tracking: distancia, desnivel y parciales. */
object GeoUtils {

    private const val EARTH_RADIUS_M = 6_371_000.0

    /** Distancia en metros entre dos coordenadas (fórmula de Haversine). */
    fun distanceMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val dLat = Math.toRadians(lat2 - lat1)
        val dLon = Math.toRadians(lon2 - lon1)
        val a = sin(dLat / 2) * sin(dLat / 2) +
            cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2)
        val c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return EARTH_RADIUS_M * c
    }

    fun distanceMeters(a: TrackPoint, b: TrackPoint): Double =
        distanceMeters(a.latitude, a.longitude, b.latitude, b.longitude)

    fun totalDistanceMeters(points: List<TrackPoint>): Double {
        var total = 0.0
        for (i in 1 until points.size) total += distanceMeters(points[i - 1], points[i])
        return total
    }

    /**
     * Desnivel positivo acumulado. Se ignoran variaciones menores a [thresholdM]
     * para filtrar el ruido del GPS barométrico.
     */
    fun elevationGain(points: List<TrackPoint>, thresholdM: Double = 3.0): Double {
        if (points.size < 2) return 0.0
        var gain = 0.0
        var reference = points.first().altitudeM
        for (p in points) {
            val diff = p.altitudeM - reference
            if (diff >= thresholdM) {
                gain += diff
                reference = p.altitudeM
            } else if (diff <= -thresholdM) {
                reference = p.altitudeM
            }
        }
        return gain
    }

    /** Parciales cada [splitMeters] metros a partir de la lista de puntos. */
    fun computeSplits(points: List<TrackPoint>, splitMeters: Double = 1000.0): List<Split> {
        if (points.size < 2) return emptyList()
        val splits = mutableListOf<Split>()
        var accumulated = 0.0
        var splitStartTime = points.first().timestampMs
        var splitStartAlt = points.first().altitudeM
        var minAlt = splitStartAlt
        var index = 1
        for (i in 1 until points.size) {
            accumulated += distanceMeters(points[i - 1], points[i])
            minAlt = min(minAlt, points[i].altitudeM)
            if (accumulated >= splitMeters) {
                val durationSec = ((points[i].timestampMs - splitStartTime) / 1000L).toInt()
                splits += Split(
                    index = index,
                    distanceM = accumulated,
                    durationSec = durationSec,
                    elevationGainM = max(0.0, points[i].altitudeM - splitStartAlt)
                )
                index++
                accumulated = 0.0
                splitStartTime = points[i].timestampMs
                splitStartAlt = points[i].altitudeM
            }
        }
        if (accumulated > 50) {
            val last = points.last()
            splits += Split(
                index = index,
                distanceM = accumulated,
                durationSec = ((last.timestampMs - splitStartTime) / 1000L).toInt(),
                elevationGainM = max(0.0, last.altitudeM - splitStartAlt)
            )
        }
        return splits
    }

    /**
     * Normaliza el recorrido a coordenadas 0..1 conservando la relación de aspecto,
     * para dibujarlo en un Canvas sin depender de un SDK de mapas.
     */
    fun normalizeForCanvas(points: List<TrackPoint>): List<Pair<Float, Float>> {
        if (points.isEmpty()) return emptyList()
        val lats = points.map { it.latitude }
        val lons = points.map { it.longitude }
        val minLat = lats.min()
        val maxLat = lats.max()
        val minLon = lons.min()
        val maxLon = lons.max()
        val midLat = (minLat + maxLat) / 2.0
        // Corrección de la longitud por la latitud (proyección equirectangular simple).
        val lonScale = cos(Math.toRadians(midLat))
        val width = (maxLon - minLon) * lonScale
        val height = maxLat - minLat
        val span = max(max(width, height), 1e-6)
        val offsetX = (span - width) / 2.0
        val offsetY = (span - height) / 2.0
        return points.map { p ->
            val x = ((p.longitude - minLon) * lonScale + offsetX) / span
            // El eje Y del canvas crece hacia abajo, por eso se invierte.
            val y = 1.0 - ((p.latitude - minLat) + offsetY) / span
            x.toFloat() to y.toFloat()
        }
    }

    /** Descarta puntos con mala precisión o saltos imposibles (teletransportes del GPS). */
    fun isPlausible(previous: TrackPoint?, candidate: TrackPoint, maxSpeedMps: Double = 12.0): Boolean {
        if (candidate.accuracyM > 35f) return false
        if (previous == null) return true
        val dt = (candidate.timestampMs - previous.timestampMs) / 1000.0
        if (dt <= 0) return false
        val d = distanceMeters(previous, candidate)
        if (d < 1.0) return false
        return d / dt <= maxSpeedMps
    }
}
