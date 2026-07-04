import json;
import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }


glob _NIGHTLY = "nightly";


def toolchain_available -> bool {
    return shutil.which("cargo") is not None and shutil.which("rustup") is not None;
}


def workspace_root -> object {
    env = os.environ.get("JAC_BRIDGE_WORKSPACE");
    if env {
        p = Path(env);
        if (p / "jac-bridge").is_dir() {
            return p;
        }
    }
    return None;
}


def _run(cmd: list, cwd: object = None) -> object {
    return subprocess.run(
        [str(c) for c in cmd],
        cwd=str(cwd) if cwd is not None else None,
        capture_output=True,
        text=True
    );
}


def _check(result: object, what: str) {
    if result.returncode != 0 {
        raise RuntimeError(
            f"{what} failed (exit {result.returncode}):\n{result.stderr.strip()}"
        );
    }
}


def _binder_cmd(ws: Path) -> list {
    for profile in ("release", "debug") {
        cand = ws / "target" / profile / "jac-bridge-binder";
        if cand.is_file() {
            return [cand];
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


def _resolved_version(proj: Path, crate: str) -> str {
    result = _run(["cargo", "metadata", "--format-version", "1"], cwd=proj);
    _check(result, "cargo metadata");
    meta = json.loads(result.stdout);
    for pkg in meta.get("packages", []) {
        if pkg.get("name") == crate {
            return pkg.get("version");
        }
    }
    raise RuntimeError(f"crate '{crate}' not found in resolved dependency graph");
}


def build_bridge(crate: str, version: str = "*", workspace: object = None) -> Path {
    if not toolchain_available() {
        raise RuntimeError(
            "Building a Rust bridge requires the Rust toolchain (cargo + rustup). "
            "Install rustup from https://rustup.rs, add a nightly toolchain "
            "(`rustup toolchain install nightly`), and retry."
        );
    }
    if workspace is not None {
        ws = Path(workspace);
        if not (ws / "jac-bridge").is_dir() {
            ws = None;
        }
    } else {
        ws = workspace_root();
    }
    if ws is None {
        raise RuntimeError(
            "Cannot locate the jac-bridge workspace. Set JAC_BRIDGE_WORKSPACE to "
            "the bridges/ directory that contains jac-bridge and jac-bridge-binder."
        );
    }
    stem = crate.replace("-", "_");
    jac_bridge_path = (ws / "jac-bridge").resolve();

    work = Path(tempfile.mkdtemp(prefix="jac-bridge-build-"));
    proj = work / "fetch";
    proj.mkdir(parents=True, exist_ok=True);

    _check(
        _run(["cargo", "init", "--lib", "--quiet", "--name", "bridgefetch"], cwd=proj),
        "cargo init"
    );
    add_spec = crate if version in ("", "*") else f"{crate}@{version}";
    _check(
        _run(["cargo", "add", "--quiet", add_spec], cwd=proj), f"cargo add {add_spec}"
    );

    exact = _resolved_version(proj, crate);

    _check(
        _run(
            [
                "cargo",
                f"+{_NIGHTLY}",
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
        ),
        "cargo rustdoc"
    );
    doc_json = proj / "target" / "doc" / f"{stem}.json";
    if not doc_json.is_file() {
        raise RuntimeError(f"rustdoc did not produce {doc_json}");
    }

    gen = work / "gen";
    gen.mkdir(parents=True, exist_ok=True);
    binder = _binder_cmd(ws);
    _check(
        _run(
            binder + [doc_json, "--out", gen, "--jac-bridge", jac_bridge_path], cwd=ws
        ),
        "jac-bridge-binder"
    );

    _check(
        _run(
            [
                "cargo",
                "build",
                "--release",
                "--quiet",
                "--manifest-path",
                gen / "Cargo.toml"
            ],
            cwd=gen
        ),
        "cargo build (bridge)"
    );

    rel = gen / "target" / "release";
    built = rel / f"libjac_bridge_{stem}.so";
    if not built.is_file() {
        built = rel / f"lib{stem}.so";
    }
    if not built.is_file() {
        raise RuntimeError(
            f"bridge build did not produce a .so under {gen}/target/release"
        );
    }

    import from jaclang.compiler.rust_bridge { install_bridge }
    dest = install_bridge(built, exact);
    shutil.rmtree(work, ignore_errors=True);
    return dest;
}
