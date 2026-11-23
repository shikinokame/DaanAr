package ph.daanar.daanar_app

import kotlin.math.*

data class GeoPoint(val latitude: Double, val longitude: Double) {
    init {
        require(latitude.isFinite() && longitude.isFinite() && latitude in -90.0..90.0 && longitude in -180.0..180.0)
    }

    fun offsetFrom(origin: GeoPoint): GroundPoint = GroundPoint(
        (longitude - origin.longitude) * 111195.0 * cos(Math.toRadians(origin.latitude)),
        (latitude - origin.latitude) * 111195.0
    )
}

data class GroundPoint(val east: Double, val north: Double) {
    fun distance(other: GroundPoint) = hypot(east - other.east, north - other.north)
}

data class RouteProjection(val along: Double, val deviation: Double)
data class RouteArrow(val id: Int, val along: Double, val point: GeoPoint, val bearing: Double)

/** Geographic geometry only: no Android, camera, network or rendering dependencies. */
class WalkingRouteGeometry(val points: List<GeoPoint>) {
    init { require(points.size in 2..30000) }
    private val origin = points.first()
    private val local = points.map { it.offsetFrom(origin) }
    val offsets = DoubleArray(points.size)
    init {
        for (i in 1 until points.size) offsets[i] = offsets[i - 1] + local[i - 1].distance(local[i])
        require(length > 0.5 && length.isFinite())
    }
    val length: Double get() = offsets.last()

    fun project(point: GeoPoint, previousAlong: Double? = null): RouteProjection {
        val p = point.offsetFrom(origin)
        var best = RouteProjection(0.0, Double.POSITIVE_INFINITY)
        var score = Double.POSITIVE_INFINITY
        for (i in 0 until local.lastIndex) {
            val a = local[i]
            val b = local[i + 1]
            val dx = b.east - a.east
            val dy = b.north - a.north
            val square = dx * dx + dy * dy
            val t = if (square == 0.0) 0.0 else (((p.east - a.east) * dx + (p.north - a.north) * dy) / square).coerceIn(0.0, 1.0)
            val deviation = p.distance(GroundPoint(a.east + t * dx, a.north + t * dy))
            val along = offsets[i] + (offsets[i + 1] - offsets[i]) * t
            val continuity = previousAlong?.let { min(8.0, abs(along - it) * 0.02) } ?: 0.0
            if (deviation + continuity < score) {
                score = deviation + continuity
                best = RouteProjection(along, deviation)
            }
        }
        return best
    }

    fun pointAt(along: Double): GeoPoint {
        val target = along.coerceIn(0.0, length)
        val index = offsets.indexOfFirst { it >= target }.coerceAtLeast(1)
        val span = offsets[index] - offsets[index - 1]
        val t = if (span == 0.0) 0.0 else (target - offsets[index - 1]) / span
        val a = points[index - 1]
        val b = points[index]
        return GeoPoint(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t)
    }

    fun bearingAt(along: Double): Double {
        val target = along.coerceIn(0.0, length)
        val segmentEnd = offsets.indexOfFirst { it > target }.takeIf { it > 0 }
            ?: (offsets.lastIndex downTo 1).first { offsets[it] > offsets[it - 1] }
        val delta = points[segmentEnd].offsetFrom(points[segmentEnd - 1])
        return atan2(delta.east, delta.north)
    }

    /** Stable IDs at fixed route offsets; GPS updates never shift existing markers. */
    fun arrows(nearAlong: Double, ahead: Double = 30.0, spacing: Double = 5.0): List<RouteArrow> {
        val leadOffset = if (spacing < 4.5) 0.8 else -3.0
        val first = max(1, floor((nearAlong + leadOffset) / spacing).toInt())
        return (first..first + 8).mapNotNull { id ->
            val along = id * spacing
            if (along > length - 1.0 || along > nearAlong + ahead) return@mapNotNull null
            val p = pointAt(along)
            RouteArrow(id, along, p, Math.toDegrees(bearingAt(along)))
        }
    }
}

