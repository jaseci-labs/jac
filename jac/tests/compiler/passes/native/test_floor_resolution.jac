"""Unit gate for the floor locator's two shipping shapes (#6978 Phase 0.2).

`nacompile` static-links a bundled C floor from a `.a` it resolves at compile
time. _resolve_floor_dir / _resolve_ca_bundle map the jaclang package root + a
target triple to that archive dir (and the CA bundle) under either the dev
`.pbs-build` tree or the installed `python/floor` payload layout (staged into the
runtime cache by `mkpayload`). These build each layout synthetically in a temp
dir so the resolution is covered without a real pbs build or a relocated jaclang
-- the production lookups (_floor_lib_dir / _floor_ca_bundle) just feed the real
`jaclang.__file__`-derived root into these resolvers.
"""

import os;
import tempfile;
import from jaclang.cli.commands.nacompile {
    _resolve_floor_dir,
    _resolve_ca_bundle,
    _floor_lib_dir,
    _floor_ca_bundle
}


"""mkdir -p `path`, returning it."""
def _mk(path: str) -> str {
    os.makedirs(path, exist_ok=True);
    return path;
}


test "installed payload: python/floor/<osarch> resolves by arch (#6978 0.2)" {
    rt = tempfile.mkdtemp();
    pkg_root = _mk(os.path.join(rt, "site"));  # jaclang pkg root == <rt>/site
    floor = _mk(os.path.join(rt, "python", "floor", "linux-x86_64"));
    got = _resolve_floor_dir(pkg_root, "x86_64-unknown-linux-gnu");
    assert got == floor , f"expected {floor}, got {got}";
}


test "installed payload: cross-arch target does not match host floor (#6978 0.2)" {
    rt = tempfile.mkdtemp();
    pkg_root = _mk(os.path.join(rt, "site"));
    _mk(os.path.join(rt, "python", "floor", "linux-x86_64"));
    # Only an x86_64 floor is staged; an arm64 target must NOT grab it -- linking
    # host-arch archives into a cross-arch binary is broken, so this stays None.
    got = _resolve_floor_dir(pkg_root, "aarch64-unknown-linux-gnu");
    assert got is None , f"expected None for cross-arch, got {got}";
}


test "dev tree: .pbs-build/<osarch>/python/build/lib resolves (#6978 0.2)" {
    base = tempfile.mkdtemp();
    libdir = _mk(
        os.path.join(base, ".pbs-build", "linux-x86_64", "python", "build", "lib")
    );
    got = _resolve_floor_dir(base, "x86_64-unknown-linux-gnu");
    assert got == libdir , f"expected {libdir}, got {got}";
}


test "no floor anywhere resolves to None (#6978 0.2)" {
    base = tempfile.mkdtemp();
    got = _resolve_floor_dir(base, "x86_64-unknown-linux-gnu");
    assert got is None , f"expected None, got {got}";
}


test "JAC_NATIVE_FLOOR_DIR overrides resolution (#6978 0.2)" {
    override = tempfile.mkdtemp();
    prev = os.environ.get("JAC_NATIVE_FLOOR_DIR", None);
    os.environ["JAC_NATIVE_FLOOR_DIR"] = override;
    try {
        got = _floor_lib_dir("x86_64-unknown-linux-gnu");
        assert got == override , f"env override ignored: {got}";
    } finally {
        if prev is None {
            os.environ.pop("JAC_NATIVE_FLOOR_DIR", None);
        } else {
            os.environ["JAC_NATIVE_FLOOR_DIR"] = prev;
        }
    }
}


test "CA bundle resolves from installed python/floor/cacert.pem (#6978 0.2)" {
    rt = tempfile.mkdtemp();
    pkg_root = _mk(os.path.join(rt, "site"));
    _mk(os.path.join(rt, "python", "floor"));
    ca = os.path.join(rt, "python", "floor", "cacert.pem");
    with open(ca, "w") as f {
        f.write("# test bundle\n");
    }
    got = _resolve_ca_bundle(pkg_root);
    assert got == ca , f"expected {ca}, got {got}";
}


test "CA bundle is None when neither installed nor dev bundle exists (#6978 0.2)" {
    pkg_root = _mk(os.path.join(tempfile.mkdtemp(), "site"));
    got = _resolve_ca_bundle(pkg_root);
    assert got is None , f"expected None, got {got}";
}


test "JAC_NATIVE_CA_BUNDLE overrides CA resolution (#6978 0.2)" {
    d = tempfile.mkdtemp();
    override = os.path.join(d, "my-ca.pem");
    with open(override, "w") as f {
        f.write("# override\n");
    }
    prev = os.environ.get("JAC_NATIVE_CA_BUNDLE", None);
    os.environ["JAC_NATIVE_CA_BUNDLE"] = override;
    try {
        got = _floor_ca_bundle();
        assert got == override , f"env override ignored: {got}";
    } finally {
        if prev is None {
            os.environ.pop("JAC_NATIVE_CA_BUNDLE", None);
        } else {
            os.environ["JAC_NATIVE_CA_BUNDLE"] = prev;
        }
    }
}
