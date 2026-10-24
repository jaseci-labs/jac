import os;

def scale_runtime_configured -> bool;

def mark_scale_runtime;

glob _sv_service_routes_warned: bool = False;

class JacScaleRuntime {
    static def create_j_context(
        user_root: (str | None),
        base_path_dir: (str | None) = None,
        full_target_path: (str | None) = None
    ) -> ExecutionContext | None;

    static def create_server(jac_server: JacServer, host: str, port: int);
    static def get_server_extensions -> list[ServerExtension];
    static def store(
        base_path: str = "./storage", create_dirs: bool = True
    ) -> Storage;

    static def get_sv_service_routes -> dict[str, any];
    static def get_sv_registry -> dict[str, str];
    static def sv_transport_available -> bool;
    static def sv_service_call(
        app: str,
        func_name: str,
        args: dict[str, any],
        headers: dict[str, str] | None = None
    ) -> any;

    static def sv_walker_call(
        app: str,
        walker_name: str,
        args: dict[str, any],
        stub_cls: any,
        headers: dict[str, str] | None = None
    ) -> any;
}
