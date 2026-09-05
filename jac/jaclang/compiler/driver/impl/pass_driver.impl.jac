impl _SetupProgress.postinit -> None {
    self._seen_files = `set();
}

impl _SetupProgress._get_jaclang_root -> str {
    if (self._jaclang_root is None) {
        import jaclang;
        self._jaclang_root = os.path.dirname(str(jaclang.__file__));
    }
    return self._jaclang_root;
}

impl _SetupProgress._atexit_handler -> None {
    if (self._banner_shown and (self._compile_count > 0)) {
        sys.stderr.write(
            f"Jac setup complete ({self._compile_count} modules compiled and cached)\n"
        );
        sys.stderr.flush();
    }
}

impl _SetupProgress.on_internal_compile(file_path: str) -> None {
    normalized = os.path.normpath(file_path);
    if (normalized in self._seen_files) {
        return;
    }
    self._seen_files.add(normalized);
    if not self._banner_shown {
        self._banner_shown = True;
        atexit.register(self._atexit_handler);
        sys.stderr.write(
            '\nSetting up Jac for first use (compiling and caching compiler)...\n'
        );
        sys.stderr.flush();
    }
    jaclang_root = self._get_jaclang_root();
    rel_path = file_path;
    if normalized.startswith((jaclang_root + os.sep)) {
        rel_path = os.path.relpath(normalized, os.path.dirname(jaclang_root));
    }
    self._compile_count += 1;
    import time;
    if self._first_compile_at is None {
        self._first_compile_at = time.monotonic();
    }
    if self._precompile_limit() > 0 {
        since = time.monotonic() - self._first_compile_at;
        sys.stderr.write(
            f"  Compiling {rel_path}... [{self._compile_count} @ {since:.2f}s]\n"
        );
    } else {
        sys.stderr.write(f"  Compiling {rel_path}...\n");
    }
    sys.stderr.flush();
    self._halt_at_limit();
}

"""The setup line for a kernel derivation: the first parse of a checkout
that has no kernel, or one whose plan digest moved, relinks it here."""
impl _SetupProgress.on_kernel_build(lib_path: str) -> None {
    if not self._banner_shown {
        self._banner_shown = True;
        atexit.register(self._atexit_handler);
        sys.stderr.write(
            '\nSetting up Jac for first use (compiling and caching compiler)...\n'
        );
    }
    sys.stderr.write(
        f"  Linking the native compiler kernel ({os.path.basename(lib_path)})...\n"
    );
    sys.stderr.flush();
}

impl _SetupProgress._precompile_limit -> int {
    raw = os.environ.get("JAC_PRECOMPILE_LIMIT");
    if not raw {
        return 0;
    }
    try {
        return int(raw);
    } except ValueError {
        return 0;
    }
}

impl _SetupProgress._halt_at_limit -> None {
    limit = self._precompile_limit();
    if limit <= 0 or self._compile_count < limit {
        return;
    }
    import time;
    started = self._first_compile_at if self._first_compile_at is not None else 0.0;
    elapsed = time.monotonic() - started;
    sys.stderr.write(
        f"Jac precompile limit reached: {self._compile_count} modules in "
        f"{elapsed:.2f}s\n"
    );
    sys.stderr.flush();
    os._exit(0);
}

impl _SetupProgress.is_active.getter -> bool {
    return self._banner_shown;
}

impl CompileProgress.postinit -> None {
    self._listeners = [];
}

impl CompileProgress.notify(file_path: str) -> None {
    for callback in list(self._listeners) {
        callback(file_path);
    }
}

@contextmanager
impl CompileProgress.listen(callback: Callable[[str], None]) -> Iterator[None] {
    self._listeners.append(callback);
    try {
        yield None;
    } finally {
        self._listeners.remove(callback);
    }
}
