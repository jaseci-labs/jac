"""The native floors are artifacts the router resolves per target: the C floor
archives (`c-floor@<os-arch>`), the static musl runtime (`musl@<os-arch>`) and
the wasm32 libc bitcode (`wasm-libc`). Each is found in the sealed image's
`python/floor`, the checkout's build trees, or the kit's `python/floor`, and
only for the architecture asked for. These build each layout synthetically in
a temp dir so resolution is covered without a real Python or Zig build.
"""

import hashlib;
import os;
import tempfile;
import from unittest.mock { patch }
import jaclang.artifacts.router as router;
import jaclang.compiler.backends.native.floors as floors;
import from jaclang.artifacts.model { Source }
import from jaclang.artifacts.kit { osarch }

def _mk(path: str) -> str {
    os.makedirs(path, exist_ok=True);
    return path;
}

def _touch(path: str, data: bytes = b"") -> str {
    _mk(os.path.dirname(path));
    with open(path, "wb") as f {
        f.write(data);
    }
    return path;
}

def _unsealed -> any {
    return patch("jaclang.jac0core.sealed._jaclang_image", return_value=None);
}

test "osarch names a triple the way the build trees do" {
    assert osarch("x86_64-unknown-linux-gnu") == "linux-x86_64";
    assert osarch("aarch64-unknown-linux-musl") == "linux-aarch64";
    assert osarch("arm64-apple-macosx11.0.0") == "macos-aarch64";
    assert osarch("wasm32-unknown-unknown") == "wasm32";
}

test "the checkout's C floor resolves per arch, never across arches" {
    repo = tempfile.mkdtemp();
    x86 = _mk(
        os.path.join(
            repo, ".python-build", "cpython", "linux-x86_64", "python", "build", "lib"
        )
    );
    _touch(os.path.join(x86, "libssl.a"));
    with patch.object(floors, "_repo_root", return_value=repo), _unsealed() {
        found = floors.CFloorArtifact(variant="linux-x86_64").probe_checkout();
        assert found.found is not None and found.found.path == x86;
        other = floors.CFloorArtifact(variant="linux-aarch64").probe_checkout();
        assert other.found is None , "an aarch64 build must never link the x86_64 floor";
    }
}

test "the running interpreter's own Python build supplies the C floor" {
    repo = tempfile.mkdtemp();
    libs: dict[str, str] = {};
    for variant in ("cpython", "jacpython") {
        libs[variant] = _mk(
            os.path.join(
                repo, ".python-build", variant, "linux-x86_64", "python", "build", "lib"
            )
        );
        _touch(os.path.join(libs[variant], "libz.a"));
    }
    with patch.object(floors, "_repo_root", return_value=repo) {
        with patch.object(
            floors, "_running_python_variant", return_value="jacpython"
        ) {
            found = floors.CFloorArtifact(variant="linux-x86_64").probe_checkout();
        }
    }
    assert found.found is not None and found.found.path == libs["jacpython"];
}

test "a sealed image and a kit serve their own python/floor" {
    rt = tempfile.mkdtemp();
    floor = _mk(os.path.join(rt, "python", "floor"));
    _touch(os.path.join(floor, "linux-x86_64", "libssl.a"));
    _touch(os.path.join(floor, "linux-aarch64", "musl", "libc.a"));
    _touch(os.path.join(floor, "wasm32", "libc", "libc.bc"));
    with patch.object(floors, "runtime_floor_root", return_value=floor) {
        with patch("jaclang.jac0core.sealed._jaclang_image", return_value=object()) {
            c = floors.CFloorArtifact(variant="linux-x86_64").probe_sealed();
            assert c is not None
                and c.found is not None
                and c.found.source == Source.SEALED;
            m = floors.MuslArtifact(variant="linux-aarch64").probe_sealed();
            assert m is not None and m.found is not None , "a kit bundles the cross musl too";
            w = floors.WasmLibcArtifact().probe_sealed();
            assert w is not None and w.found is not None;
        }
        kit = floors.MuslArtifact(variant="linux-aarch64").probe_kit();
        assert kit.found is not None and kit.found.source == Source.KIT;
        absent = floors.MuslArtifact(variant="linux-x86_64").probe_kit();
        assert absent.found is None;
    }
}

test "a runtime being sealed serves the floor staged beside it" {
    import jaclang;
    rt = tempfile.mkdtemp();
    pkg = _touch(os.path.join(rt, "site", "jaclang", "__init__.py"));
    staged = _mk(os.path.join(rt, "python", "floor", "macos-aarch64"));
    _touch(os.path.join(staged, "libcrypto.a"));
    with patch("jaclang.artifacts.kit.kit_image", return_value=None) {
        with patch.object(jaclang, "__file__", pkg) {
            found = floors.CFloorArtifact(variant="macos-aarch64").probe_kit();
            assert found.found is not None and found.found.path == staged;
        }
        bare = _touch(
            os.path.join(tempfile.mkdtemp(), "site", "jaclang", "__init__.py")
        );
        with patch.object(jaclang, "__file__", bare) {
            assert floors.CFloorArtifact(variant="macos-aarch64").probe_kit().found
                is None;
        }
    }
}

test "a wasm libc floor is current only while its manifest matches wasm_rt" {
    libc = tempfile.mkdtemp();
    _touch(os.path.join(libc, "libc.bc"));
    src = os.path.join(floors.wasm_rt_src_dir(), "jac_abi64.c");
    with open(src, "rb") as f {
        digest = hashlib.sha256(f.read()).hexdigest();
    }
    manifest = os.path.join(libc, floors.WASM_FLOOR_MANIFEST);
    unchecked = floors._wasm_probe(libc, Source.CHECKOUT);
    assert unchecked.found is None and "manifest" in unchecked.drift[0];
    _touch(manifest, f"{digest} jac_abi64.c\n".encode());
    assert floors._wasm_probe(libc, Source.CHECKOUT).found is not None;
    _touch(manifest, f"{'0' * 64} jac_abi64.c\n".encode());
    moved = floors._wasm_probe(libc, Source.CHECKOUT);
    assert moved.found is None and moved.drift == ["wasm_rt/jac_abi64.c changed"];
}

test "static linking asks the router for the target's floors" {
    import from jaclang.compiler.backends.native.native_link {
        floor_lib_dir,
        musl_lib_dir
    }
    repo = tempfile.mkdtemp();
    lib = _mk(
        os.path.join(
            repo, ".python-build", "cpython", "linux-aarch64", "python", "build", "lib"
        )
    );
    _touch(os.path.join(lib, "libssl.a"));
    musl = _mk(os.path.join(repo, ".pbs-build", "linux-aarch64", "musl", "lib"));
    _touch(os.path.join(musl, "libc.a"));
    router.forget();
    try {
        with patch.object(floors, "_repo_root", return_value=repo), _unsealed() {
            with patch.object(floors, "runtime_floor_root", return_value="") {
                assert floor_lib_dir("aarch64-unknown-linux-gnu") == lib;
                assert musl_lib_dir("aarch64-unknown-linux-musl") == musl;
                assert musl_lib_dir("x86_64-unknown-linux-musl") is None;
            }
        }
    } finally {
        router.forget();
    }
}
