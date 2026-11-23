package ph.daanar.daanar_app

import org.junit.Assert.*
import org.junit.Test
import kotlin.math.PI

class WalkingRouteGeometryTest {
    private val start = GeoPoint(16.0, 120.0)
    private fun north(metres: Double) = GeoPoint(16.0 + metres / 111195.0, 120.0)
    private fun route() = WalkingRouteGeometry(listOf(start, north(20.0), north(50.0)))

    @Test fun arrowsFollowDistanceInsteadOfVertexDensity() {
        val arrows = route().arrows(0.0)
        assertEquals(listOf(5.0, 10.0, 15.0, 20.0, 25.0, 30.0), arrows.map { it.along })
        assertEquals(5.0, arrows.first().point.offsetFrom(start).north, .01)
        assertEquals(0.0, arrows.first().bearing, .01)
    }

    @Test fun cornersArePreservedAndArrowTurnsAfterCorner() {
        val corner = north(10.0)
        val end = GeoPoint(corner.latitude, 120.0002)
        val r = WalkingRouteGeometry(listOf(start, corner, end))
        assertEquals(120.0, r.pointAt(8.0).longitude, 1e-8)
        assertEquals(corner.latitude, r.pointAt(15.0).latitude, 1e-8)
        assertEquals(90.0, r.arrows(0.0).first { it.along == 15.0 }.bearing, .1)
    }

    @Test fun arrowImmediatelyBeforeCornerStillPointsAlongTheCurrentSegment() {
        val corner = north(5.5)
        val r = WalkingRouteGeometry(listOf(start, corner, GeoPoint(corner.latitude, 120.0002)))
        assertEquals(0.0, r.arrows(0.0).first().bearing, .01)
        assertEquals(90.0, r.arrows(0.0)[1].bearing, .01)
    }

    @Test fun twoPathTapsCorrectBothHeadingAndSidewaysOffset() {
        val alignment = requireNotNull(alignToPath(
            route(), RouteProjection(10.0, 2.0), 3.0 to 5.0, 4.0 to 6.0, 8.0 to 6.0
        ))
        val onPath = alignment.world(north(15.0))
        assertEquals(8.0, onPath.first, .01)
        assertEquals(6.0, onPath.second, .01)
    }

    @Test fun alignmentRejectsTapsAcrossATurnOrTooFarFromTheCamera() {
        val corner = north(5.5)
        val r = WalkingRouteGeometry(listOf(start, corner, GeoPoint(corner.latitude, 120.0002)))
        assertNull(alignToPath(r, RouteProjection(4.0, 0.0), 0.0 to 0.0, 0.0 to -1.0, 0.0 to -5.0))
        assertNull(alignToPath(route(), RouteProjection(4.0, 0.0), 0.0 to 0.0, 0.0 to -4.0, 0.0 to -8.0))
    }

    @Test fun projectionSupportsBacktrackingWithoutSkippingLoop() {
        val r = route()
        assertEquals(15.0, r.project(north(15.0), 10.0).along, .01)
        assertEquals(7.0, r.project(north(7.0), 15.0).along, .01)
        assertEquals(0.0, r.project(north(15.0)).deviation, .01)
    }

    @Test fun alignmentMapsNorthEastAndRoundTrips() {
        val map = GroundAlignment(start, 3.0, 8.0, 0.0)
        val p = map.world(north(10.0))
        assertEquals(3.0, p.first, .01)
        assertEquals(-2.0, p.second, .01)
        val g = map.geographic(p.first, p.second)
        assertEquals(north(10.0).latitude, g.latitude, 1e-9)
        val rotated = GroundAlignment(start, 0.0, 0.0, PI / 2).world(north(10.0))
        assertEquals(10.0, rotated.first, .01)
        assertEquals(0.0, rotated.second, .01)
    }

    @Test fun singleNoisyFixCannotRetireOrResurrectArrow() {
        val arrows = route().arrows(0.0)
        val gate = PassedArrowGate()
        gate.update(arrows, RouteProjection(7.0, 0.0), 1000)
        assertFalse(gate.isRetired(1))
        gate.update(arrows, RouteProjection(4.0, 0.0), 1300)
        gate.update(arrows, RouteProjection(7.0, 0.0), 1500)
        gate.update(arrows, RouteProjection(7.0, 0.0), 2200)
        assertTrue(gate.isRetired(1))
        gate.update(arrows, RouteProjection(4.0, 0.0), 3000)
        assertTrue(gate.isRetired(1))
    }

    @Test fun offRouteProgressDoesNotConsumeArrows() {
        val arrows = route().arrows(0.0)
        val gate = PassedArrowGate()
        gate.update(arrows, RouteProjection(15.0, 9.0), 1000)
        gate.update(arrows, RouteProjection(15.0, 9.0), 3000)
        assertFalse(gate.isRetired(1))
    }

    @Test fun lostTrackingOrLeavingTheWindowRestartsPassConfirmation() {
        val arrows = route().arrows(0.0)
        val past = RouteProjection(7.0, 0.0)
        val gate = PassedArrowGate()
        gate.update(arrows, past, 0)
        gate.pause()
        gate.update(arrows, past, 2200)
        assertFalse(gate.isRetired(1))
        gate.update(emptyList(), past, 2300)
        gate.update(arrows, past, 3100)
        assertFalse(gate.isRetired(1))
        gate.update(arrows, past, 3800)
        gate.pause()
        assertTrue(gate.isRetired(1))
    }

    @Test fun destinationDoesNotGenerateArrowsPastTheEnd() {
        assertTrue(route().arrows(49.0).all { it.along < route().length })
        assertTrue(route().arrows(55.0).isEmpty())
    }

    @Test(expected = IllegalArgumentException::class) fun malformedCoordinatesAreRejected() {
        GeoPoint(Double.NaN, 120.0)
    }

    @Test(expected = IllegalArgumentException::class) fun zeroLengthRouteIsRejected() {
        WalkingRouteGeometry(listOf(start, start))
    }
}
