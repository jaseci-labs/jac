obj RuntimeSymbol {
    has name: str,
        source: str = "@jac/runtime",
        prepend: bool = False;
}

glob _REACT_RUNTIME_SURFACE: list[RuntimeSymbol] = [
         RuntimeSymbol(name="__jacJsx", prepend=True),
         RuntimeSymbol(name="__jacSpawn", prepend=True),
         RuntimeSymbol(name="useRef", source="react"),
         RuntimeSymbol(name="forwardRef", source="react")
     ];

def runtime_symbol(name: str) -> (RuntimeSymbol | None);

glob WASM_HOST_MODULE: str = "@jac/wasm_host";

def injected_virtual_modules(backend: FrameworkBackend) -> list[str];

def runtime_import_source(name: str, backend: (FrameworkBackend | None) = None) -> str;

def backend_jsx_factory_name(backend: (FrameworkBackend | None) = None) -> str;

def _required_runtime_globals(
    backend: (FrameworkBackend | None) = None
) -> tuple[list[str], str];

def with_runtime_globals(
    js_code: str, backend: (FrameworkBackend | None) = None
) -> str;

def prepend_active_runtime_globals(js_code: str) -> str;
