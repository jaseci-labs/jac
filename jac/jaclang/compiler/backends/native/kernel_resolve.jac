import from jaclang.jac0core.cache_paths { FileLock, atomic_write }
import json;
import os;
import sys;
import from jaclang.runtime.object_model { field }
import from jaclang.compiler.driver.compile_options {
    CompileOptions,
    NATIVE_LINK_MODE_BITCODE
}

glob KERNEL_LIB_ENV: str = "JAC_COMPILER_LIB",
     STUBCAT_BUILDING_ENV: str = "JAC_STUBCAT_BUILDING",
     KERNEL_OFF_VALUES: tuple[str, ...] = ("none", "off", "disabled", "0"),
     LAYOUT_SIDECAR_SUFFIX: str = ".layout.json";

obj ResolvedKernel {
    has lib_path: str,
        layout: dict,
        source: str,
        plan_digest: str = "";
}

class KernelUnavailable(RuntimeError) {}

def kernel_lib_name -> str {
    if sys.platform == "darwin" {
        return "libjac_compiler.dylib";
    }
    if sys.platform.startswith("win") {
        return "jac_compiler.dll";
    }
    return "libjac_compiler.so";
}

def source_tree_kernel_path -> str {
    import from jaclang.compiler.frontend.codeinfo { jaclang_pkg_root }
    return os.path.join(jaclang_pkg_root(), "compiler", kernel_lib_name());
}

def read_sidecar(lib_path: str) -> (dict | None) {
    data: any = None;
    try {
        with open(lib_path + LAYOUT_SIDECAR_SUFFIX, "r", encoding="utf-8") as f {
            data = json.load(f);
        }
    } except Exception {
        return None;
    }
    if not isinstance(data, dict) or not isinstance(data.get("classes"), dict) {
        return None;
    }
    return data;
}

def _from_explicit(path: str) -> ResolvedKernel {
    sidecar = read_sidecar(path);
    if not os.path.isfile(path) or sidecar is None {
        raise KernelUnavailable(
            f"{KERNEL_LIB_ENV}={path} does not name a kernel lib with its "
            f"{LAYOUT_SIDECAR_SUFFIX} sidecar"
        );
    }
    return ResolvedKernel(
        lib_path=path,
        layout=sidecar["classes"],
        source="explicit",
        plan_digest=str(sidecar.get("plan_digest", ""))
    );
}

def _from_sealed_image -> (ResolvedKernel | None) {
    import from jaclang.jac0core { sealed }
    image = sealed._jaclang_image();
    if image is None {
        return None;
    }
    record = image.native_artifact();
    if record is None {
        raise KernelUnavailable(
            "sealed jaclang image carries no native compiler kernel; the image "
            "is immutable, so rebuild the payload"
        );
    }
    lib_path = str(image.pkg_dir / record["path"]);
    sidecar = read_sidecar(lib_path);
    if not os.path.isfile(lib_path) or sidecar is None {
        raise KernelUnavailable(
            f"sealed jaclang image names kernel {lib_path} but it or its "
            f"{LAYOUT_SIDECAR_SUFFIX} sidecar is missing"
        );
    }
    import hashlib;
    with open(lib_path, "rb") as f {
        digest = hashlib.sha256(f.read()).hexdigest();
    }
    if digest != record.get("sha256") {
        raise KernelUnavailable(
            f"sealed kernel {lib_path} does not match its manifest sha256"
        );
    }
    if str(sidecar.get("plan_digest", "")) != str(record.get("plan_digest", "")) {
        raise KernelUnavailable(
            f"sealed kernel {lib_path}: sidecar plan digest disagrees with the manifest"
        );
    }
    return ResolvedKernel(
        lib_path=lib_path,
        layout=sidecar["classes"],
        source="sealed",
        plan_digest=str(record.get("plan_digest", ""))
    );
}

def _toolchain_available -> bool {
    try {
        import from jaclang.compiler.driver.schedules { native_pipeline_available }
        (ok, _why) = native_pipeline_available();
        return bool(ok);
    } except Exception {
        return False;
    }
}

def kernel_options -> CompileOptions {
    """The kernel runs in this process, so it is always the host's: a cross
    target set for the artifacts being built never reaches the kernel's
    units, its source key or its plan.""";
    return CompileOptions(
        aot_mode=True,
        default_codespace="native",
        native_unit=True,
        skip_native_engine=True,
        native_target="",
        na_gc_mode="cycles",
        memory_profile="managed",
        nogc_enforce_all=False,
        memory_enforce=[],
        memory_exempt=[],
        native_threads=4,
        rc_debug_codegen=False,
        native_debug=False,
        opt_level=2,
        dump_ir_path="",
        debug_ir=False,
        rc_stats=False,
        nogc_debug=False
    );
}

