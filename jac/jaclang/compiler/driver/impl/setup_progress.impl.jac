impl SetupProgress.postinit -> None {
    self._seen_files = `set();
}

impl SetupProgress._atexit_handler -> None {
    noun = "module" if self._reuse_count == 1 else "modules";
    if (self._banner_shown and (self._compile_count > 0)) {
        reused = (
            f", {self._reuse_count} reused from an earlier compiler build"
                if self._reuse_count > 0
                else ""
        );
        sys.stderr.write(
            f"Jac setup complete ({self._compile_count} modules compiled and cached{reused})\n"
        );
        sys.stderr.flush();
    } elif self._reuse_count > 0 {
        sys.stderr.write(
            f"Compiler sources changed: {self._reuse_count} unchanged compiler {noun} "
            "reused from an earlier compiler build ([dev] exact = true in jac.toml rebuilds them)\n"
        );
        sys.stderr.flush();
    }
}

impl SetupProgress._register_exit -> None {
    if not self._exit_registered {
        self._exit_registered = True;
        atexit.register(self._atexit_handler);
    }
}

impl SetupProgress.on_internal_reuse(file_path: str) -> None {
    normalized = os.path.normpath(file_path);
    if (normalized in self._seen_files) {
        return;
    }
    self._seen_files.add(normalized);
    self._reuse_count += 1;
    self._register_exit();
}

impl SetupProgress.on_internal_compile(file_path: str) -> None {
    normalized = os.path.normpath(file_path);
    if (normalized in self._seen_files) {
        return;
    }
    self._seen_files.add(normalized);
    if not self._banner_shown {
        self._banner_shown = True;
        self._register_exit();
        sys.stderr.write(
            '\nSetting up Jac for first use (compiling and caching compiler)...\n'
        );
        sys.stderr.flush();
    }
    jaclang_root = jaclang_pkg_root();
    rel_path = file_path;
    if normalized.startswith((jaclang_root + os.sep)) {
        rel_path = os.path.relpath(normalized, os.path.dirname(jaclang_root));
    }
    self._compile_count += 1;
    sys.stderr.write(f"  Compiling {rel_path}...\n");
    sys.stderr.flush();
}
