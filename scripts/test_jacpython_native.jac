"""Compile and execute JacPython's native output-boundary regression.

Run inside the JacPython runtime: jac run scripts/test_jacpython_native.jac
The driver may use Python; the tested constant writer runs in the native
library and builds objects through the runtime's retained object API.
"""
import argparse;
import ctypes;
import math;
import from pathlib { Path }
import sys;
import tempfile;


def take_object(library: any, entry_name: str) -> any {
    factory = getattr(library, entry_name);
    factory.argtypes = [];
    factory.restype = ctypes.py_object;
    return factory();
}


def verify(library_path: Path) {
    if sys.version_info[:2] != (3, 14) {
        raise RuntimeError("The JacPython output oracle requires CPython 3.14");
    }
    bridge = getattr(ctypes.pythonapi, "_PyJac_CompilerBridgeVersion", None);
    if bridge is None or bridge() != 4 {
        raise RuntimeError(
            "The JacPython output oracle runs inside the JacPython runtime (bridge 4)"
        );
    }
    library = ctypes.PyDLL(str(library_path), mode=ctypes.RTLD_GLOBAL);
    library.diagnostic_probe.argtypes = [];
    library.diagnostic_probe.restype = ctypes.c_int64;
    assert library.diagnostic_probe() == 0;
    library.integer_probe.argtypes = [];
    library.integer_probe.restype = ctypes.c_int64;
    assert library.integer_probe() == 0;
    constants = take_object(library, "probe_constants");
    assert constants[:6] == (None, True, 0, -1, -(1 << 63), (1 << 63) - 1);
    assert math.copysign(1, constants[6]) == -1;
    assert constants[7] == 1.2345678901234567;
    assert constants[8] == complex(1.5, -2.5);
    assert constants[9] == "\x00á中";
    assert constants[10] == bytes([0, 255, 128]);
    assert constants[11] == constants[12] == "repeat";
    assert constants[13] == frozenset([7]);
    assert constants[14] == slice(None, 3, None);
    assert constants[15] == 1 << 100;
    assert constants[16] == -(1 << 100);
    assert constants[17] == -(1 << 63);
    assert constants[18] == constants[11];
    assert constants[19] == constants[7];
    assert constants[20] == 1.2345678901234569;
    assert constants[20] != constants[19];
    assert math.copysign(1, constants[21]) == 1;
    code = take_object(library, "code_object");
    assert code.co_filename == "probe.py";
    assert code.co_name == "<module>";
    assert code.co_consts == (1, );
    assert eval(code) == 3;
    nested = take_object(library, "nested_code_objects");
    assert nested[0] is not nested[1];
    assert nested[0].co_consts == nested[1].co_consts;
    assert nested[0].co_filename is nested[1].co_filename;
    arithmetic = take_object(library, "integer_arithmetic");
    assert arithmetic
        == (
            1 << 63,
            1 << 63,
            0,
            (1 << 100) - 1,
            -(1 << 100) + 1,
            float((1 << 100) + (1 << 47)),
            float((1 << 100) + (1 << 47) + 1)
        );
    print("Native JacPython constants and code-object boundary passed.", flush=True);
}


def main -> int {
    parser = argparse.ArgumentParser(description=__doc__);
    parser.add_argument("--verify-library", `type=Path);
    args = parser.parse_args();
    if args.verify_library {
        verify(args.verify_library);
        return 0;
    }
    repo = Path(__file__).resolve().parents[1];
    sources = repo / "jac/jaclang";
    with tempfile.TemporaryDirectory(prefix="jacpython-native-") as temporary {
        stage = Path(temporary);
        # Keep these compilation units out of the compiler's own self-host
        # program. Preserve the package hierarchy and never edit the checkout.
        for relative in [
            "runtime/python/objects.jac",
            "runtime/python/compiler_integer.jac",
            "runtime/python/opcode_meta.jac",
            "runtime/python/capi.jac",
            "runtime/python/constant_keys.jac",
            "runtime/python/constant_output.jac",
            "compiler/frontend/python/syntax_error.jac"
        ] {
            destination = stage / "native_subject" / relative;
            destination.parent.mkdir(parents=True, exist_ok=True);
            destination.write_text(
                (sources / relative).read_text().replace("jaclang.", "native_subject.")
            );
        }
        fixture = repo
            / "jac/tests/compiler/backends/native/fixtures/jacpython_constants.jac";
        entry_name = stage / "probe.jac";
        entry_name.write_text(
            fixture.read_text().replace("jaclang.", "native_subject.")
        );
        (stage / "jac.toml").write_text('[placement]\ndefault_codespace = "server"\n');
        library_path = stage / "probe.so";
        # Reuse this process's loaded compiler, including checkout backend fixes.
        import from jaclang.cli.commands.native_build { native_build }
        import contextlib;
        import io;
        output = io.StringIO();
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output) {
            status = native_build(
                str(entry_name),
                output=str(library_path),
                lib=True,
                memory="managed",
                no_ir_cache=True
            );
        }
        build_output = output.getvalue();
        print(build_output, flush=True);
        if status or "demoting " in build_output or not library_path.is_file() {
            raise AssertionError(
                "Native output-boundary build failed or demoted a function"
            );
        }
        verify(library_path);
    }
    return 0;
}

with entry {
    sys.exit(main());
}
