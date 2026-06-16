"""End-to-end tests for the native length-aware bytes type, the struct module,
and binary file I/O (#6404 Track 0).

These exercise the sv↔na-congruent surface a binary parser needs:
  - a `bytes` type that carries an explicit length (embedded NULs survive),
  - `struct.pack`/`unpack`/`calcsize` for int/float byte-reinterpretation,
  - `open(path, "rb").read()` returning that length-aware bytes buffer.
"""

import ctypes;
import os;
import tempfile;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.program { JacProgram }
import jaclang.jac0core.unitree as uni;
import from llvmlite.binding { ExecutionEngine }

glob FIXTURES = str(
         Path(jaclang.__file__).parent.parent / "tests" / "compiler" / "passes" / "native" / "fixtures"
     );

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

# ─── bytes type: length awareness, indexing, slicing, equality ───
test "bytes literal length counts embedded NUL" {
    (eng, _) = compile_native("bytes_ops.na.jac");
    f = get_func(eng, "lit_len", ctypes.c_int64);
    assert f() == 5;
}

test "bytes index returns embedded NUL byte" {
    (eng, _) = compile_native("bytes_ops.na.jac");
    f = get_func(eng, "idx_nul", ctypes.c_int64);
    assert f() == 0;
}

test "bytes data past NUL is reachable" {
    (eng, _) = compile_native("bytes_ops.na.jac");
    f = get_func(eng, "idx_after_nul", ctypes.c_int64);
    assert f() == 67;
}

test "bytes negative index" {
    (eng, _) = compile_native("bytes_ops.na.jac");
    f = get_func(eng, "neg_index", ctypes.c_int64);
    assert f() == 68;
}

test "bytes slice length" {
    (eng, _) = compile_native("bytes_ops.na.jac");
    f = get_func(eng, "slice_len", ctypes.c_int64);
    assert f() == 5;
}

test "bytes slice index" {
    (eng, _) = compile_native("bytes_ops.na.jac");
    f = get_func(eng, "slice_idx", ctypes.c_int64);
    assert f() == 119;
}

test "bytes equality true" {
    (eng, _) = compile_native("bytes_ops.na.jac");
    f = get_func(eng, "eq_true", ctypes.c_int64);
    assert f() == 1;
}

test "bytes equality differs after NUL" {
    (eng, _) = compile_native("bytes_ops.na.jac");
    f = get_func(eng, "eq_false_after_nul", ctypes.c_int64);
    assert f() == 0;
}

test "bytes equality differs by length" {
    (eng, _) = compile_native("bytes_ops.na.jac");
    f = get_func(eng, "eq_len_differs", ctypes.c_int64);
    assert f() == 0;
}

test "str encode length" {
    (eng, _) = compile_native("bytes_ops.na.jac");
    f = get_func(eng, "encode_len", ctypes.c_int64);
    assert f() == 5;
}

test "int from_bytes little-endian length-aware" {
    (eng, _) = compile_native("bytes_ops.na.jac");
    f = get_func(eng, "from_bytes_le", ctypes.c_int64);
    assert f() == 256;
}

test "int from_bytes big-endian" {
    (eng, _) = compile_native("bytes_ops.na.jac");
    f = get_func(eng, "from_bytes_be", ctypes.c_int64);
    assert f() == 1;
}

test "int to_bytes roundtrip" {
    (eng, _) = compile_native("bytes_ops.na.jac");
    f = get_func(eng, "to_bytes_roundtrip", ctypes.c_int64);
    assert f() == 258;
}

test "empty bytes length" {
    (eng, _) = compile_native("bytes_ops.na.jac");
    f = get_func(eng, "empty_len", ctypes.c_int64);
    assert f() == 0;
}

# ─── struct module: unpack / pack / calcsize ───
test "struct unpack u32 little-endian" {
    (eng, _) = compile_native("struct_pack.na.jac");
    f = get_func(eng, "u_u32_le", ctypes.c_int64);
    assert f() == 1;
}

test "struct unpack i32 little-endian signed" {
    (eng, _) = compile_native("struct_pack.na.jac");
    f = get_func(eng, "u_i32_le", ctypes.c_int64);
    assert f() == -1;
}

test "struct unpack u32 big-endian" {
    (eng, _) = compile_native("struct_pack.na.jac");
    f = get_func(eng, "u_u32_be", ctypes.c_int64);
    assert f() == 1;
}

test "struct unpack i16 signed" {
    (eng, _) = compile_native("struct_pack.na.jac");
    f = get_func(eng, "u_i16_le", ctypes.c_int64);
    assert f() == -2;
}

test "struct unpack u16" {
    (eng, _) = compile_native("struct_pack.na.jac");
    f = get_func(eng, "u_u16_le", ctypes.c_int64);
    assert f() == 32768;
}

test "struct unpack u8" {
    (eng, _) = compile_native("struct_pack.na.jac");
    f = get_func(eng, "u_u8", ctypes.c_int64);
    assert f() == 255;
}

test "struct unpack i8 signed" {
    (eng, _) = compile_native("struct_pack.na.jac");
    f = get_func(eng, "u_i8", ctypes.c_int64);
    assert f() == -1;
}

