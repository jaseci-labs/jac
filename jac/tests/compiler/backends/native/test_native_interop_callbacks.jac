"""Native calls into Python marshal every scalar at its own width and sign.

A callback's ctypes signature is derived from the scalar shape of each type
the boundary analysis recorded: f32 is a C float, u8 an unsigned byte, u64 an
unsigned 64-bit integer, and so on. A type with no C form at this boundary
(bytes, a container, a union) is refused at compile time (E5093), and the
runtime refuses it again when a record names one. A void return is a
restype-less CFUNCTYPE.

A ctypes callback cannot raise into its native caller, so a call that reaches
a Python function before the module defining it ran stops the process, for
void and value-returning callbacks alike.
"""

import ctypes;
import os;
import subprocess;
import tempfile;
import from tests.support { get_func, jac_command }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.runtime.interop_bridge {
    NativeCallback,
    callback_ctype,
    register_py_callbacks
}

def _fake_register(name: str, address: int) {
    return;
}

test "callback ctypes follow the scalar shape" {
    expected = {
        "int": ctypes.c_int64,
        "float": ctypes.c_double,
        "bool": ctypes.c_bool,
        "str": ctypes.c_char_p,
        "i8": ctypes.c_int8,
        "u8": ctypes.c_uint8,
        "i16": ctypes.c_int16,
        "u16": ctypes.c_uint16,
        "i32": ctypes.c_int32,
        "u32": ctypes.c_uint32,
        "i64": ctypes.c_int64,
        "u64": ctypes.c_uint64,
        "f32": ctypes.c_float,
        "f64": ctypes.c_double
    };
    for (name, ctype) in expected.items() {
        assert callback_ctype(name) is ctype , (
            f"{name} must cross as {ctype}, got {callback_ctype(name)}"
        );
    }
    for name in ("bytes", "usize", "isize", "list[int]", "None") {
        assert callback_ctype(name) is None , f"{name} has no C form here";
    }
}

test "void and sized callbacks register and reach their Python function" {
    seen: list[tuple[any, ...]] = [];
    def sink(a: int, b: int) {
        seen.append((a, b));
    }
    def wide(n: int, big: int) -> float {
        return float(n) + big / 2;
    }
    cbs: list[object] = [];
    register_py_callbacks(
        [
            NativeCallback(
                name="sink",
                symbol="sym_sink",
                ret_type="None",
                param_types=["int", "u32"]
            ),
            NativeCallback(
                name="wide",
                symbol="sym_wide",
                ret_type="f64",
                param_types=["i8", "u64"]
            )
        ],
        {"sym_sink": sink, "sym_wide": wide},
        cbs,
        _fake_register
    );
    assert len(cbs) == 2 , "every marshallable signature must register";
    assert cbs[0](1, 2) is None , "a void callback returns None";
    assert seen == [(1, 2)] , f"the registered sink must run, saw {seen}";
    assert cbs[1](-3, 18446744073709551614) == -3 + 9223372036854775807.0;
}

test "signatures no ctypes type can carry still refuse" {
    for bad in [
        NativeCallback(
            name="bad", symbol="s", ret_type="None", param_types=["list[int]"]
        ),
        NativeCallback(name="bad", symbol="s", ret_type="int | str", param_types=[]),
        NativeCallback(name="bad", symbol="s", ret_type="None", param_types=["None"]),
        NativeCallback(name="bad", symbol="s", ret_type="None", param_types=["bytes"]),
        NativeCallback(name="bad", symbol="s", ret_type="usize", param_types=[])
    ] {
        refused = False;
        try {
            register_py_callbacks([bad], {}, [], _fake_register);
        } except RuntimeError {
            refused = True;
        }
        assert refused , (
            f"{bad.ret_type} / {bad.param_types} cannot cross the FFI boundary"
        );
    }
}

test "native code passes sized scalars to Python at their own width" {
    tmp = tempfile.mkdtemp(prefix="jac_sized_cb_");
    files = {
        "jac.toml": '[placement.pins]\nhelper = "server"\n"main.sized" = "native"\n',
        "helper.jac": (
            "def:pub mix(x: f32, n: i8, b: u8, big: u64) -> f64 {\n"
            + "    return 0.0;\n"
            + "}\n\n"
            + "def:pub half(x: f32) -> f32 {\n"
            + "    return x;\n"
            + "}\n"
        ),
        "main.jac": (
            "import from helper { mix, half }\n\n"
            + "def:pub sized -> f64 {\n"
            + "    return mix(f32(1.5), i8(-3), u8(250), u64(9223372036854775808))\n"
            + "        + float(half(f32(3.0)));\n"
            + "}\n"
        )
    };
    for (fname, src) in files.items() {
        with open(os.path.join(tmp, fname), "w") as f {
            f.write(src);
        }
    }
    prog = JacProgram();
    mod = prog.compile(os.path.join(tmp, "main.jac"), options=CompileOptions());
    assert not prog.errors_had , [str(e) for e in prog.errors_had];
    bindings = mod.gen.interop_manifest.bindings;
    seen: list[tuple[any, ...]] = [];
    def mix(x: float, n: int, b: int, big: int) -> float {
        seen.append((x, n, b, big));
        return x + n + b + big // 4294967296;
    }
    def half(x: float) -> float {
        seen.append((x, ));
        return x / 2;
    }
    table = mod.gen.interop_py_funcs;
    table[bindings["mix"].symbol] = mix;
    table[bindings["half"].symbol] = half;
    sized = get_func(mod.gen.native_engine, "sized", ctypes.c_double);
    result = sized();
    assert (1.5, -3, 250, 9223372036854775808) in seen , (
        f"each argument must arrive at its declared width and sign: {seen}"
    );
    assert (3.0, ) in seen , f"an f32 argument must arrive as a float: {seen}";
    assert result == 1.5 - 3 + 250 + 2147483648 + 1.5 , (
        f"the f64 and f32 returns must come back intact, got {result}"
    );
}

"""Run a script that calls an unregistered callback; return the process."""
def _call_unregistered(ret_type: str) -> subprocess.CompletedProcess {
    tmp = tempfile.mkdtemp(prefix="jac_unregistered_cb_");
    script = os.path.join(tmp, "ghost_call.jac");
    with open(script, "w") as f {
        f.write(
            "import from jaclang.runtime.interop_bridge {\n"
                + "    register_py_callbacks,\n"
                + "    NativeCallback\n"
                + "}\n"
                + "def reg(name: str, address: int) {\n"
                + "    return;\n"
                + "}\n"
                + "with entry {\n"
                + "    cbs: list[object] = [];\n"
                + "    register_py_callbacks(\n"
                + f"        [NativeCallback(name='ghost', symbol='sym_ghost', ret_type='{ret_type}', param_types=[])],\n"
                + "        {},\n"
                + "        cbs,\n"
                + "        reg\n"
                + "    );\n"
                + "    cb = cbs[0];\n"
                + "    cb();\n"
                + "    print('UNREACHABLE: the call carried on');\n"
                + "}\n"
        );
    }
    return subprocess.run(
        jac_command("run", script), capture_output=True, text=True, timeout=300
    );
}

test "calling an unregistered callback stops the process, not a 0 return" {
    for ret_type in ("int", "None") {
        result = _call_unregistered(ret_type);
        assert "UNREACHABLE" not in result.stdout , (
            f"a {ret_type} callback must not carry on without its function"
        );
        assert result.returncode != 0 , result.stderr;
        assert "ghost" in result.stderr , (
            f"the abort must name the unregistered function, got: {result.stderr[:300]}"
        );
    }
}