/** Single-tap / instant alignment using the tapped ground point and camera forward direction. */
fun alignSingleTapToPath(
    route: WalkingRouteGeometry,
    gps: RouteProjection,
    camera: Pair<Double, Double>,
    target: Pair<Double, Double>,
    fallbackForward: Pair<Double, Double>
): GroundAlignment {
    var dx = target.first - camera.first
    var dz = target.second - camera.second
    val dist = hypot(dx, dz)
    if (dist < 0.4) {
        dx = fallbackForward.first
        dz = fallbackForward.second
    }
    val along = gps.along.coerceIn(0.0, max(0.0, route.length - 0.5))
    val startPoint = route.pointAt(along)
    val lookAhead = (along + 4.0).coerceAtMost(route.length)
    val delta = route.pointAt(lookAhead).offsetFrom(startPoint)
    val routeBearing = if (delta.distance(GroundPoint(0.0, 0.0)) > 0.2) {
        atan2(delta.east, delta.north)
    } else {
        route.bearingAt(along)
    }
    val worldX = camera.first + (target.first - camera.first) * 0.35
    val worldZ = camera.second + (target.second - camera.second) * 0.35
    return GroundAlignment(startPoint, worldX, worldZ, atan2(dx, -dz) - routeBearing)
}

/** Match two points on the real path to the current straight section of the route. */
fun alignToPath(
    route: WalkingRouteGeometry,
    gps: RouteProjection,
    camera: Pair<Double, Double>,
    near: Pair<Double, Double>,
    far: Pair<Double, Double>
): GroundAlignment? {
    val dx = far.first - near.first
    val dz = far.second - near.second
    val span = hypot(dx, dz)
    if (span !in 1.5..7.0) return null
    val cameraToNearX = near.first - camera.first
    val cameraToNearZ = near.second - camera.second
    if (hypot(cameraToNearX, cameraToNearZ) > 3.0) return null
    val offset = (cameraToNearX * dx + cameraToNearZ * dz) / span
    if (offset < -.5) return null
    val along = (gps.along + offset).coerceAtLeast(0.0)
    val end = along + span
    if (end > route.length) return null
    val startPoint = route.pointAt(along)
    val delta = route.pointAt(end).offsetFrom(startPoint)
    val routeBearing = atan2(delta.east, delta.north)
    // A tap across a corner would rotate both street segments away from the path.
    if (delta.distance(GroundPoint(0.0, 0.0)) < span * .95) return null
    for (index in 0..4) {
        val angle = route.bearingAt(along + span * index / 5.0) - routeBearing
        if (abs(atan2(sin(angle), cos(angle))) > Math.toRadians(20.0)) return null
    }
    return GroundAlignment(startPoint, near.first, near.second, atan2(dx, -dz) - routeBearing)
}

/** The geographic-to-AR alignment is frozen until the user explicitly realigns. */
class GroundAlignment(
    val origin: GeoPoint,
    val worldX: Double,
    val worldZ: Double,
    val yawRadians: Double
) {
    fun world(point: GeoPoint): Pair<Double, Double> {
        val p = point.offsetFrom(origin)
        return Pair(worldX + p.east * cos(yawRadians) + p.north * sin(yawRadians),
            worldZ + p.east * sin(yawRadians) - p.north * cos(yawRadians))
    }

    fun geographic(x: Double, z: Double): GeoPoint {
        val dx = x - worldX
        val dz = z - worldZ
        val east = dx * cos(yawRadians) + dz * sin(yawRadians)
        val north = dx * sin(yawRadians) - dz * cos(yawRadians)
        return GeoPoint(origin.latitude + north / 111195.0,
            origin.longitude + east / (111195.0 * cos(Math.toRadians(origin.latitude))))
    }
}

/** Retire after sustained visual progress, never from a single noisy GPS fix. */
class PassedArrowGate {
    private val candidates = mutableMapOf<Int, Long>()
    private val retired = mutableSetOf<Int>()
    fun isRetired(id: Int) = id in retired
    fun pause() = candidates.clear()
    fun update(arrows: List<RouteArrow>, progress: RouteProjection, nowMs: Long) {
        candidates.keys.removeAll { id -> arrows.none { it.id == id } }
        arrows.forEach { arrow ->
            if (arrow.id in retired) return@forEach
            if (progress.deviation <= 3.0 && progress.along >= arrow.along + 1.5) {
                val since = candidates.getOrPut(arrow.id) { nowMs }
                if (nowMs - since >= 700) {
                    retired += arrow.id
                    candidates.remove(arrow.id)
                }
            } else candidates.remove(arrow.id)
        }
    }
}