test "struct unpack u64" {
    (eng, _) = compile_native("struct_pack.na.jac");
    f = get_func(eng, "u_u64_le", ctypes.c_int64);
    assert f() == 1;
}

test "struct unpack two shorts" {
    (eng, _) = compile_native("struct_pack.na.jac");
    f = get_func(eng, "u_two_le", ctypes.c_int64);
    assert f() == 1002;
}

test "struct unpack f32 via pack roundtrip" {
    (eng, _) = compile_native("struct_pack.na.jac");
    f = get_func(eng, "u_f32", ctypes.c_double);
    assert abs(f() - 1.5) < 1e-9;
}

test "struct unpack f64 via pack roundtrip" {
    (eng, _) = compile_native("struct_pack.na.jac");
    f = get_func(eng, "u_f64", ctypes.c_double);
    assert abs(f() - 3.25) < 1e-12;
}

test "struct calcsize mixed" {
    (eng, _) = compile_native("struct_pack.na.jac");
    f = get_func(eng, "calcsize_mix", ctypes.c_int64);
    assert f() == 8;
}

test "struct calcsize with pad byte" {
    (eng, _) = compile_native("struct_pack.na.jac");
    f = get_func(eng, "calcsize_pad", ctypes.c_int64);
    assert f() == 4;
}

test "struct pack unpack u32 le roundtrip" {
    (eng, _) = compile_native("struct_pack.na.jac");
    f = get_func(eng, "pack_unpack_u32_le", ctypes.c_int64);
    assert f() == 305419896;
}

test "struct pack unpack u32 be roundtrip" {
    (eng, _) = compile_native("struct_pack.na.jac");
    f = get_func(eng, "pack_unpack_u32_be", ctypes.c_int64);
    assert f() == 305419896;
}

test "struct pack multiple values" {
    (eng, _) = compile_native("struct_pack.na.jac");
    f = get_func(eng, "pack_multi", ctypes.c_int64);
    assert f() == 7009;
}

test "struct unpack short buffer raises" {
    (eng, _) = compile_native("struct_pack.na.jac");
    f = get_func(eng, "unpack_short_raises", ctypes.c_int64);
    assert f() == -1;
}

test "struct pack wrong arg count is a compile error" {
    prog = JacProgram();
    prog.compile(file_path=str(os.path.join(FIXTURES, "struct_bad_pack.na.jac")));
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert prog.errors_had , "expected a compile error for the bad struct.pack";
    assert any("struct.pack" in e for e in errors) , f"unexpected errors: {errors}";
}

# ─── binary file read returns length-aware bytes ───
"""Write a small binary blob with embedded NULs and return its path."""
def _write_blob -> str {
    (fd, path) = tempfile.mkstemp(suffix=".bin");
    os.write(fd, b"\x78\x56\x34\x12\x00\x99\x00\x07");
    os.close(fd);
    return path;
}

test "binary read length counts embedded NULs" {
    (eng, _) = compile_native("binary_file.na.jac");
    f = get_func(eng, "read_len", ctypes.c_int64, ctypes.c_char_p);
    path = _write_blob();
    try {
        assert f(path.encode("utf-8")) == 8;
    } finally {
        os.unlink(path);
    }
}

test "binary read byte after NUL" {
    (eng, _) = compile_native("binary_file.na.jac");
    f = get_func(eng, "byte_after_nul", ctypes.c_int64, ctypes.c_char_p);
    path = _write_blob();
    try {
        assert f(path.encode("utf-8")) == 153;
    } finally {
        os.unlink(path);
    }
}

test "struct unpack from binary file slice" {
    (eng, _) = compile_native("binary_file.na.jac");
    f = get_func(eng, "struct_from_file", ctypes.c_int64, ctypes.c_char_p);
    path = _write_blob();
    try {
        assert f(path.encode("utf-8")) == 305419896;
    } finally {
        os.unlink(path);
    }
}

test "binary read via context manager" {
    (eng, _) = compile_native("binary_file.na.jac");
    f = get_func(eng, "read_with_ctx", ctypes.c_int64, ctypes.c_char_p);
    path = _write_blob();
    try {
        assert f(path.encode("utf-8")) == 8;
    } finally {
        os.unlink(path);
    }
}

"""Write a blob whose first line has an embedded NUL before the newline."""
def _write_line_blob -> str {
    (fd, path) = tempfile.mkstemp(suffix=".bin");
    os.write(fd, b"AB\x00C\nXY");
    os.close(fd);
    return path;
}

test "binary readline keeps embedded NUL (length-aware)" {
    (eng, _) = compile_native("binary_file.na.jac");
    f = get_func(eng, "first_line_len", ctypes.c_int64, ctypes.c_char_p);
    path = _write_line_blob();
    try {
        assert f(path.encode("utf-8")) == 5;
    } finally {
        os.unlink(path);
    }
}

test "binary readline byte after NUL" {
    (eng, _) = compile_native("binary_file.na.jac");
    f = get_func(eng, "first_line_byte_after_nul", ctypes.c_int64, ctypes.c_char_p);
    path = _write_line_blob();
    try {
        assert f(path.encode("utf-8")) == 67;
    } finally {
        os.unlink(path);
    }
}
