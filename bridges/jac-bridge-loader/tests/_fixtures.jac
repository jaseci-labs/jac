# Shared fixtures for the jac rust-bridge loader test suite.
# Locates the cargo-built bridge .so files and (lazily) loads them into
# auto-generated ctypes modules.
import from pathlib { Path }
import from jaclang.compiler.rust_bridge { load_bridge }


def workspace -> Path {
    # tests/ -> jac-bridge-loader/ -> bridges/ (the cargo workspace root)
    return Path(__file__).resolve().parent.parent.parent;
}


def _find_so(crate: str) -> str {
    ws = workspace();
    stems = (
        f"libjac_bridge_{crate}.so",
        f"libjac_bridge_{crate}.dylib",
        f"jac_bridge_{crate}.dll"
    );
    for stem in stems {
        p = ws / "target" / "release" / stem;
        if p.exists() {
            return str(p);
        }
    }
    raise FileNotFoundError(
        f"libjac_bridge_{crate} not found; run: cargo build --release"
    );
}


def regex_so -> str {
    return _find_so("regex");
}


def owning_so -> str {
    return _find_so("owning");
}


def scalar_so -> str {
    return _find_so("scalar");
}


def map_so -> str {
    return _find_so("map");
}


def list_so -> str {
    return _find_so("list");
}
