obj GeneratedPythonRejected(Exception) {
    has path: str,
        reason: str,
        line: int = 0,
        col: int = 0;

    def __str__ -> str;
}

obj PythonEngine {
    def parse_module(source: str, path: str) -> PyModule abst;
    def code_bytes(module: uni.Module) -> bytes abst;
    def python_source(module: uni.Module) -> str abst;
}

glob _ENGINES: list[PythonEngine] = [];

def install_engine(engine: PythonEngine);

def active_engine -> PythonEngine;
