import hashlib;
import json;
import shutil;
import sys;
import time;
import from pathlib { Path }
import from jaclang.compiler.backends.native.kernel_resolve {
    LAYOUT_SIDECAR_SUFFIX,
    CI_BUILD_PROFILE,
    SEALED_LINK_MODE,
    STAGE0_BUILDER,
    _accept_in_tree,
    _sha256_file,
    kernel_options,
    read_sidecar,
    seal_link_mode
}
import from jaclang.compiler.backends.native.kernel_stage0 {
    link_kernel,
    running_kernel_target
}
import from jaclang.compiler.backends.native.stage0_build { build_kernel_by_pin }
import from jaclang.compiler.kernel_target { KernelTarget, set_kernel_target }
import from jaclang.compiler.driver.jir { cache_mode, get_jir_cache_dir }
import from jaclang.compiler.driver.native_iface { layout_digest }
import from jaclang.jac0core.cache_paths { FileLock, atomic_write }

def _log(message: str) {
    sys.stderr.write(message + "\n");
    sys.stderr.flush();
}

def kernel_build_key(target: KernelTarget) -> str {
    import from jaclang.compiler.backends.native.llvm { _find_shim }
    spec = target.to_dict();
    spec.pop("root");
    spec.pop("link_mode");
    body = {
        "format": 1,
        "target": spec,
        "shim": _sha256_file(_find_shim()),
        "options": kernel_options().base_codegen_identity()
    };
    return hashlib.sha256(json.dumps(body, sort_keys=True).encode()).hexdigest();
}

def cached_kernel(path: Path, mode: str, inputs: str) -> bool {
    (rebuild, _) = cache_mode();
    if rebuild {
        return False;
    }
    sidecar = read_sidecar(str(path));
    if sidecar is None {
        return False;
    }
    try {
        import from jaclang.compiler.kernel_target { target_pkg_root }
        parent = Path(target_pkg_root()).parent;
        for ident in sidecar.get("unit_ids", []) {
            if str(ident).startswith("jaclang/")
                and not (parent / str(ident)).is_file() {
                return False;
            }
        }
        return sidecar.get("link_mode") == mode
            and sidecar.get("seal_inputs") == inputs
            and sidecar.get("layout_digest") == layout_digest(sidecar["classes"])
            and _accept_in_tree(str(path)) is not None;
    } except Exception {
        return False;
    }
}

def kernel_record(path: Path, artifact_rel: str, mode: str) -> dict[str, any] {
    sidecar = read_sidecar(str(path));
    if sidecar is None or sidecar.get("link_mode") != mode {
        raise RuntimeError(f"kernel build did not produce its requested {mode} link");
    }
    digest = hashlib.sha256(path.read_bytes()).hexdigest();
    if sidecar.get("artifact_sha256") != digest {
        raise RuntimeError("kernel build artifact does not match its sidecar sha256");
    }
    if sidecar.get("layout_digest") != layout_digest(sidecar["classes"]) {
        raise RuntimeError("kernel layout does not match its sidecar digest");
    }
    record: dict[str, any] = {
        "path": Path(artifact_rel).as_posix(),
        "sha256": digest,
        "layout_digest": str(sidecar.get("layout_digest", "")),
        "plan_digest": str(sidecar.get("plan_digest", "")),
        "triple": str(sidecar.get("triple", "")),
        "mode": mode
    };
    if sidecar.get("builder") == STAGE0_BUILDER {
        stage0 = sidecar.get("stage0");
        if not isinstance(stage0, dict) {
            raise RuntimeError("stage-0 kernel carries no producing compiler identity");
        }
        record["builder"] = STAGE0_BUILDER;
        record["stage0"] = dict(stage0);
    }
    if mode != SEALED_LINK_MODE {
        record["profile"] = CI_BUILD_PROFILE;
    }
    return {"units": {}, "artifact": record};
}

def seal_kernel(
    pkg_path: Path, artifact_path: Path, artifact_rel: str
) -> dict[str, any] {
    started = time.monotonic();
    mode = seal_link_mode();
    spec = running_kernel_target(str(pkg_path));
    inputs = kernel_build_key(spec);
    work = get_jir_cache_dir() / "kernel";
    work.mkdir(parents=True, exist_ok=True);
    lock = FileLock(str(work / "build.lock"), timeout=7200.0);
    lock.acquire();
    previous = set_kernel_target(spec);
    try {
        out = work / "out" / mode / artifact_path.name;
        bitcode = work / "out" / SEALED_LINK_MODE / artifact_path.name;
        if mode != SEALED_LINK_MODE
            and cached_kernel(bitcode, SEALED_LINK_MODE, inputs) {
            out = bitcode;
            mode = SEALED_LINK_MODE;
        }
        if cached_kernel(out, mode, inputs) {
            _log(f"  Kernel: reusing verified {mode} artifact");
        } else {
            target = work / "target" / pkg_path.name;
            if target.exists() {
                shutil.rmtree(target);
            }
            shutil.copytree(
                pkg_path,
                target,
                symlinks=True,
                ignore=shutil.ignore_patterns(
                    "__pycache__",
                    "_precompiled",
                    "_bun",
                    "*.so",
                    "*.so.*",
                    "*.dylib",
                    "*.dll",
                    ".jac"
                )
            );
            spec = running_kernel_target(str(target));
            set_kernel_target(spec);
            out.parent.mkdir(parents=True, exist_ok=True);
            _log(f"  Kernel: selecting builder ({mode} link)");
            if not build_kernel_by_pin(str(out), spec=spec, link_mode=mode) {
                _log(f"  Kernel: self build ({mode} link)");
                link_kernel(str(out), target=spec, link_mode=mode, log=_log);
            }
            kernel_record(out, artifact_rel, mode);
            sidecar = read_sidecar(str(out));
            assert sidecar is not None;
            sidecar["seal_inputs"] = inputs;
            atomic_write(
                str(out) + LAYOUT_SIDECAR_SUFFIX,
                json.dumps(sidecar, sort_keys=True).encode()
            );
        }
        record = kernel_record(out, artifact_rel, mode);
        artifact_path.parent.mkdir(parents=True, exist_ok=True);
        for suffix in ("", LAYOUT_SIDECAR_SUFFIX) {
            shutil.copyfile(str(out) + suffix, str(artifact_path) + suffix);
        }
        _log(f"  Kernel: sealed in {time.monotonic() - started:.1f}s ({mode} link)");
        return record;
    } finally {
        set_kernel_target(previous);
        lock.release();
    }
}
