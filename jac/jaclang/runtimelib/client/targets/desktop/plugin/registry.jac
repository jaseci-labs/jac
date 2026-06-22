"""Built-in plugin registry + data-driven bootstrap.

Replaces the seven hand-written `plugin_py += (...)` registration blocks in
native_desktop_target.impl.jac with the `BUILTIN_PLUGINS` list and
`bootstrap_plugins()`.

`bootstrap_plugins()` runs in the embedded CPython at startup. It is ordinary
Jac (transpiled like the other plugin modules), so it is unit-testable — unlike
the generated source strings it replaces.

Transpiled to dependency-free Python at build time.
"""
import from manifest { PluginManifest, PluginContext }
import from desktop_plugin { DesktopPlugin }
import from plugin_host { PluginHost }
import from built_in.path_plugin { PathPlugin }
import from built_in.window_plugin { WindowPlugin }
import from built_in.fs_plugin { FsPlugin }
import from built_in.notification_plugin { NotificationPlugin }
import from built_in.clipboard_plugin { ClipboardPlugin }
import from built_in.dialog_plugin { DialogPlugin }
import from built_in.shell_plugin { ShellPlugin }


"""Ordered registry. Order matters: PathPlugin first (it is a service other
plugins depend on via PluginContext).

NOTE: the build's importlib bootstrap keeps a parallel module load-order list
(`_plugin_mods` in native_desktop_target.impl.jac) that must contain every
`m.module` here plus the infra modules (manifest, desktop_plugin, ...). The two
cannot be unified because that bootstrap runs before registry is importable.
When you add a plugin, update both."""
glob BUILTIN_PLUGINS: list = [
         PathPlugin.manifest(),
         WindowPlugin.manifest(),
         FsPlugin.manifest(),
         NotificationPlugin.manifest(),
         ClipboardPlugin.manifest(),
         DialogPlugin.manifest(),
         ShellPlugin.manifest()
     ];


"""Construct + register every enabled plugin from config.

`modules` is sys.modules (injected so tests can pass a fake map). Returns a
fully-wired PluginHost. The generated host source calls this in one line instead
of emitting seven registration blocks.
"""
def bootstrap_plugins(configs: dict, modules: dict) -> PluginHost {
    ctx = PluginContext();
    # PathPlugin is a foundational service: fs needs it even when the jac.path
    # IPC surface is off. Always constructed; its IPC registration is still
    # gated by config in the loop below.
    ctx.path_plugin = PathPlugin();
    host = PluginHost();
    for m in BUILTIN_PLUGINS {
        cfg = configs.get(m.config_key, m.default_on);
        if not DesktopPlugin._config_enabled(cfg) {
            continue;
        }
        cls = getattr(modules[m.module], m.class_name);
        host.register(m.name, cls.build(ctx, cfg));
    }
    return host;
}
