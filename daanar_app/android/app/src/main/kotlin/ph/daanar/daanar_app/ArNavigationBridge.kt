package ph.daanar.daanar_app

/** In-process handoff avoids putting long polylines in Android Binder intents. */
object ArNavigationBridge {
    var launchData: Map<*, *>? = null
    var requestWalkingRoute: ((Double, Double, (Map<*, *>?, String?) -> Unit) -> Unit)? = null
}
