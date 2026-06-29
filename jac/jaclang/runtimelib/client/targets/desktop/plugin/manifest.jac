import ctypes;


obj PluginManifest {
    has name: str,
        config_key: str,
        module: str,
        class_name: str,
        default_on: bool = False;
}


obj PluginContext {
    has path_plugin: object | None = None,
        wv_handle: int = 0,
        wv_lib: ctypes.CDLL | None = None;
}