def kernel_plan(prog: any = None, mode: str = "") -> any {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.native_scope { kernel_root_path }
    import from jaclang.compiler.backends.native.link_plan { build_link_plan }
    program = prog if prog is not None else JacProgram();
    options = kernel_options();
    return build_link_plan(
        program, [kernel_root_path()], options, mode=mode, native_unit=True
    );
}

def build_kernel(dst: str, prog: any = None, log: any = None) -> any {
    import from jaclang.compiler.backends.native.link_plan {
        ArtifactKind,
        link_artifact
    }
    with _StoreParserSpan() {
        plan = kernel_plan(prog, mode=NATIVE_LINK_MODE_BITCODE);
        os.makedirs(os.path.dirname(os.path.abspath(dst)) or ".", exist_ok=True);
        return link_artifact(plan, dst, ArtifactKind.SHARED, log=log);
    }
}

class _StoreParserSpan {
    def init(self: _StoreParserSpan) {
        self.prev = None;
    }

    def __enter__(self: _StoreParserSpan) -> _StoreParserSpan {
        self.prev: (str | None) = os.environ.get(KERNEL_LIB_ENV);
        os.environ[KERNEL_LIB_ENV] = "off";
        return self;
    }

    def __exit__(self: _StoreParserSpan, exc_type: any, exc: any, tb: any) -> bool {
        if self.prev is None {
            os.environ.pop(KERNEL_LIB_ENV, None);
        } else {
            os.environ[KERNEL_LIB_ENV] = str(self.prev);
        }
        return False;
    }
}

def _from_source_tree -> (ResolvedKernel | None) {
    if not _toolchain_available() {
        return None;
    }
    lib_path = source_tree_kernel_path();
    found = _accept_in_tree(lib_path);
    if found is not None {
        return found;
    }
    try {
        return _derive_in_tree(lib_path);
    } except KernelUnavailable {
        raise;
    } except Exception as e {
        sys.stderr.write(
            f"jac: the native compiler kernel could not be derived "
            f"({type(e).__name__}: {e}); parsing with the store parser. "
            "Run `jac precompile ./jac --seal` to see the full diagnostics.\n"
        );
        return None;
    }
}

def _sidecar_matches_sources(sidecar: dict) -> bool {
    import from jaclang.compiler.backends.native.link_plan {
        sidecar_unit_paths,
        units_source_key
    }
    units = sidecar_unit_paths(sidecar);
    recorded = str(sidecar.get("source_key", ""));
    if not units or not recorded {
        return False;
    }
    return units_source_key(units, kernel_options()) == recorded;
}

def _accept_in_tree(lib_path: str) -> (ResolvedKernel | None) {
    sidecar = read_sidecar(lib_path);
    if sidecar is None or not os.path.isfile(lib_path) {
        return None;
    }
    import from jaclang.compiler.backends.native.link_plan { _sha256_of }
    try {
        if sidecar.get("artifact_sha256") != _sha256_of(lib_path) {
            return None;
        }
    } except OSError {
        return None;
    }
    if not _sidecar_matches_sources(sidecar) {
        return None;
    }
    return ResolvedKernel(
        lib_path=lib_path,
        layout=sidecar["classes"],
        source="tree",
        plan_digest=str(sidecar.get("plan_digest", ""))
    );
}

def _bundled_kernel_path -> (str | None) {
    """The kernel the running kit carries, when this process's compiler is
    a rerouted checkout rather than that kit: the kit's sealed jaclang sits
    beside its interpreter.""";
    import from jaclang.compiler.frontend.codeinfo { jaclang_pkg_root }
    site_pkg = os.path.join(os.path.dirname(sys.prefix), "site", "jaclang");
    if not os.path.isdir(os.path.join(site_pkg, "_precompiled")) {
        return None;
    }
    if os.path.realpath(site_pkg) == os.path.realpath(jaclang_pkg_root()) {
        return None;
    }
    try {
        import from jaclang.jac0core.sealed { load_image }
        image = load_image(os.path.join(site_pkg, "_precompiled"));
        if image is None {
            return None;
        }
        record = image.native_artifact();
    } except Exception {
        return None;
    }
    if not record {
        return None;
    }
    lib_path = os.path.join(site_pkg, str(record.get("path", "")));
    return lib_path if os.path.isfile(lib_path) else None;
}

