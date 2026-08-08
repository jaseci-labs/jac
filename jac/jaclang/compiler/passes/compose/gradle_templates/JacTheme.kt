package {{package_name}}

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

data class JacGeneratedTheme(
    val name: String,
    val colors: Map<String, Color>,
    val radius: Dp
)

object JacThemeModule {
    const val generated = true
    const val defaultTheme = "light"
    val names = listOf(
        "light",
    )
    val themes = listOf(
        JacGeneratedTheme(name = "light", colors = mapOf(
{{colors}}
        ), radius = {{radius}}.dp),
    )
}
