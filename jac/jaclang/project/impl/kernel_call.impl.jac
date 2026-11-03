impl world_paths -> tuple[list[str], str] {
    return ([path for path in sys.path if path and os.path.isabs(path)], package_root());
}

impl call_compile(request: CompileRequest) -> CompileResult {
    kernel = load_kernel();
    if kernel is None {
        return compile_request(request);
    }
    try {
        raw = kernel.compile(request.to_dict());
    } except RuntimeError as refused {
        raise KernelError(str(refused)) from refused;
    }
    return CompileResult.from_dict(raw);
}

impl call_check(request: CheckRequest) -> CheckResult {
    kernel = load_kernel();
    if kernel is None {
        return check_request(request);
    }
    try {
        raw = kernel.check(request.to_dict());
    } except RuntimeError as refused {
        raise KernelError(str(refused)) from refused;
    }
    return CheckResult.from_dict(raw);
}

impl open_kernel_session(project_root: str) -> SessionClient {
    (search_paths, package) = world_paths();
    kernel = load_kernel();
    if kernel is None {
        return SessionClient(
            project_root=project_root,
            local=open_session(project_root, search_paths, package)
        );
    }
    try {
        handle = kernel.open_session(project_root, search_paths, package);
    } except RuntimeError as refused {
        raise KernelError(str(refused)) from refused;
    }
    return SessionClient(project_root=project_root, handle=handle);
}

impl SessionClient.query(method: str, args: list[any]) -> any {
    if self.local is not None {
        return session_query(self.local, method, args);
    }
    kernel = load_kernel();
    try {
        return kernel.session_query(self.handle, method, args);
    } except RuntimeError as refused {
        raise KernelError(str(refused)) from refused;
    }
}

impl SessionClient.close {
    if self.local is not None {
        self.local = None;
        return;
    }
    if self.handle {
        load_kernel().close_session(self.handle);
        self.handle = 0;
    }
}
