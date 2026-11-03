impl GeneratedPythonRejected.__str__ -> str {
    where = f"{self.path}:{self.line}:{self.col}" if self.line else self.path;
    return f"the generated Python of {where} does not compile: {self.reason}";
}

impl install_engine(engine: PythonEngine) {
    _ENGINES.clear();
    _ENGINES.append(engine);
}

impl active_engine -> PythonEngine {
    if not _ENGINES {
        raise RuntimeError(
            "no Python engine is installed: the host boot installs the host's and "
            "the kernel module installs the kernel's"
        );
    }
    return _ENGINES[0];
}
