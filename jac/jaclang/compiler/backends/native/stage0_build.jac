import json;
import os;
import re;
import shutil;
import subprocess;
import sys;
import tarfile;
import type from jaclang.compiler.kernel_target { KernelTarget }
import from jaclang.compiler.backends.native.kernel_resolve {
    KERNEL_DEV_LINK_MODE,
    STAGE0_BUILDER
}
import from jaclang.compiler.backends.native.stage0_pin {
    Stage0Pin,
    Stage0PinError,
    abi_contract_differences,
    abi_contract_digest,
    read_stage0_pin,
    stage0_source_dir,
    stage0_strict
}

glob STAGE0_CACHE_DIR: str = "stage0",
     STAGE0_STAMP_NAME: str = ".stage0.json",
     STAGE0_EXIT_UNKNOWN_FORMAT: int = 3,
     STAGE0_EXIT_FOREIGN_COMPILER: int = 4,
     _ABI_PATTERN: str = r"NATIVE_ABI_VERSION\s*:\s*int\s*=\s*(\d+)",
     _TYPESHED_REL: tuple[str, ...] = ("vendor", "typeshed"),
     _STAGE0_CHILD: str = (
         "import os, sys\n"
         "root = sys.argv[-1]\n"
         "sys.path.insert(0, root)\n"
         "import jaclang\n"
         "home = os.path.realpath(os.path.dirname(jaclang.__file__))\n"
         "if home != os.path.realpath(os.path.join(root, 'jaclang')):\n"
         "    sys.stderr.write(f'stage 0 imported jaclang from {home}\\n')\n"
         "    sys.exit(4)\n"
         "try:\n"
         "    from jaclang.compiler.backends.native.kernel_stage0 import build_target_kernel\n"
         "except ImportError as e:\n"
         "    sys.stderr.write(f'stage 0 has no kernel entry point: {e}\\n')\n"
         "    sys.exit(3)\n"
         "log = lambda m: (sys.stderr.write(m + '\\n'), sys.stderr.flush())\n"
         "sys.exit(build_target_kernel(sys.argv[1], sys.argv[2], log=log))\n"
     );

class Stage0Unavailable(RuntimeError) {}

def _git(repo: str, args: list[str]) -> str {
    try {
        proc = subprocess.run(
            ["git", "-C", repo] + args, capture_output=True, text=True
        );
    } except OSError as e {
        raise Stage0Unavailable(f"git is unavailable: {e}");
    }
    if proc.returncode != 0 {
        raise Stage0Unavailable(
            f"git {' '.join(args)} failed: {proc.stderr.strip() or proc.returncode}"
        );
    }
    return proc.stdout.strip();
}

def _git_ok(repo: str, args: list[str]) -> bool {
    try {
        proc = subprocess.run(["git", "-C", repo] + args, capture_output=True);
        return proc.returncode == 0;
    } except OSError {
        return False;
    }
}

def checkout_repo -> tuple[str, str] {
    jac_dir = stage0_source_dir();
    top = os.path.realpath(_git(jac_dir, ["rev-parse", "--show-toplevel"]));
    rel = os.path.relpath(jac_dir, top).replace(os.sep, "/");
    if rel.startswith("..") {
        raise Stage0Unavailable(f"{jac_dir} is not inside its git work tree {top}");
    }
    return (top, "" if rel == "." else rel + "/");
}

def ensure_commit(repo: str, commit: str) {
    if _git_ok(repo, ["cat-file", "-e", commit + "^{commit}"]) {
        return;
    }
    _git(repo, ["fetch", "--depth=1", "origin", commit]);
    if not _git_ok(repo, ["cat-file", "-e", commit + "^{commit}"]) {
        raise Stage0Unavailable(f"commit {commit} is not in {repo} after fetching it");
    }
}

def stage0_dir(commit: str) -> str {
    import from jaclang.jac0core.cache_paths { get_cache_home }
    return os.path.join(str(get_cache_home()), STAGE0_CACHE_DIR, commit);
}

def _stamp_matches(s0_dir: str, pin: Stage0Pin) -> bool {
    try {
        with open(
            os.path.join(s0_dir, STAGE0_STAMP_NAME), "r", encoding="utf-8"
        ) as f {
            stamp = json.load(f);
        }
    } except (OSError, ValueError) {
        return False;
    }
    return isinstance(stamp, dict)
        and stamp.get("commit") == pin.commit
        and stamp.get("jaclang_tree") == pin.jaclang_tree
        and os.path.isdir(os.path.join(s0_dir, "jaclang"));
}

def _note_use(s0_dir: str) {
    try {
        os.utime(os.path.join(s0_dir, STAGE0_STAMP_NAME), None);
    } except OSError {}
}

