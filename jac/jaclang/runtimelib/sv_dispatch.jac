"""Shared host dispatch for test/bun sv services used by core + scale runtimes."""

import from pathlib { Path }
import from jaclang.jac0core.sv_service_host { resolve_sv_service_host }
import from jaclang.jac0core.host { HOST_BUN, HOST_TEST }
import from jaclang.runtimelib.test_sv_host {
    prepare_test_sv_service,
    get_test_adapter
}
import from jaclang.runtimelib.bun_sv_spawn { spawn_bun_sv_service }
import from jaclang.runtimelib { sv_client }


def default_sv_base_port(module_name: str) -> int {
    return 18000 + hash(module_name) % 1000;
}


# Host test/bun sv services for module_name.
#
# Registers the service on sv_client and returns its base_url, or returns
# None when the caller should fall through to the cpython path. When
# kinds is given, only those host kinds are dispatched.
def dispatch_sv_service(
    module_name: str,
    base_path: str,
    *,
    port: int = 0,
    scale_mode: bool = False,
    progress: any = None,
    on_spawn: any = None,
    kinds: (frozenset | None) = None
) -> (str | None) {
    host_kind = resolve_sv_service_host(module_name, base_path);
    if kinds is not None and host_kind not in kinds {
        return None;
    }
    if host_kind == HOST_TEST {
        if get_test_adapter(module_name) is not None {
            base_url = f"test://{module_name}";
        } else {
            module_file = str(Path(base_path) / f"{module_name}.jac");
            base_url = prepare_test_sv_service(module_name, module_file, base_path);
        }
        sv_client.register(module_name, base_url);
        return base_url;
    }
    if host_kind == HOST_BUN {
        # Port retry parity with the cpython sibling path
        # (serve_background(port_retries=100)): probe a free port instead of
        # failing hard when the hash-derived one is occupied.
        spawn_port = port;
        if spawn_port <= 0 {
            import from jaclang.scale.runtime.context.util { pick_free_port }
            spawn_port = pick_free_port(module_name);
        }
        spawn_result = spawn_bun_sv_service(
            module_name,
            base_path,
            spawn_port,
            scale_mode=scale_mode,
            progress=progress
        );
        if on_spawn is not None {
            on_spawn(spawn_result);
        }
        sv_client.register(module_name, spawn_result.base_url);
        return spawn_result.base_url;
    }
    return None;
}