def _adopt_bundled(lib_path: str) -> (ResolvedKernel | None) {
    """A checkout whose sources are the ones the kit was built from takes
    the kit's kernel instead of deriving its own: the sidecar's source key
    is the same compiler digest and unit keys the derivation would settle
    on. The copy lands beside the loader so later runs accept it in place.""";
    bundled = _bundled_kernel_path();
    if bundled is None {
        return None;
    }
    sidecar = read_sidecar(bundled);
    if sidecar is None or not _sidecar_matches_sources(sidecar) {
        return None;
    }
    try {
        os.makedirs(os.path.dirname(lib_path) or ".", exist_ok=True);
        _publish_kernel(bundled, lib_path);
    } except OSError {
        return None;
    }
    return _accept_in_tree(lib_path);
}

def _publish_kernel(source: str, destination: str) {
    """Publish the library before its hash-bearing sidecar; readers fail closed
    until both images agree. The caller holds the destination's build lock.""";
    import from pathlib { Path }
    atomic_write(destination, Path(source).read_bytes(), mode=0o755);
    atomic_write(
        destination + LAYOUT_SIDECAR_SUFFIX,
        Path(source + LAYOUT_SIDECAR_SUFFIX).read_bytes(),
        mode=0o644
    );
}

def _build_kernel_in_child(dst: str) {
    import subprocess;
    env = child_compiler_env({KERNEL_LIB_ENV: "off"});
    code = (
        "import sys\n"
        "sys.path.insert(0, sys.argv[-1])\n"
        "from jaclang.compiler.backends.native.kernel_resolve import build_kernel\n"
        "build_kernel(sys.argv[1], log=lambda m: sys.stderr.write(m + '\\n'))\n"
    );
    proc = subprocess.run(child_compiler_argv(code, [dst]), env=env);
    if proc.returncode != 0 {
        raise RuntimeError(f"kernel build exited with status {proc.returncode}");
    }
}

def _derive_in_tree(lib_path: str) -> (ResolvedKernel | None) {
    found = _accept_in_tree(lib_path);
    if found is not None {
        return found;
    }
    lock = FileLock(lib_path + ".lock");
    lock.acquire();
    try {
        found = _accept_in_tree(lib_path) or _adopt_bundled(lib_path);
        if found is not None {
            return found;
        }
        import from jaclang.compiler.driver.pass_driver { setup_progress }
        setup_progress.on_kernel_build(lib_path);
        tmp = f"{lib_path}.{os.getpid()}.tmp";
        try {
            _build_kernel_in_child(tmp);
            _publish_kernel(tmp, lib_path);
        } finally {
            for leftover in (tmp, tmp + LAYOUT_SIDECAR_SUFFIX) {
                try {
                    os.remove(leftover);
                } except OSError {}
            }
        }
        sidecar = read_sidecar(lib_path);
        if sidecar is None {
            raise RuntimeError("the kernel build left no layout sidecar");
        }
        return ResolvedKernel(
            lib_path=lib_path,
            layout=sidecar["classes"],
            source="tree",
            plan_digest=str(sidecar.get("plan_digest", ""))
        );
    } finally {
        lock.release();
    }
}

def resolve_kernel -> (ResolvedKernel | None) {
    if os.environ.get(STUBCAT_BUILDING_ENV) {
        return None;
    }
    lib_setting = os.environ.get(KERNEL_LIB_ENV, "");
    if lib_setting.strip().lower() in KERNEL_OFF_VALUES {
        return None;
    }
    if lib_setting {
        return _from_explicit(lib_setting);
    }
    sealed = _from_sealed_image();
    if sealed is not None {
        return sealed;
    }
    return _from_source_tree();
}

def compiler_package_parent -> str {
    """The directory holding the `jaclang` package this process runs: what a
child must put first on its path to run the same compiler. A build boots
its interpreter with `-I` and an explicit `sys.path`, which a child does
not inherit, and `python -c` would otherwise put the working directory
first, where a checkout's own `jaclang` shadows the tree being built.""";
    import from jaclang.compiler.frontend.codeinfo { jaclang_pkg_root }
    return os.path.dirname(jaclang_pkg_root());
}

def child_compiler_argv(code: str, args: list[str]) -> list[str] {
    """The command line of a child compiler process: this interpreter, safe
path mode so the working directory never joins `sys.path`, the driver
code, its arguments, and the package parent for the driver to insert
first. `import jaclang` registers the `.jac` importer itself.""";
    import sys;
    return [sys.executable, "-P", "-c", code]
        + list(args)
        + [compiler_package_parent()];
}

def child_compiler_env(extra: (dict[str, str] | None) = None) -> dict[str, str] {
    env = dict(os.environ);
    pkg_parent = compiler_package_parent();
    prior = env.get("PYTHONPATH", "");
    parts = [pkg_parent] + ([prior] if prior else []);
    env["PYTHONPATH"] = os.pathsep.join(parts);
    if extra {
        env.update(extra);
    }
    return env;
}
