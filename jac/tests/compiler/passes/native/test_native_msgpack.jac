"""Native codegen tests for the serde wide-lane MessagePack codec (FFI-LANES 2.5).

The shared codec (`jac/jaclang/compiler/rust_bridge/_msgpack.jac`) is inlined
into each synthesized bridge, so these tests compile an inlined copy
(`fixtures/msgpack_encode.na.jac`) and exercise the encoder end to end.

The encoder is the wide-PARAM half: it walks a recursive `JacValue` tree and
returns a MessagePack `bytes` blob, driving the `def -> bytes` return path plus
recursive `bytes + bytes` concatenation (#7470/#7472). Non-minimal integer
widths are intentional -- `rmp_serde::from_slice` accepts any valid encoding.
"""

import ctypes;
import os;
import from pathlib { Path }
import from jaclang.jac0core.program { JacProgram }
import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.native.llvm.binding { ExecutionEngine }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

"""Compile a .na.jac fixture and return the JIT engine."""
def compile_native(fixture: str) -> tuple[ExecutionEngine, uni.Module] {
    prog = JacProgram();
    ir = prog.compile(file_path=str(os.path.join(FIXTURES, fixture)));
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    return (eng, ir);
}

"""Get a ctypes-callable function from the JIT engine."""
def get_func(eng: object, name: str, restype: type | None, *argtypes: type) -> object {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    functype = ctypes.CFUNCTYPE(restype, *argtypes);
    return functype(addr);
}

test "encoder builds a nested array/map blob byte-for-byte" {
    (eng, _) = compile_native("msgpack_encode.na.jac");
    enc_len = get_func(eng, "enc_len", ctypes.c_int64);
    enc_byte = get_func(eng, "enc_byte", ctypes.c_int64, ctypes.c_int64);
    # [ 1, "hi", { "k": [ true, nil ] } ]
    expected = [0x93, 0x01, 0xa2, 0x68, 0x69, 0x81, 0xa1, 0x6b, 0x92, 0xc3, 0xc0];
    n = enc_len();
    assert n == len(expected) , f"len {n} != {len(expected)}";
    got = [enc_byte(i) & 0xff for i in range(n)];
    assert got == expected , f"blob {got} != {expected}";
}

test "encoder emits the wide i64 form for a large negative int" {
    (eng, _) = compile_native("msgpack_encode.na.jac");
    enc_len = get_func(eng, "enc_int_wide_len", ctypes.c_int64);
    enc_byte = get_func(eng, "enc_int_wide_byte", ctypes.c_int64, ctypes.c_int64);
    import struct;
    expected = [0xd3] + list(struct.pack(">q", -1000));
    n = enc_len();
    assert n == len(expected) , f"len {n} != {len(expected)}";
    got = [enc_byte(i) & 0xff for i in range(n)];
    assert got == expected , f"blob {got} != {expected}";
}
