"""FsPlugin — illustrative refactor showing the manifest + factory additions.

DRAFT STUB (proposal). Only the NEW parts are shown in full; the existing
handle()/_read_file()/_check_allowed()/etc. bodies are unchanged and elided.
The point: every plugin gains exactly two static members — manifest() and
build() — and loses its bespoke construction block in the codegen string.
"""
import os;
import from pathlib { Path }
import from desktop_plugin { PluginError, DesktopPlugin }
import from built_in.path_plugin { PathPlugin }
import from manifest { PluginManifest, CommandSpec, PluginContext }


glob FS_COMMANDS: list = [
         CommandSpec(
             name="read_file",
             params={"path": "str", "encoding": "str"},
             returns="dict",
             doc="Read a text file inside an allowed root."
         ),
         CommandSpec(
             name="write_file",
             params={"path": "str", "content": "str"},
             returns="dict",
             doc="Write a text file inside an allowed root."
         ),
         CommandSpec(name="list_dir", params={"path": "str"}, returns="dict"),
         CommandSpec(name="mkdir", params={"path": "str"}, returns="dict"),
         CommandSpec(name="remove", params={"path": "str"}, returns="dict"),
         CommandSpec(name="exists", params={"path": "str"}, returns="dict"),
         CommandSpec(name="stat", params={"path": "str"}, returns="dict")
     ];


obj FsPlugin(DesktopPlugin) {
    has _path_plugin: PathPlugin,
        _allow_read: list = [],
        _allow_write: list = [],
        _resolved_read: list = [],
        _resolved_write: list = [];

    # ---- NEW: manifest + uniform factory ----
    """Declarative description used by the registry, module loader, and SDK gen."""
    static def manifest -> PluginManifest {
        return PluginManifest(
            name="jac.fs",
            config_key="fs",
            module="built_in.fs_plugin",
            class_name="FsPlugin",
            commands=FS_COMMANDS
        );
    }

    """Uniform construction. Hides FsPlugin's path-dependency behind the shared
    PluginContext so the registry can build every plugin the same way."""
    static def build(ctx: PluginContext, config: object) -> DesktopPlugin {
        return FsPlugin(DesktopPlugin._coerce_config(config), ctx.path_plugin);
    }

    # ---- existing constructor, now relying on the coerced config ----
    def init(config: dict, path_plugin: PathPlugin) {
        super.init("jac.fs");
        self._allow_read = config.get("allow_read", []);
        self._allow_write = config.get("allow_write", []);
        self._path_plugin = path_plugin;
        self._resolved_read = [self._resolve_pattern(p) for p in self._allow_read];
        self._resolved_write = [self._resolve_pattern(p) for p in self._allow_write];
    }
    # ---- handle() and all _read_file/_write_file/_check_allowed/etc.
    #      bodies are UNCHANGED from the current fs_plugin.jac and elided here ----
}
