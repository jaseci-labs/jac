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


glob BUILTIN_PLUGINS: list = [
         PathPlugin.manifest(),
         WindowPlugin.manifest(),
         FsPlugin.manifest(),
         NotificationPlugin.manifest(),
         ClipboardPlugin.manifest(),
         DialogPlugin.manifest(),
         ShellPlugin.manifest()
     ];


def bootstrap_plugins(configs: dict, modules: dict) -> PluginHost {
    ctx = PluginContext();

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
