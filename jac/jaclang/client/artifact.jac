import from pathlib { Path }
import from types { ModuleType }

class ClientBundleError(RuntimeError) {}

obj ClientBundle {
    has module_name: str,
        code: str,
        client_functions: list[str],
        client_globals: list[str],
        hash: str;
}

def client_output_dir(source_path: Path) -> Path;

def prebuilt_bundle(module: ModuleType, source_path: Path) -> ClientBundle | None;
