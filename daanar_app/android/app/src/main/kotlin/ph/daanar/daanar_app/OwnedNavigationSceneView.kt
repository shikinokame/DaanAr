package ph.daanar.daanar_app

import android.content.Context
import androidx.lifecycle.Lifecycle
import io.github.sceneview.ar.ARSceneView

/** SceneView may destroy itself BEFORE Activity.onDestroy, including on window detach. */
class OwnedNavigationSceneView(
    context: Context,
    sceneLifecycle: Lifecycle,
    private val releaseOwnedNodes: () -> Unit
) : ARSceneView(context, sharedLifecycle = sceneLifecycle) {
    private val teardown = SceneTeardown()
    val acceptsUpdates: Boolean get() = teardown.acceptsUpdates

    override fun destroy() {
        teardown.close(
            releaseResources = releaseOwnedNodes,
            destroyEngine = { super.destroy() }
        )
    }
}
