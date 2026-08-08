package {{package_name}}

import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.SideEffect

// Hot-swap entry point. In dev, JacDevHostActivity DexClassLoader-loads this
// class from a freshly compiled classes.dex and reflectively calls mount().
// In release, MainActivity could call the same method directly. Either way the
// composable tree is defined once, here.
//
// The SideEffect logs a render marker only after the Compose tree above
// composes without throwing, so the on-device e2e can assert a successful
// render from logcat instead of the accessibility service (which ANRs under
// the headless CI emulator). A compose-time crash leaves the marker absent.
object JacDevEntry {
    @JvmStatic
    fun mount(activity: ComponentActivity) {
        activity.setContent {
            MaterialTheme {
                JacApp(JacRoutes.initialPath, null, 0)
            }
            SideEffect { Log.i(TAG, RENDER_MARKER) }
        }
    }

    private const val TAG = "JacHmr"
    private const val RENDER_MARKER = "JAC_COMPOSE_RENDERED"
}
