package ph.daanar.daanar_app

import org.junit.Assert.*
import org.junit.Test

class SceneTeardownTest {
    @Test fun meshesAndAnchorsAreReleasedWhileEngineIsAlive() {
        var engineAlive = true
        val events = mutableListOf<String>()
        val owner = SceneTeardown()
        owner.close(
            releaseResources = {
                check(engineAlive) { "Native use-after-free" }
                assertFalse(owner.acceptsUpdates)
                events += "anchors"
                events += "meshes"
            },
            destroyEngine = { engineAlive = false; events += "engine" }
        )
        assertEquals(listOf("anchors", "meshes", "engine"), events)
        assertFalse(engineAlive)
    }

    @Test fun lifecycleThenActivityThenWindowDetachCannotDestroyMeshesAgain() {
        val owner = SceneTeardown()
        var engineAlive = true
        var releases = 0
        var destroys = 0
        repeat(3) {
            owner.close(
                releaseResources = { check(engineAlive); releases++ },
                destroyEngine = { engineAlive = false; destroys++ }
            )
        }
        assertEquals(1, releases)
        assertEquals(1, destroys)
    }

    @Test fun reentrantDetachDuringCleanupCannotCloseEngineEarly() {
        val owner = SceneTeardown()
        val events = mutableListOf<String>()
        owner.close(
            releaseResources = {
                events += "release-start"
                owner.close({ fail("Duplicate mesh cleanup") }, { fail("Engine closed during mesh cleanup") })
                events += "release-end"
            },
            destroyEngine = { events += "engine" }
        )
        assertEquals(listOf("release-start", "release-end", "engine"), events)
    }

    @Test fun failedCleanupStillClosesEngineAndRejectsLateCallbacks() {
        val owner = SceneTeardown()
        var engineClosed = false
        try {
            owner.close({ throw IllegalStateException("Release failed") }, { engineClosed = true })
            fail("Expected cleanup failure")
        } catch (_: IllegalStateException) { }
        assertTrue(engineClosed)
        assertFalse(owner.acceptsUpdates)
        owner.close({ fail("Cleanup retried after engine closed") }, { fail("Engine closed twice") })
    }
}
