"""Compile and execute JacPython's native output-boundary regression.

Run with the checkout compiler: jac run scripts/test_jacpython_native.jac
The driver may use Python; the tested serializer runs in the native library.
"""
import argparse;
import ctypes;
import marshal;
import math;
import from pathlib { Path }
import sys;
import tempfile;


def read_packet(library: any, entry_name: str) -> bytes {
    factory = getattr(library, entry_name);
    factory.restype = ctypes.c_void_p;
    handle = factory();
    if not handle {
        raise AssertionError(f"{entry_name}: null result");
    }
    try {
        size = library.packet_size(handle);
        if size < 0 {
            raise AssertionError(f"{entry_name}: native serialization failed");
        }
        return bytes(library.packet_byte(handle, index) for index in range(size));
    } finally {
        library.jac_release(handle);
    }
}


def verify(library_path: Path) {
    if sys.version_info[:2] != (3, 14) {
        raise RuntimeError("The JacPython output oracle requires CPython 3.14");
    }
    library = ctypes.CDLL(str(library_path));
    library.packet_size.argtypes = [ctypes.c_void_p];
    library.packet_size.restype = ctypes.c_int64;
    library.packet_byte.argtypes = [ctypes.c_void_p, ctypes.c_int64];
    library.packet_byte.restype = ctypes.c_int64;
    library.jac_release.argtypes = [ctypes.c_void_p];
    library.diagnostic_probe.argtypes = [];
    library.diagnostic_probe.restype = ctypes.c_int64;
    assert library.diagnostic_probe() == 0;
    constants = marshal.loads(read_packet(library, "probe_packet"));
    assert constants[:6] == (None, True, 0, -1, -(1 << 63), (1 << 63) - 1);
    assert math.copysign(1, constants[6]) == -1;
    assert constants[7] == 1.2345678901234567;
    assert constants[8] == complex(1.5, -2.5);
    assert constants[9] == "\x00á中";
    assert constants[10] == bytes([0, 255, 128]);
    assert constants[11] is constants[12];
    assert constants[13] == frozenset([7]);
    assert constants[14] == slice(None, 3, None);
    code = marshal.loads(read_packet(library, "code_packet"));
    assert code.co_filename == "probe.py";
    assert code.co_name == "<module>";
    assert code.co_consts == (1, );
    assert eval(code) == 3;
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
            "runtime/python/opcode_meta.jac",
            "compiler/frontend/python/syntax_error.jac",
            "compiler/backends/py/jacpython/marshal_writer.jac"
        ] {
            destination = stage / "native_subject" / relative;
            destination.parent.mkdir(parents=True, exist_ok=True);
            destination.write_text(
                (sources / relative).read_text().replace("jaclang.", "native_subject.")
            );
        }
        fixture = repo
            / "jac/tests/compiler/backends/native/fixtures/jacpython_marshal.jac";
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
