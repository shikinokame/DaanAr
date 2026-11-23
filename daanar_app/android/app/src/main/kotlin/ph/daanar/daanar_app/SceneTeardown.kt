package ph.daanar.daanar_app

/** One owner for lifecycle, window-detach and explicit close; GPU resources go first. */
class SceneTeardown {
    private var closing = false
    val acceptsUpdates: Boolean get() = !closing

    fun close(releaseResources: () -> Unit, destroyEngine: () -> Unit) {
        if (closing) return
        closing = true
        try {
            releaseResources()
        } finally {
            destroyEngine()
        }
    }
}
