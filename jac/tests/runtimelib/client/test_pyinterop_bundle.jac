"""Phase 3.3.4: prove the py-interop bundle path ships an EXTERNAL wheel.

Where the 3.0-3.2 pyinterop tests only used bundled stdlib (binascii/operator),
this proves the packaging half (FFI-LANES 3.3.1/3.3.2): an na host is nacompiled,
a CUSTOM slim runtime payload is assembled with a pip-installed wheel
(_assemble_pyinterop_payload -> __extractrt + pip install --target site-packages
+ slim + patchelf + repack), grafted onto the host (__graftrt <bin> <payload>),
and the resulting single file boots embedded CPython and imports the wheel with
no Python on the machine.

orjson is the probe: a small single-.so binary wheel, so a clean import proves
wheel-install + patchelf-RPATH + the window_log=24 repack + boot all line up.
polars/cryptography smoke tests stay in 3.5. The wheel is imported from the
embedded interpreter (jpy_PyRun_SimpleString) so the marker asserts it is on the
grafted binary's own module_search_paths (embed.zig's site-packages entry).

Runs only where the fused runtime boots (needs the __graftrt trailer a `zig
build` jac carries) AND where pip can reach a wheel for orjson on the host
platform, same gating as the sibling pyinterop tests. host libc must match.
"""
import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from jaclang.runtimelib.client.targets.desktop.desktop_build {
    _jac_bin,
    _stage_pyembed_shim
}
import from jaclang.cli.commands.project { _assemble_pyinterop_payload }


def _orjson_host_src -> str {
    # An na host: boot the runtime, then import the pip-installed orjson wheel
    # from the embedded interpreter and round-trip a value through it. Markers
    # print from the Python side; exit codes 1-2 stage the boot failure.
    return (
        "import sys;\n"
        "import from python { py_boot }\n"
        "import from jacpyembed { def jpy_PyRun_SimpleString(cmd: str) -> i32; }\n"
        "with entry {\n"
        "    rc: i32 = py_boot();\n"
        "    if rc != 0 { sys.exit(1); }\n"
        "    st: i32 = jpy_PyRun_SimpleString(\n"
        "        \"import orjson\\n\"\n"
        "        \"print('ORJSON_IMPORT_OK', orjson.__version__, flush=True)\\n\"\n"
        "        \"ok = orjson.loads(orjson.dumps([1, 2, 3])) == [1, 2, 3]\\n\"\n"
        "        \"print('ORJSON_ROUNDTRIP_OK' if ok else 'ORJSON_ROUNDTRIP_BAD', flush=True)\\n\"\n"
        "    );\n"
        "    if st != 0 { sys.exit(2); }\n"
        "}\n"
    );
}


test "na binary bundles + boots an external orjson wheel with no host python" {
    jac = _jac_bin();
    tmp = tempfile.mkdtemp();
    try {
        out_dir = Path(tmp);
        # The shim rides $ORIGIN-adjacent so the host's `import from jacpyembed`
        # resolves the sibling libjacpyembed at load (ships in the fused payload).
        _stage_pyembed_shim(out_dir);
        (out_dir / "orjhost.na.jac").write_text(_orjson_host_src());
        binary = out_dir / "pyinterop_orjson";
        comp = subprocess.run(
            [jac, "nacompile", "orjhost.na.jac", "-o", "pyinterop_orjson"],
            cwd=tmp,
            capture_output=True,
            text=True,
            timeout=300
        );
        assert comp.returncode == 0 and binary.exists() , f"nacompile failed:\n{comp.stderr}";

        # Assemble a CUSTOM slim payload carrying the orjson wheel, then graft it
        # onto the host (a payload arg -> graftRuntimeFrom, not the base suffix).
        stage = Path(tempfile.mkdtemp(prefix="orjstage-", dir=tmp));
        payload = _assemble_pyinterop_payload(["orjson"], stage);
        assert payload is not None and payload.exists() , "orjson payload assembly failed";

        graft = subprocess.run(
            [jac, "__graftrt", str(binary), str(payload)],
            capture_output=True,
            text=True,
            timeout=120
        );
        assert graft.returncode == 0 , f"__graftrt failed:\n{graft.stderr}";

        run = subprocess.run(
            [str(binary)], cwd=tmp, capture_output=True, text=True, timeout=120
        );
        assert run.returncode == 0 , (
            f"orjson binary exited {run.returncode}\n"
            f"stdout:\n{run.stdout}\nstderr:\n{run.stderr}"
        );
        for marker in ["ORJSON_IMPORT_OK", "ORJSON_ROUNDTRIP_OK"] {
            assert marker in run.stdout , (
                f"marker {marker} missing\nstdout:\n{run.stdout}\nstderr:\n{run.stderr}"
            );
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
