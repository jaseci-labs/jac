import from jaclang.jac0core.cache_paths { FileLock, atomic_write }
import hashlib;
import json;
import os;
import sys;
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
        layout: dict[str, any],
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

def read_sidecar(lib_path: str) -> (dict[str, any] | None) {
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
        import from jaclang.compiler.driver.pipeline { native_pipeline_available }
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
        native_require=[],
        native_link_mode="objects",
        na_debug=False,
        default_codespace="native",
        force_target_program=True,
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

def _sha256_file(path: str) -> str {
    h = hashlib.sha256();
    with open(path, "rb") as f {
        while True {
            chunk = f.read(1 << 20);
            if not chunk {
                break;
            }
            h.update(chunk);
        }
    }
    return h.hexdigest();
}

def _sidecar_matches_sources(sidecar: dict[str, any]) -> bool {
    """Acceptance runs while the bootstrap tier is still compiling, so it
    reaches only the cache-key module; the link plan, which the legacy
    folded key needs, is imported for that key alone.""";
    import from jaclang.compiler.driver.jir { sidecar_unit_paths }
    units = sidecar_unit_paths(sidecar);
    if not units {
        return False;
    }
    recorded_sources = sidecar.get("unit_sources");
    if isinstance(recorded_sources, dict) and recorded_sources {
        return _unit_sources_match(sidecar, recorded_sources, units);
    }
    recorded = str(sidecar.get("source_key", ""));
    if not recorded {
        return False;
    }
    import from jaclang.compiler.backends.native.link_plan { units_source_key }
    return units_source_key(units, kernel_options()) == recorded;
}

def _unit_sources_match(
    sidecar: dict[str, any], recorded: dict[str, any], units: list[str]
) -> bool {
    """A kernel is its compiler, codegen identity, target, interpreter and
    the units' sources; comparing those inputs one by one accepts a kernel
    built at another path, such as the kit's staging directory. The folded
    source key is what an in-tree build records for itself: the module key
    of a file outside the running package fingerprints its project, so the
    key a kit's build folded is never the one a checkout computes.""";
    import from jaclang.compiler.driver.jir {
        running_compiler_digest,
        unit_source_digest
    }
    import from jaclang.compiler.frontend.codeinfo { native_unit_identity }
    options = kernel_options();
    if str(sidecar.get("compiler_digest", "")) != running_compiler_digest()
        or str(sidecar.get("codegen_identity", "")) != options.base_codegen_identity()
        or str(sidecar.get("triple", "")) != options.effective_triple()
        or str(sidecar.get("python", ""))
            != f"{sys.version_info.major}.{sys.version_info.minor}" {
        return False;
    }
    ids = sidecar.get("unit_ids");
    idents = (
        [str(i) for i in ids]
            if isinstance(ids, list) and len(ids) == len(units)
            else [native_unit_identity(u) for u in units]
    );
    if len(recorded) != len(idents) {
        return False;
    }
    policy = sidecar.get("unit_policy");
    recorded_policy: dict[str, any] = policy if isinstance(policy, dict) else {};
    for (ident, path) in zip(idents, units) {
        if recorded.get(ident) != unit_source_digest(path) {
            return False;
        }
        if int(recorded_policy.get(ident, 0))
            != int(options.native_required_for(path)) {
            return False;
        }
    }
    return True;
}

def _accept_in_tree(lib_path: str) -> (ResolvedKernel | None) {
    sidecar = read_sidecar(lib_path);
    if sidecar is None or not os.path.isfile(lib_path) {
        return None;
    }
    try {
        if sidecar.get("artifact_sha256") != _sha256_file(lib_path) {
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
    found = _bundled_kernel();
    return found[0] if found is not None else None;
}

def _bundled_kernel -> (tuple[str, dict[str, any]] | None) {
    """The kernel the running kit carries and its manifest record, when this
    process's compiler is a rerouted checkout rather than that kit: the
    kit's sealed jaclang sits beside its interpreter.""";
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
    return (lib_path, dict(record)) if os.path.isfile(lib_path) else None;
}

def _adopt_bundled(lib_path: str) -> (ResolvedKernel | None) {
    """A checkout whose sources are the ones the kit was built from takes
    the kit's kernel instead of deriving its own: the sidecar's source key
    is the same compiler digest and unit keys the derivation would settle
    on. The copy lands beside the loader so later runs accept it in place.""";
    found = _bundled_kernel();
    if found is None {
        return None;
    }
    (bundled, record) = found;
    sidecar = read_sidecar(bundled);
    if sidecar is None or not _sidecar_matches_sources(sidecar) {
        return None;
    }
    try {
        actual = _sha256_file(bundled);
    } except OSError {
        return None;
    }
    if str(record.get("sha256", "")) != actual {
        return None;
    }
    published = dict(sidecar);
    published["artifact_sha256"] = actual;
    try {
        os.makedirs(os.path.dirname(lib_path) or ".", exist_ok=True);
        _publish_kernel(bundled, lib_path, sidecar=published);
    } except OSError {
        return None;
    }
    return _accept_in_tree(lib_path);
}

def _publish_kernel(
    source: str, destination: str, sidecar: (dict[str, any] | None) = None
) {
    """Publish the library before its hash-bearing sidecar; readers fail closed
    until both images agree. The caller holds the destination's build lock.
    A kit strips its kernel after the sidecar recorded the library's hash and
    re-stamps only its manifest, so an adopted copy publishes the sidecar the
    caller re-stamped from that manifest.""";
    import from pathlib { Path }
    atomic_write(destination, Path(source).read_bytes(), mode=0o755);
    payload = (
        json.dumps(sidecar, sort_keys=True).encode("utf-8")
            if sidecar is not None
            else Path(source + LAYOUT_SIDECAR_SUFFIX).read_bytes()
    );
    atomic_write(destination + LAYOUT_SIDECAR_SUFFIX, payload, mode=0o644);
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
