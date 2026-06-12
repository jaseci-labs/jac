"""Built-in plugin registry + data-driven bootstrap.

Replaces the seven hand-written `plugin_py += (...)` registration blocks and
the `_plugin_mods` list in native_desktop_target.impl.jac with one list and
one function.

`bootstrap_plugins()` runs in the embedded CPython at startup. It is ordinary
Jac (transpiled like the other plugin modules), so it is unit-testable — unlike
the generated source strings it replaces.

Transpiled to dependency-free Python at build time.
"""
import from manifest { PluginManifest, PluginContext }
import from plugin_host { PluginHost }
import from built_in.path_plugin { PathPlugin }
import from built_in.window_plugin { WindowPlugin }
import from built_in.fs_plugin { FsPlugin }
import from built_in.notification_plugin { NotificationPlugin }
import from built_in.clipboard_plugin { ClipboardPlugin }
import from built_in.dialog_plugin { DialogPlugin }
import from built_in.shell_plugin { ShellPlugin }


"""Ordered registry. Order matters: PathPlugin first (it is a service other
plugins depend on via PluginContext). This list is ALSO the module-load list
used by the build's importlib bootstrap, so there is no separate `_plugin_mods`."""
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
        if not _config_enables(cfg) {
            continue;
        }
        cls = getattr(modules[m.module], m.class_name);
        host.register(m.name, cls.build(ctx, cfg));
    }
    return host;
}


"""True when a config value means 'enabled'.

Only an explicit False (or missing/None) disables.
"""
def _config_enables(cfg: object) -> bool {
    return cfg is not False and cfg is not None;
}
