import os;
import shutil;
import from pathlib { Path }


def toolchain_available -> bool {
    return shutil.which("cargo") is not None and shutil.which("rustup") is not None;
}


def workspace_root -> Path | None {
    env = os.environ.get("JAC_BRIDGE_WORKSPACE");
    if env {
        p = Path(env);
        if (p / "jac-bridge").is_dir() {
            return p;
        }
    }
    return None;
}


def build_bridge(crate: str, version: str = "*", workspace: object = None) -> Path {
    if not toolchain_available() {
        raise RuntimeError(
            "Building a Rust bridge requires the Rust toolchain (cargo + rustup). "
            "Install rustup from https://rustup.rs, add a nightly toolchain "
            "(`rustup toolchain install nightly`), and retry."
        );
    }
    ws: Path | None = None;
    if workspace is not None {
        cand_ws = Path(str(workspace));
        if (cand_ws / "jac-bridge").is_dir() {
            ws = cand_ws;
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
    import from jaclang.compiler.rust_bridge._build_core { run_build_pipeline }
    import from jaclang.compiler.rust_bridge._finder { built_lib_candidates }
    pipeline = run_build_pipeline(crate, version, ws);
    exact = pipeline[0];
    gen = pipeline[1];
    work = pipeline[2];
    try {
        rel = gen / "target" / "release";
        built: Path | None = None;
        for name in built_lib_candidates(crate) {
            cand = rel / name;
            if cand.is_file() {
                built = cand;
                break;
            }
        }
        if built is None {
            raise RuntimeError(
                f"bridge build did not produce a cdylib "
                f"(.so/.dylib/.dll) under {gen}/target/release"
            );
        }
        import from jaclang.compiler.rust_bridge { install_bridge }
        dest = install_bridge(built, exact);
    } finally {
        shutil.rmtree(work, ignore_errors=True);
    }
    return dest;
}
