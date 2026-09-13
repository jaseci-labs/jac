import from jaclang.compiler.backends.common.artifacts { InteropManifest }
import from jaclang.compiler.backends.native.naming { native_glob_init_symbols }

def install_native_static_init(
    engine: any, manifest: (InteropManifest | None)
) -> None {
    if engine is None {
        return;
    }
    engine.static_init_symbols = native_glob_init_symbols(manifest);
    engine.static_init_chained = {"jac_entry"};
}
