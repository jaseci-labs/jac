import json;
import platform;
import subprocess;
import tempfile;
import from pathlib { Path }


def run_cmd(cmd: list, cwd: object = None) -> subprocess.CompletedProcess {
    proc = subprocess.run(
        [str(c) for c in cmd],
        cwd=str(cwd) if cwd is not None else None,
        capture_output=True,
        text=True
    );
    if proc.returncode != 0 {
        joined = " ".join([str(c) for c in cmd]);
        raise RuntimeError(
            f"command failed (exit {proc.returncode}): {joined}\n{proc.stderr.strip()}"
        );
    }
    return proc;
}


def binder_cmd(ws: Path) -> list {
    for profile in ("release", "debug") {
        exe = ws / "target" / profile / "jac-bridge-binder";
        if exe.is_file() {
            return [exe];
        }
        win = exe.with_suffix(".exe");
        if win.is_file() {
            return [win];
        }
    }
    return [
        "cargo",
        "run",
        "--quiet",
        "--release",
        "--manifest-path",
        ws / "Cargo.toml",
        "-p",
        "jac-bridge-binder",
        "--"
    ];
}


def resolved_crate_version(proj: Path, crate: str) -> str {
    meta = json.loads(
        str(run_cmd(["cargo", "metadata", "--format-version", "1"], cwd=proj).stdout)
    );
    for pkg in meta.get("packages", []) {
        if pkg.get("name") == crate {
            return str(pkg.get("version"));
        }
    }
    raise RuntimeError(f"crate '{crate}' not found in resolved dependency graph");
}


def target_triple -> str {
    try {
        out = str(run_cmd(["rustc", "-vV"]).stdout);
        for line in out.splitlines() {
            if line.startswith("host:") {
                return line.split(":", 1)[1].strip();
            }
        }
    } except Exception { }
    import from jaclang.compiler.rust_bridge._finder { _target_triple }
    return _target_triple();
}


def run_build_pipeline(crate: str, version: str, ws: Path) -> tuple {
    import from jaclang.compiler.rust_bridge._finder { crate_lib_stem }
    stem = crate_lib_stem(crate);
    jac_bridge_path = (ws / "jac-bridge").resolve();
    work = Path(tempfile.mkdtemp(prefix="jac-bridge-build-"));
    proj = work / "fetch";
    proj.mkdir(parents=True, exist_ok=True);
    run_cmd(["cargo", "init", "--lib", "--quiet", "--name", "bridgefetch"], cwd=proj);
    add_spec = crate if version in ("", "*") else f"{crate}@{version}";
    run_cmd(["cargo", "add", "--quiet", add_spec], cwd=proj);
    exact = resolved_crate_version(proj, crate);
    run_cmd(
        [
            "cargo",
            "+nightly",
            "rustdoc",
            "-p",
            crate,
            "-Z",
            "unstable-options",
            "--output-format",
            "json",
            "--quiet"
        ],
        cwd=proj
    );
    doc_json = proj / "target" / "doc" / f"{stem}.json";
    if not doc_json.is_file() {
        raise RuntimeError(f"rustdoc did not produce {doc_json}");
    }
    gen = work / "gen";
    gen.mkdir(parents=True, exist_ok=True);
    run_cmd(
        binder_cmd(ws) + [doc_json, "--out", gen, "--jac-bridge", jac_bridge_path],
        cwd=ws
    );
    run_cmd(
        [
            "cargo",
            "build",
            "--release",
            "--quiet",
            "--manifest-path",
            gen / "Cargo.toml"
        ],
        cwd=gen
    );
    return (exact, gen, work);
}
