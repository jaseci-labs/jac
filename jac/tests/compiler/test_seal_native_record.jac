"""A sealed package records its native units and one linked artifact (#8943).

`jac precompile --seal` over an app with a native pin compiles the pinned
module as a native unit, links the package's native artifact through the
link plan, and writes manifest format 9's `native` record: the units by
source path with their interface digests, and the artifact with its sha256,
layout digest and plan digest. `SealedImage.verify_native` refuses an image
whose record and artifact disagree.
"""

import hashlib;
import json;
import os;
import sys;
import tempfile;
import from pathlib { Path }
import from jaclang.jac0core.sealed { MANIFEST_FORMAT, SealedImage, load_image }
import from jaclang.compiler.driver.schedules { native_pipeline_available }


"""Seal `src_root` the way the build's seal stage does, in a child process:
the `precompile` command is the build's engine, not a sealed kit's command,
and it ends its process itself."""
def _seal(src_root: str) -> tuple[int, str] {
    import subprocess;
    code = (
        "import sys\n"
        "sys.argv = ['precompile', sys.argv[1], '--seal', '--jobs=0']\n"
        "from jaclang.dist.precompile_bytecode import main\n"
        "main()\n"
    );
    run = subprocess.run(
        [sys.executable, "-P", "-c", code, src_root], capture_output=True, text=True
    );
    return (run.returncode, run.stdout + run.stderr);
}


def _app(tmp: str) -> str {
    src_root = os.path.join(tmp, "src");
    pkg = os.path.join(src_root, "natapp");
    os.makedirs(pkg);
    Path(os.path.join(pkg, "__init__.jac")).write_text("");
    Path(os.path.join(pkg, "jac.toml")).write_text(
        "[project]\nname = \"natapp\"\nentry-point = \"main.jac\"\n"
        "kind = \"cli\"\n\n[placement.pins]\nfast = \"native\"\n"
    );
    Path(os.path.join(pkg, "fast.jac")).write_text(
        "def:pub triple(v: int) -> int {\n    return v * 3;\n}\n\n"
        "def add(a: int, b: int) -> int {\n    return a + b;\n}\n"
    );
    Path(os.path.join(pkg, "main.jac")).write_text(
        "import from fast { add, triple }\n\n"
        "with entry {\n    print(add(triple(2), 1));\n}\n"
    );
    return src_root;
}


test "the seal records the native unit and its artifact" {
    (ok, why) = native_pipeline_available();
    if not ok {
        import pytest;
        pytest.skip(why);
    } else {
        with tempfile.TemporaryDirectory(prefix="jac-seal-native-") as tmp {
            src_root = _app(tmp);
            (code, out) = _seal(src_root);
            assert code == 0 , out;
            pkg = os.path.join(src_root, "natapp");
            manifest = json.loads(
                Path(pkg, "_precompiled", "MANIFEST.json").read_text()
            );
            assert manifest["format"] == MANIFEST_FORMAT;
            native = manifest.get("native");
            assert native , "an app with a native pin must seal a native record";
            assert "fast.jac" in native["units"] , native["units"].keys();
            unit = native["units"]["fast.jac"];
            assert unit["jir"] == "fast.jir" and len(unit["iface_digest"]) == 64;
            artifact = native["artifact"];
            lib = Path(pkg, artifact["path"]);
            assert lib.is_file() , f"missing artifact {lib}";
            assert artifact["sha256"] == hashlib.sha256(lib.read_bytes()).hexdigest();
            sidecar = json.loads(Path(str(lib) + ".layout.json").read_text());
            assert sidecar["plan_digest"] == artifact["plan_digest"];
            assert sidecar["layout_digest"] == artifact["layout_digest"];
            image = load_image(os.path.join(pkg, "_precompiled"));
            assert image is not None;
            image.verify_native();
            assert image.native_artifact()["path"] == artifact["path"];
            assert set(image.native_units().keys()) == {"fast.jac"};
            import ctypes;
            import from jaclang.runtime.native_library { shared_engine_for }
            loaded = shared_engine_for(str(lib), artifact);
            assert shared_engine_for(str(lib), artifact) is loaded;
            address = loaded.get_function_address("triple");
            assert address;
            assert ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(address)(2) == 6;
            assert loaded._initialized;
            assert loaded.get_function_address("missing_export") == 0;
            assert not loaded.static_init_symbols;
        }
    }
}


test "a tampered artifact is refused at load" {
    (ok, why) = native_pipeline_available();
    if not ok {
        import pytest;
        pytest.skip(why);
    } else {
        with tempfile.TemporaryDirectory(prefix="jac-seal-native-") as tmp {
            src_root = _app(tmp);
            (code, out) = _seal(src_root);
            assert code == 0 , out;
            pkg = os.path.join(src_root, "natapp");
            manifest = json.loads(
                Path(pkg, "_precompiled", "MANIFEST.json").read_text()
            );
            lib = Path(pkg, manifest["native"]["artifact"]["path"]);
            lib.write_bytes(lib.read_bytes() + b"\0");
            image = load_image(os.path.join(pkg, "_precompiled"));
            assert image is not None;
            raised = False;
            try {
                image.verify_native();
            } except RuntimeError {
                raised = True;
            }
            assert raised , "a native artifact that no longer hashes to its record must be refused";
        }
    }
}