def _extract_snapshot(repo: str, prefix: str, pin: Stage0Pin, s0_dir: str) {
    tmp = f"{s0_dir}.{os.getpid()}.tmp";
    shutil.rmtree(tmp, ignore_errors=True);
    os.makedirs(tmp);
    try {
        proc = subprocess.Popen(
            [
                "git",
                "-C",
                repo,
                "archive",
                "--format=tar",
                pin.commit,
                prefix + "jaclang"
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        );
        with tarfile.open(fileobj=proc.stdout, mode="r|") as tar {
            tar.extractall(tmp, filter="data");
        }
        err_bytes = proc.stderr.read() if proc.stderr is not None else b"";
        err = err_bytes.decode("utf-8", "replace").strip();
        if proc.wait() != 0 {
            raise Stage0Unavailable(f"git archive {pin.commit} failed: {err}");
        }
        extracted = os.path.join(tmp, *(prefix + "jaclang").split("/"));
        staged = os.path.join(tmp, "stage0");
        os.makedirs(staged);
        os.rename(extracted, os.path.join(staged, "jaclang"));
        with open(
            os.path.join(staged, STAGE0_STAMP_NAME), "w", encoding="utf-8"
        ) as f {
            json.dump({"commit": pin.commit, "jaclang_tree": pin.jaclang_tree}, f);
        }
        shutil.rmtree(s0_dir, ignore_errors=True);
        os.rename(staged, s0_dir);
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

def _materialize_typeshed(snapshot_pkg: str) {
    import from jaclang.compiler.frontend.codeinfo { jaclang_pkg_root }
    source = os.path.join(
        os.path.realpath(jaclang_pkg_root()), *_TYPESHED_REL, "stdlib"
    );
    if not os.path.isfile(os.path.join(source, "builtins.pyi")) {
        raise Stage0Unavailable(f"this checkout has no typeshed stdlib at {source}");
    }
    stdlib = os.path.join(snapshot_pkg, *_TYPESHED_REL, "stdlib");
    if os.path.islink(stdlib) {
        os.remove(stdlib);
    }
    if os.path.isfile(os.path.join(stdlib, "builtins.pyi")) {
        return;
    }
    staged = f"{stdlib}.{os.getpid()}.tmp";
    shutil.rmtree(staged, ignore_errors=True);
    shutil.copytree(source, staged);
    shutil.rmtree(stdlib, ignore_errors=True);
    os.rename(staged, stdlib);
}

def provision_stage0(pin: Stage0Pin, repo: str, prefix: str) -> str {
    import from jaclang.jac0core.cache_paths { FileLock }
    import from jaclang.compiler.driver.jir { compiler_source_digest }
    s0_dir = stage0_dir(pin.commit);
    os.makedirs(os.path.dirname(s0_dir), exist_ok=True);
    lock = FileLock(s0_dir + ".lock");
    lock.acquire();
    try {
        if not _stamp_matches(s0_dir, pin) {
            ensure_commit(repo, pin.commit);
            tree = _git(repo, ["rev-parse", f"{pin.commit}:{prefix}jaclang"]);
            if tree != pin.jaclang_tree {
                raise Stage0Unavailable(
                    f"{pin.commit}:{prefix}jaclang is tree {tree}, the pin says "
                    f"{pin.jaclang_tree}"
                );
            }
            _extract_snapshot(repo, prefix, pin, s0_dir);
        }
        _note_use(s0_dir);
        snapshot_pkg = os.path.join(s0_dir, "jaclang");
        _materialize_typeshed(snapshot_pkg);
        digest = compiler_source_digest(snapshot_pkg);
        if digest != pin.compiler_digest {
            raise Stage0Unavailable(
                f"the snapshot of {pin.commit} digests to {digest}, the pin says "
                f"{pin.compiler_digest}"
            );
        }
        return snapshot_pkg;
    } finally {
        lock.release();
    }
}

def _read_text(path: str) -> (str | None) {
    try {
        with open(path, "r", encoding="utf-8") as f {
            return f.read();
        }
    } except OSError {
        return None;
    }
}

def abi_version_of(pkg_root: str) -> (int | None) {
    text = _read_text(os.path.join(pkg_root, "compiler", "frontend", "codeinfo.jac"));
    if text is None {
        return None;
    }
    found = re.search(_ABI_PATTERN, text);
    return int(found.group(1)) if found else None;
}

def typeshed_pin_of(pkg_root: str) -> str {
    text = _read_text(os.path.join(pkg_root, *_TYPESHED_REL, "PIN"));
    return text.strip() if text is not None else "";
}

def file_guard_trips(pin: Stage0Pin, snapshot_pkg: str, target_root: str) -> list[str] {
    import from jaclang.compiler.frontend.codeinfo {
        NATIVE_ABI_VERSION,
        jaclang_pkg_root
    }
    trips: list[str] = [];
    ours = typeshed_pin_of(jaclang_pkg_root());
    theirs = typeshed_pin_of(snapshot_pkg);
    if not ours or ours != theirs or ours != pin.typeshed_pin {
        trips.append(
            f"typeshed pin {ours or '?'} here, {theirs or '?'} at stage 0, "
            f"{pin.typeshed_pin} pinned"
        );
    }
    abi = abi_version_of(snapshot_pkg);
    if abi != NATIVE_ABI_VERSION {
        trips.append(f"native ABI {NATIVE_ABI_VERSION} here, {abi} at stage 0");
    }
    changed = abi_contract_differences(snapshot_pkg, target_root);
    if changed {
        trips.append(f"kernel ABI contract differs: {', '.join(changed)}");
    }
    return trips;
}

def native_tree_trips(pin: Stage0Pin, repo: str, prefix: str) -> list[str] {
    tree = _git(repo, ["rev-parse", f"{pin.commit}:{prefix}native"]);
    if tree != pin.native_tree {
        return [
            f"{pin.commit}:{prefix}native is tree {tree}, the pin says {pin.native_tree}"
        ];
    }
    if not _git_ok(repo, ["diff", "--quiet", pin.commit, "--", prefix + "native"]) {
        return [f"{prefix}native differs from {pin.commit}"];
    }
    return [];
}

def stage0_child_env(snapshot_pkg: str, spec_path: str) -> dict[str, str] {
    import from jaclang.compiler.backends.native.kernel_resolve { KERNEL_LIB_ENV }
    import from jaclang.compiler.kernel_target { KERNEL_TARGET_ENV }
    import from jaclang.compiler.backends.native.llvm { _find_shim }
    parent = os.path.dirname(snapshot_pkg);
    env = dict(os.environ);
    env.pop("JAC_NO_DEV_SOURCE", None);
    env["PYTHONPATH"] = parent;
    env["JAC_DEV_SOURCE"] = parent;
    env[KERNEL_LIB_ENV] = "off";
    env[KERNEL_TARGET_ENV] = spec_path;
    env["JAC_LLVM_SHIM"] = _find_shim();
    return env;
}

def run_stage0_child(snapshot_pkg: str, spec_path: str, dst: str) -> int {
    parent = os.path.dirname(snapshot_pkg);
    proc = subprocess.run(
        [sys.executable, "-P", "-c", _STAGE0_CHILD, spec_path, dst, parent],
        env=stage0_child_env(snapshot_pkg, spec_path),
        cwd=parent
    );
    return proc.returncode;
}

def _unit_candidates(spec: KernelTarget) -> list[str] {
    paths = [spec.module_path(m) for m in spec.scope_modules];
    paths.extend(
        os.path.join(spec.`root, *rel.split("/")) for rel in spec.kernel_unit_rel
    );
    return [
        p
        for p in paths
        if os.path.isfile(p)
    ];
}

def unit_sources_before(spec: KernelTarget) -> dict[str, str] {
    import from jaclang.compiler.driver.jir { unit_source_digest }
    return {os.path.realpath(p): unit_source_digest(p) for p in _unit_candidates(spec)};
}

def restamp_stage0_sidecar(
    dst: str, pin: Stage0Pin, target_root: str, before: dict[str, str]
) -> dict[str, object] {
    import from jaclang.jac0core.cache_paths { atomic_write }
    import from jaclang.compiler.backends.native.kernel_resolve {
        LAYOUT_SIDECAR_SUFFIX,
        kernel_options,
        read_sidecar
    }
    import from jaclang.compiler.driver.jir { sidecar_unit_paths, unit_source_digest }
    import from jaclang.compiler.frontend.codeinfo { NATIVE_ABI_VERSION }
    import from jaclang.compiler.driver.compile_options { NATIVE_LINK_MODE_BITCODE }
    sidecar = read_sidecar(dst);
    if sidecar is None {
        raise Stage0Unavailable("the stage-0 build left no layout sidecar");
    }
    ids = sidecar.get("unit_ids");
    units = sidecar_unit_paths(sidecar);
    if not isinstance(ids, list) or not units or len(ids) != len(units) {
        raise Stage0Unavailable("the stage-0 sidecar names no unit identities");
    }
    options = kernel_options();
    sources: dict[str, str] = {};
    policy: dict[str, int] = {};
    for (ident, path) in zip(ids, units) {
        digest = unit_source_digest(path);
        prior = before.get(os.path.realpath(path));
        if prior is not None and prior != digest {
            raise RuntimeError(
                f"{ident} changed while stage 0 built the kernel; rebuild when the "
                "sources are settled"
            );
        }
        sources[str(ident)] = digest;
        policy[str(ident)] = int(options.native_required_for(path));
    }
    stamped = dict(sidecar);
    stamped["builder"] = STAGE0_BUILDER;
    stamped["stage0"] = {"commit": pin.commit, "digest": pin.compiler_digest};
    stamped["abi"] = NATIVE_ABI_VERSION;
    stamped["abi_contract"] = abi_contract_digest(target_root);
    stamped["link_mode"] = str(sidecar.get("link_mode") or NATIVE_LINK_MODE_BITCODE);
    stamped["unit_sources"] = sources;
    stamped["unit_policy"] = policy;
    atomic_write(
        dst + LAYOUT_SIDECAR_SUFFIX,
        json.dumps(stamped, sort_keys=True).encode("utf-8"),
        mode=0o644
    );
    return stamped;
}

def _fall_back(reason: str) -> bool {
    if stage0_strict() {
        import from jaclang.compiler.backends.native.kernel_resolve {
            KernelUnavailable
        }
        raise KernelUnavailable(
            f"stage-0 kernel build failed ({reason}) and JAC_STAGE0_STRICT forbids "
            "the self build; fix the sources or pin stage 0 to \"self\""
        );
    }
    sys.stderr.write(
        f"jac: stage-0 kernel build unavailable ({reason}); building the kernel "
        "with this compiler.\n"
    );
    if os.environ.get("GITHUB_ACTIONS") == "true" {
        sys.stdout.write(
            f"::notice title=stage 0::{reason}; the kernel was built by this compiler\n"
        );
        sys.stdout.flush();
    }
    return False;
}

def _child_failure(code: int) -> str {
    if code == STAGE0_EXIT_UNKNOWN_FORMAT {
        return "stage 0 does not read this kernel target format";
    }
    if code == STAGE0_EXIT_FOREIGN_COMPILER {
        return "the stage-0 child did not run the snapshot's compiler";
    }
    return f"the stage-0 child exited with status {code}";
}

def build_kernel_by_pin(
    dst: str, spec: (KernelTarget | None) = None, link_mode: str = KERNEL_DEV_LINK_MODE
) -> bool {
    try {
        pin = read_stage0_pin();
    } except (Stage0PinError, OSError) as e {
        return _fall_back(f"unreadable pin: {e}");
    }
    if pin.is_self() {
        return False;
    }
    import from jaclang.compiler.kernel_target {
        active_kernel_target,
        with_link_mode,
        write_kernel_target
    }
    import from jaclang.compiler.backends.native.kernel_stage0 { running_kernel_target }
    spec = with_link_mode(
        spec or active_kernel_target() or running_kernel_target(), link_mode
    );
    spec_path = f"{dst}.target.json";
    try {
        (repo, prefix) = checkout_repo();
        snapshot_pkg = provision_stage0(pin, repo, prefix);
        trips = native_tree_trips(pin, repo, prefix)
            + file_guard_trips(pin, snapshot_pkg, spec.`root);
        if trips {
            return _fall_back("; ".join(trips));
        }
        write_kernel_target(spec, spec_path);
        before = unit_sources_before(spec);
        code = run_stage0_child(snapshot_pkg, spec_path, dst);
        if code != 0 {
            return _fall_back(_child_failure(code));
        }
        restamp_stage0_sidecar(dst, pin, spec.`root, before);
        return True;
    } except (Stage0Unavailable, OSError, tarfile.TarError) as e {
        return _fall_back(str(e));
    } finally {
        try {
            os.remove(spec_path);
        } except OSError {}
    }
}

def pin_for_commit(commit: str) -> Stage0Pin {
    (repo, prefix) = checkout_repo();
    full = _git(repo, ["rev-parse", "--verify", commit + "^{commit}"]);
    pin = Stage0Pin(
        commit=full,
        jaclang_tree=_git(repo, ["rev-parse", f"{full}:{prefix}jaclang"]),
        native_tree=_git(repo, ["rev-parse", f"{full}:{prefix}native"]),
        typeshed_pin=_git(
            repo, ["show", f"{full}:{prefix}jaclang/vendor/typeshed/PIN"]
        ).strip()
    );
    s0_dir = stage0_dir(full);
    import from jaclang.jac0core.cache_paths { FileLock }
    import from jaclang.compiler.driver.jir { compiler_source_digest }
    os.makedirs(os.path.dirname(s0_dir), exist_ok=True);
    lock = FileLock(s0_dir + ".lock");
    lock.acquire();
    try {
        if not _stamp_matches(s0_dir, pin) {
            _extract_snapshot(repo, prefix, pin, s0_dir);
        }
        pin.compiler_digest = compiler_source_digest(os.path.join(s0_dir, "jaclang"));
    } finally {
        lock.release();
    }
    return pin;
}
