"""Where the native compiler kernel comes from.

`ensure_loaded` in `native_compiler.jac` calls `resolve_kernel()` and
nothing else. The precedence is fixed:

1. Explicit switches. `JAC_COMPILER_LIB` as a path is used as given and
   must carry its layout sidecar; `off` selects the store parser;
   `JAC_STUBCAT_BUILDING` keeps selecting the store parser during the
   catalog build.
2. Sealed image. The manifest's `native` record names the artifact, its
   sha256, layout digest and plan digest. Missing or mismatched is a startup
   error; a sealed image is immutable.
3. Source tree. The kernel beside `native_compiler.jac` is accepted when its
   recorded plan digest equals the digest the module cache computes now;
   otherwise the link plan rebuilds stale units and relinks, under a lock,
   with the store parser for the units' own parse.
4. No native toolchain: the store parser serves, silently.

There is no state in which the loader knows a kernel should exist but
cannot make one, so `zig build -Ddev` needs no kernel step: the first parse
derives it. The bootstrap order is the payload build's: the scope units are
parsed by the store parser while the kernel is rebuilt, so a kernel rebuild
never depends on a kernel.
"""
import json;
import os;
import sys;
import from dataclasses { field }

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

"""The in-tree kernel location: beside `native_compiler.jac`."""
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
        raise KernelUnavailable(f"sealed kernel {lib_path} does not match its manifest sha256");
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

"""The kernel a source tree should have now: the plan over the kernel root
with the frontend scope compiled as native units."""
def kernel_plan(prog: any = None) -> any {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.compiler.native_scope { kernel_root_path }
    import from jaclang.compiler.backends.native.link_plan { build_link_plan }
    program = prog if prog is not None else JacProgram();
    options = CompileOptions(
        aot_mode=True,
        default_codespace="native",
        force_target_program=True,
        native_unit=True,
        skip_native_engine=True
    );
    return build_link_plan(program, [kernel_root_path()], options, native_unit=True);
}

"""Link the kernel at `dst` from the plan. The units' own parse goes
through the store parser: the kernel switch is pinned off for the span of
the build, so a kernel rebuild never depends on a kernel."""
def build_kernel(dst: str, prog: any = None, log: any = None) -> any {
    import from jaclang.compiler.backends.native.link_plan {
        ArtifactKind,
        link_artifact
    }
    with _StoreParserSpan() {
        plan = kernel_plan(prog);
        os.makedirs(os.path.dirname(os.path.abspath(dst)) or ".", exist_ok=True);
        return link_artifact(plan, dst, ArtifactKind.SHARED, log=log);
    }
}

class _KernelLock {
    def init(self: _KernelLock, path: str) {
        self.path = path + ".lock";
        self.handle = None;
    }

    def acquire(self: _KernelLock) {
        os.makedirs(os.path.dirname(self.path) or ".", exist_ok=True);
        self.handle = open(self.path, "a+");
        if sys.platform.startswith("win") {
            import msvcrt;
            msvcrt.locking(self.handle.fileno(), msvcrt.LK_LOCK, 1);
        } else {
            import fcntl;
            fcntl.flock(self.handle.fileno(), fcntl.LOCK_EX);
        }
    }

    def release(self: _KernelLock) {
        if self.handle is None {
            return;
        }
        try {
            if sys.platform.startswith("win") {
                import msvcrt;
                msvcrt.locking(self.handle.fileno(), msvcrt.LK_UNLCK, 1);
            } else {
                import fcntl;
                fcntl.flock(self.handle.fileno(), fcntl.LOCK_UN);
            }
        } finally {
            self.handle.close();
            self.handle = None;
        }
    }
}

"""Pin the kernel switch off for the span of a plan computation or a
rebuild: the scope units parse through the store parser meanwhile."""
class _StoreParserSpan {
    def init(self: _StoreParserSpan) {
        self.prev = None;
    }

    def __enter__(self: _StoreParserSpan) -> _StoreParserSpan {
        self.prev = os.environ.get(KERNEL_LIB_ENV);
        os.environ[KERNEL_LIB_ENV] = "off";
        return self;
    }

    def __exit__(self: _StoreParserSpan, exc_type: any, exc: any, tb: any) -> bool {
        if self.prev is None {
            os.environ.pop(KERNEL_LIB_ENV, None);
        } else {
            os.environ[KERNEL_LIB_ENV] = self.prev;
        }
        return False;
    }
}

"""Source tree: accept the kernel by plan digest or derive it. A derivation
that fails (a scope unit that no longer lowers, a link error) is reported
once and the store parser serves, so an edit that breaks the kernel never
takes parsing down with it."""
def _from_source_tree -> (ResolvedKernel | None) {
    if not _toolchain_available() {
        return None;
    }
    lib_path = source_tree_kernel_path();
    try {
        with _StoreParserSpan() {
            return _derive_in_tree(lib_path);
        }
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

def _derive_in_tree(lib_path: str) -> (ResolvedKernel | None) {
    plan = kernel_plan();
    want = plan.plan_digest();
    sidecar = read_sidecar(lib_path);
    if os.path.isfile(lib_path) and sidecar is not None
        and str(sidecar.get("plan_digest", "")) == want {
        return ResolvedKernel(
            lib_path=lib_path, layout=sidecar["classes"], source="tree", plan_digest=want
        );
    }
    lock = _KernelLock(lib_path);
    lock.acquire();
    try {
        sidecar = read_sidecar(lib_path);
        if os.path.isfile(lib_path) and sidecar is not None
            and str(sidecar.get("plan_digest", "")) == want {
            return ResolvedKernel(
                lib_path=lib_path, layout=sidecar["classes"], source="tree", plan_digest=want
            );
        }
        import from jaclang.compiler.driver.pass_driver { setup_progress }
        setup_progress.on_kernel_build(lib_path);
        tmp = f"{lib_path}.{os.getpid()}.tmp";
        try {
            import from jaclang.compiler.backends.native.link_plan {
                ArtifactKind,
                link_artifact
            }
            result = link_artifact(plan, tmp, ArtifactKind.SHARED);
            os.replace(tmp + LAYOUT_SIDECAR_SUFFIX, lib_path + LAYOUT_SIDECAR_SUFFIX);
            os.replace(tmp, lib_path);
        } finally {
            for leftover in (tmp, tmp + LAYOUT_SIDECAR_SUFFIX) {
                try {
                    os.remove(leftover);
                } except OSError {}
            }
        }
        return ResolvedKernel(
            lib_path=lib_path,
            layout=result.classes,
            source="tree",
            plan_digest=result.plan_digest
        );
    } finally {
        lock.release();
    }
}

"""The one kernel lookup."""
def resolve_kernel -> (ResolvedKernel | None) {
    if os.environ.get(STUBCAT_BUILDING_ENV) {
        return None;
    }
    override = os.environ.get(KERNEL_LIB_ENV, "");
    if override.strip().lower() in KERNEL_OFF_VALUES {
        return None;
    }
    if override {
        return _from_explicit(override);
    }
    sealed = _from_sealed_image();
    if sealed is not None {
        return sealed;
    }
    return _from_source_tree();
}
