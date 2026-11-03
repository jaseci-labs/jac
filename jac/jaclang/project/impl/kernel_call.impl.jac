impl runtime_builtin_initializing -> bool {
    import sys;
    held = sys.modules.get("jaclang.runtime.builtin");
    spec = held.__spec__ if held is not None else None;
    return spec is not None and bool(getattr(spec, "_initializing", False));
}

impl loaded_kernel -> (any | None) {
    if _KERNEL {
        return _KERNEL[0];
    }
    if _RESOLVED or _RESOLVING or runtime_builtin_initializing() {
        return None;
    }
    import from jaclang.jac0core.artifact_registry { resolution_in_flight }
    if resolution_in_flight() {
        return None;
    }
    _RESOLVING.append(True);
    try {
        found = resolve_kernel();
    } finally {
        _RESOLVING.clear();
    }
    if found is None {
        _RESOLVED.append(True);
        return None;
    }
    module = load_kernel_module(os.path.realpath(found.lib_path), found.source);
    _KERNEL.append(module);
    return module;
}

impl load_kernel_module(lib_path: str, source: str) -> any {
    import importlib.machinery;
    import importlib.util;
    if source in ("sealed", "kit") {
        remedy = "this jac installation is damaged; reinstall jac";
    } else {
        remedy = "rebuild it with `jac native build kernel --force`";
    }
    try {
        loader = importlib.machinery.ExtensionFileLoader(KERNEL_MODULE_NAME, lib_path);
        spec = importlib.util.spec_from_file_location(
            KERNEL_MODULE_NAME, lib_path, loader=loader
        );
        if spec is None {
            raise ImportError(f"no module spec for {lib_path}");
        }
        module = importlib.util.module_from_spec(spec);
        loader.exec_module(module);
    } except (ImportError, OSError) as err {
        raise KernelLoadError(
            "jac: the native compiler kernel cannot be loaded\n"
            f"  kernel: {lib_path}\n"
            f"  error:  {err}\n"
            f"  fix:    {remedy}"
        ) from err;
    }
    version = module?.API_VERSION;
    if version != KERNEL_API_VERSION {
        raise KernelLoadError(
            "jac: the native compiler kernel speaks another kernel API\n"
            f"  kernel: {lib_path} (API {version})\n"
            f"  host:   API {KERNEL_API_VERSION}\n"
            f"  fix:    {remedy}"
        );
    }
    return module;
}

impl reset_loaded_kernel {
    _KERNEL.clear();
    _RESOLVED.clear();
    _RESOLVING.clear();
}

impl required_kernel -> any {
    kernel = loaded_kernel();
    if kernel is None {
        raise KernelLoadError(
            "jac: this run has no native compiler kernel\n"
            "  fix:    run `jac native build kernel`"
        );
    }
    return kernel;
}

impl call_compile(
    request: KernelRequest, asker: (HostAsker | None) = None, in_process: bool = False
) -> CompileReport {
    if in_process {
        return compile_request(request, asker);
    }
    answer = asker.ask if asker is not None else None;
    return CompileReport.from_dict(
        required_kernel().compile(request.to_dict(), answer)
    );
}

impl call_check(
    request: KernelRequest, asker: (HostAsker | None) = None, in_process: bool = False
) -> AnalysisReport {
    if in_process {
        return check_request(request, asker);
    }
    answer = asker.ask if asker is not None else None;
    return AnalysisReport.from_dict(required_kernel().check(request.to_dict(), answer));
}
