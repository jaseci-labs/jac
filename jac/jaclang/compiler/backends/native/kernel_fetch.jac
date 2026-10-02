"""A kernel CI already built for these sources, fetched instead of built.

A checkout whose compiler sources match a commit CI sealed does not need to
run stage 0 at all: the kernel CI published for those inputs is downloaded,
verified against its sidecar and the sources, and installed in place.
The name of a published kernel is a digest of every input the sidecar
check compares, so a checkout computes it without building anything."""
import hashlib;
import json;
import os;
import sys;
import urllib.error;
import urllib.request;

glob KERNEL_FETCH_ENV: str = "JAC_KERNEL_FETCH",
     KERNEL_FETCH_BASE: str = "https://github.com/jaseci-labs/jac/releases/download/kernels",
     KERNEL_FETCH_TIMEOUT: float = 30.0,
     KERNEL_FETCH_OFF: tuple[str, ...] = ("0", "off", "false", "no", "none");

def kernel_unit_paths(pkg_root: str = "") -> list[str] {
    import from jaclang.compiler.backends.native.kernel_stage0 { running_kernel_target }
    spec = running_kernel_target(pkg_root);
    paths = [spec.module_path(m) for m in spec.scope_modules];
    paths.extend(
        os.path.join(spec.`root, *rel.split("/")) for rel in spec.kernel_unit_rel
    );
    import from jaclang.compiler.frontend.codeinfo { native_stdlib_root }
    stdlib = native_stdlib_root();
    if stdlib and os.path.isdir(stdlib) {
        for (folder, _dirs, files) in os.walk(stdlib) {
            paths.extend(
                os.path.join(folder, f)
                for f in files
                if f.endswith(".jac")
            );
        }
    }
    return sorted(
        {
            os.path.realpath(p)
            for p in paths
            if os.path.isfile(p)
        }
    );
}

def kernel_publish_key(pkg_root: str = "") -> (str | None) {
    """The inputs a stage-0 kernel is accepted by, folded into one name:
    the pin, the ABI, the target, the interpreter and every unit's source
    and policy, over the scope modules, the kernel units and the native
    stdlib. The target triple comes from the LLVM shim, so the name is only
    reliable where the shim loads. A checkout under a self pin publishes
    nothing.""";
    import from jaclang.compiler.backends.native.stage0_pin {
        Stage0PinError,
        abi_contract_digest,
        read_stage0_pin
    }
    import from jaclang.compiler.backends.native.kernel_resolve { kernel_options }
    import from jaclang.compiler.driver.jir { unit_source_digest }
    import from jaclang.compiler.frontend.codeinfo {
        NATIVE_ABI_VERSION,
        jaclang_pkg_root,
        native_unit_identity
    }
    try {
        pin = read_stage0_pin();
    } except (Stage0PinError, OSError) {
        return None;
    }
    if pin.is_self() {
        return None;
    }
    pkg = pkg_root or jaclang_pkg_root();
    options = kernel_options();
    h = hashlib.sha256();
    for part in [
        pin.commit,
        pin.compiler_digest,
        str(NATIVE_ABI_VERSION),
        abi_contract_digest(pkg),
        options.effective_triple(),
        f"{sys.version_info.major}.{sys.version_info.minor}"
    ] {
        h.update(part.encode("utf-8"));
        h.update(b"\x00");
    }
    for path in kernel_unit_paths(pkg) {
        h.update(native_unit_identity(path).encode("utf-8"));
        h.update(unit_source_digest(path).encode("utf-8"));
        h.update(str(int(options.native_required_for(path))).encode("utf-8"));
        h.update(b"\x00");
    }
    return h.hexdigest()[:32];
}

def kernel_asset_name(key: str) -> str {
    import from jaclang.compiler.backends.native.kernel_resolve { kernel_lib_name }
    (stem, ext) = os.path.splitext(kernel_lib_name());
    return f"{stem}-{key}{ext}";
}

def _fetch(url: str) -> (bytes | None) {
    try {
        request = urllib.request.Request(
            url, headers={"User-Agent": "jac-kernel-fetch"}
        );
        with urllib.request.urlopen(request, timeout=KERNEL_FETCH_TIMEOUT) as resp {
            if getattr(resp, "status", 200) not in (200, None) {
                return None;
            }
            return resp.read();
        }
    } except (urllib.error.URLError, OSError, ValueError) {
        return None;
    }
}

def fetch_published_kernel(lib_path: str) -> bool {
    """Install the kernel published for this checkout's inputs at lib_path,
    or do nothing: a missing asset, an unreachable host or a hash mismatch
    all leave the build to stage 0. JAC_KERNEL_FETCH names another base
    (a file:// directory serves tests and mirrors) or turns fetching off.""";
    import from jaclang.compiler.backends.native.kernel_resolve {
        LAYOUT_SIDECAR_SUFFIX,
        _publish_kernel
    }
    setting = os.environ.get(KERNEL_FETCH_ENV, "").strip();
    if setting.lower() in KERNEL_FETCH_OFF {
        return False;
    }
    key = kernel_publish_key();
    if key is None {
        return False;
    }
    base = (setting or KERNEL_FETCH_BASE).rstrip("/");
    name = kernel_asset_name(key);
    sidecar_bytes = _fetch(f"{base}/{name}{LAYOUT_SIDECAR_SUFFIX}");
    if sidecar_bytes is None {
        return False;
    }
    try {
        sidecar = json.loads(sidecar_bytes.decode("utf-8"));
    } except (UnicodeDecodeError, ValueError) {
        return False;
    }
    if not isinstance(sidecar, dict) or not sidecar.get("artifact_sha256") {
        return False;
    }
    body = _fetch(f"{base}/{name}");
    if body is None or hashlib.sha256(body).hexdigest() != sidecar["artifact_sha256"] {
        return False;
    }
    import from jaclang.jac0core.cache_paths { atomic_write }
    staged = f"{lib_path}.{os.getpid()}.fetched";
    try {
        os.makedirs(os.path.dirname(lib_path) or ".", exist_ok=True);
        atomic_write(staged, body, mode=0o755);
        _publish_kernel(staged, lib_path, sidecar=sidecar);
    } except OSError {
        return False;
    } finally {
        try {
            os.remove(staged);
        } except OSError {}
    }
    sys.stderr.write(f"jac: installed the published kernel {name}\n");
    return True;
}
