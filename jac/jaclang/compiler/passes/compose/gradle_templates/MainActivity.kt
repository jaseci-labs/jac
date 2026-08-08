package {{package_name}}

import android.content.Intent
import android.content.res.Configuration
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.luminance
import androidx.compose.material3.MaterialTheme
import androidx.core.view.WindowCompat

class MainActivity : ComponentActivity() {
    private var incomingPath by mutableStateOf(JacRoutes.initialPath)
    private var incomingFragment by mutableStateOf<String?>(null)
    private var incomingRequest by mutableStateOf(0)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        restoreThemePreference()
        applyIntentRoute(intent)
        setContent {
            val useDarkSystemBarIcons = JacDesign.background.luminance() > 0.179f
            SideEffect {
                WindowCompat.getInsetsController(window, window.decorView).apply {
                    isAppearanceLightStatusBars = useDarkSystemBarIcons
                    isAppearanceLightNavigationBars = useDarkSystemBarIcons
                }
            }
            MaterialTheme {
                JacApp(incomingPath, incomingFragment, incomingRequest)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        applyIntentRoute(intent)
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
    }

    private fun restoreThemePreference() {
        val storedTheme = getSharedPreferences("jac", MODE_PRIVATE)
            .getString("theme-preference", JacThemeModule.defaultTheme)
            ?: JacThemeModule.defaultTheme
        JacDesign.applyTheme(storedTheme)
    }

    private fun applyIntentRoute(intent: Intent?) {
        val path = intent?.data?.path?.takeIf { JacRoutes.paths.contains(it) } ?: JacRoutes.initialPath
        incomingPath = path
        incomingFragment = intent?.data?.fragment?.takeIf { JacRoutes.sections[path]?.contains(it) == true }
        incomingRequest += 1
    }
}
