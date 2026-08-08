package {{package_name}}

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.FrameLayout
import android.widget.TextView
import androidx.activity.ComponentActivity
import dalvik.system.DexClassLoader
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONObject

// On-device HMR host. Polls the Jac dev server for a new module version every
// 300ms, downloads the merged classes.dex, and DexClassLoader-swaps it WITHOUT
// reinstalling the APK. The loaded module's JacDevEntry.mount(this) installs the
// composable tree via setContent. (Kotlin/Compose port of the reference's dev host Activity.)
class JacDevHostActivity : ComponentActivity() {
    private val handler = Handler(Looper.getMainLooper())
    private var endpoint: String = ""
    private var activeVersion: String = ""
    private var attemptedVersion: String = ""
    private var running: Boolean = true

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        endpoint = resolveEndpoint(intent)
        val loading = FrameLayout(this)
        val label = TextView(this)
        label.text = "Loading Jac module"
        loading.addView(label)
        setContentView(loading)
        restoreCachedModule()
        poll()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val resume = endpoint.isEmpty()
        endpoint = resolveEndpoint(intent)
        if (resume && endpoint.isNotEmpty()) {
            poll()
        }
    }

    override fun onDestroy() {
        running = false
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    private fun resolveEndpoint(launchIntent: Intent?): String {
        val value = launchIntent?.getStringExtra(EXTRA_SERVER)
        if (!value.isNullOrEmpty()) {
            getSharedPreferences(PREFS, MODE_PRIVATE).edit().putString(KEY_ENDPOINT, value).apply()
            return value
        }
        return getSharedPreferences(PREFS, MODE_PRIVATE).getString(KEY_ENDPOINT, "") ?: ""
    }

    private fun moduleDirectory(): File {
        val dir = File(filesDir, "jac-modules")
        if (!dir.isDirectory && !dir.mkdirs()) {
            throw IllegalStateException("unable to create Jac module directory")
        }
        return dir
    }

    private fun moduleFile(version: String): File {
        return File(moduleDirectory(), "jac-module-" + version + ".dex")
    }

    private fun restoreCachedModule() {
        try {
            val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
            val version = prefs.getString(KEY_PENDING_VERSION, null)
                ?: prefs.getString(KEY_VERSION, "")
            if (version.isNullOrEmpty()) return
            val module = moduleFile(version)
            if (!module.isFile) return
            module.setReadOnly()
            mountModule(module, version)
        } catch (error: Exception) {
            Log.e(TAG, "cached module restore failed", error)
        }
    }

    private fun poll() {
        if (!running || endpoint.isEmpty()) return
        Thread {
            try {
                val manifest = readJson(endpoint + "/_jac/dev/modules/manifest.json")
                val version = manifest.optString("version", "")
                val path = manifest.optString("path", "")
                if (version.isNotEmpty() && version != activeVersion && version != attemptedVersion) {
                    val module = download(endpoint + path, version)
                    handler.post { applyModule(module, version) }
                }
            } catch (error: Exception) {
                Log.e(TAG, "module poll failed", error)
            }
            handler.postDelayed({ poll() }, 300)
        }.start()
    }

    private fun readJson(value: String): JSONObject {
        val connection = URL(value).openConnection() as HttpURLConnection
        connection.useCaches = false
        connection.connectTimeout = 1000
        connection.readTimeout = 1000
        try {
            return JSONObject(connection.inputStream.readBytes().toString(Charsets.UTF_8))
        } finally {
            connection.disconnect()
        }
    }

    private fun download(value: String, version: String): File {
        val target = moduleFile(version)
        if (target.isFile) {
            target.setReadOnly()
            return target
        }
        val staged = File(moduleDirectory(), target.name + ".tmp")
        val connection = URL(value).openConnection() as HttpURLConnection
        connection.useCaches = false
        try {
            connection.inputStream.use { input ->
                FileOutputStream(staged).use { output -> input.copyTo(output) }
            }
        } finally {
            connection.disconnect()
        }
        if (!staged.renameTo(target)) {
            throw IllegalStateException("unable to publish Jac module")
        }
        target.setReadOnly()
        return target
    }

    private fun applyModule(file: File, version: String) {
        if (version == activeVersion) {
            return
        }
        if (version == attemptedVersion) {
            return
        }
        attemptedVersion = version
        if (activeVersion.isEmpty()) {
            if (!mountModule(file, version)) {
                attemptedVersion = ""
            }
        } else {
            getSharedPreferences(PREFS, MODE_PRIVATE)
                .edit()
                .putString(KEY_PENDING_VERSION, version)
                .apply()
            recreate()
        }
    }

    private fun mountModule(file: File, version: String): Boolean {
        try {
            val loader = DexClassLoader(file.absolutePath, codeCacheDir.absolutePath, null, classLoader)
            val type = loader.loadClass("{{package_name}}.JacDevEntry")
            val mount = type.getMethod("mount", ComponentActivity::class.java)
            mount.invoke(null, this)
            Log.i(TAG, "JAC_COMPOSE_MOUNTED v=" + version)
            activeVersion = version
            getSharedPreferences(PREFS, MODE_PRIVATE)
                .edit()
                .putString(KEY_VERSION, version)
                .remove(KEY_PENDING_VERSION)
                .apply()
            attemptedVersion = ""
            return true
        } catch (error: Exception) {
            Log.e(TAG, "module apply failed", error)
            file.delete()
            val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
            if (prefs.getString(KEY_VERSION, "") == version) {
                prefs.edit().remove(KEY_VERSION).apply()
            }
            prefs.edit().remove(KEY_PENDING_VERSION).apply()
            return false
        }
    }

    companion object {
        private const val TAG = "JacHmr"
        private const val PREFS = "jac-hmr"
        private const val EXTRA_SERVER = "jacDevServer"
        private const val KEY_ENDPOINT = "endpoint"
        private const val KEY_VERSION = "version"
        private const val KEY_PENDING_VERSION = "pending_version"
    }
}
