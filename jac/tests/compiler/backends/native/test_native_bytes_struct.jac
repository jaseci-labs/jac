"""End-to-end tests for the native length-aware bytes type, the struct module,
and binary file I/O (#6404 Track 0).

These exercise the sv↔na-congruent surface a binary parser needs:
  - a `bytes` type that carries an explicit length (embedded NULs survive),
  - `struct.pack`/`unpack`/`calcsize` for int/float byte-reinterpretation,
  - `open(path, "rb").read()` returning that length-aware bytes buffer.

No fixture here writes a global, so each is compiled once and its functions
are checked as one table.
"""

import from tests.support {
    compile_native,
    get_func,
    native_force_opts,
    native_str_func
}
import ctypes;
import os;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

"""The entries of `want` whose function returned something else, as
{name: (got, expected)}. `call` runs the named function."""
def wrong_returns(
    call: Callable[[str], int], want: dict[str, int]
) -> dict[str, tuple[int, int]] {
    got = {fn: call(fn) for fn in want};
    return {
        fn: (got[fn], want[fn])
        for fn in want
        if got[fn] != want[fn]
    };
}

test "bytes_ops: every bytes operation returns its CPython value" {
    (eng, _) = compile_native("bytes_ops.jac");
    wrong = wrong_returns(
        lambda (fn: str) { get_func(eng, fn, ctypes.c_int64)(); },
        {
            # length awareness, indexing, slicing, equality
            "lit_len": 5,  # the length counts the embedded NUL
            "idx_nul": 0,
            "idx_after_nul": 67,
            "neg_index": 68,
            "slice_len": 5,
            "slice_idx": 119,
            "eq_true": 1,
            "eq_false_after_nul": 0,
            "eq_len_differs": 0,
            "encode_len": 5,
            "from_bytes_le": 256,
            "from_bytes_be": 1,
            "to_bytes_roundtrip": 258,
            "empty_len": 0,
            # concatenation and the bytes()/bytearray() constructors
            "concat_len": 2,
            "concat_embedded_nul_len": 4,
            "concat_idx": 67,  # the right operand lands at the correct offset
            "ctor_len": 3,
            "ctor_idx_after_nul": 66,
            "bytearray_ctor_len": 3,
            # #6749: ops the i8*→jacbytes* migration left on the old
            # strlen/strstr/strcmp assumption; the NUL cases are what broke
            "repeat_len": 6,
            "repeat_idx": 98,
            "repeat_nul_len": 6,
            "repeat_nul_idx": 0,
            "repeat_zero": 0,
            "in_true": 1,
            "in_false": 0,
            "in_nul": 1,
            "not_in_true": 1,
            "in_empty": 1,
            "iter_sum": 294,  # iteration yields int bytes
            "iter_count_nul": 3,
            "iter_sum_nul": 195,
            "iter_protocol_sum": 294,
            "truthy_empty": 0,  # truthiness is emptiness, not nullness
            "truthy_nonempty": 1,
            "truthy_nul": 1,
            "bool_empty": 0,
            "bool_nonempty": 1,
            "repr_abc_ok": 1,  # repr matches CPython b'...'
            "repr_nul_ok": 1,
            "repr_empty_ok": 1,
            "repr_quote_ok": 1,
            "repr_special_ok": 1,
            "repr_backslash_ok": 1,
            "repr_hi_ok": 1,
            "dict_get": 7,  # a bytes dict key is length-aware
            "dict_nul": 5,
            "dict_distinct_len": 2,
            "dict_distinct_len2": 1,
            "lt_true": 1,  # ordering is lexicographic unsigned
            "lt_false": 0,
            "lt_prefix": 1,
            "gt_true": 1,
            "lte_eq": 1,
            "gte_eq": 1,
            "cmp_nul": 1,
            "cmp_hi": 1,
            # #6751: a None operand equals only None and is never dereferenced;
            # ordering against an un-narrowed None is E1121, pinned in
            # test_native_optional_ptr.jac
            "none_eq_bytes": 0,
            "bytes_eq_none": 0,
            "none_ne_bytes": 1,
            "cnone_eq_bytes": 0,
            "cnone_ne_bytes": 1,
            "both_none_eq": 1,
            "both_none_ne": 0,
            "some_eq_bytes": 1,
            "some_eq_diff": 0,
            "builtin_repr_ok": 1,  # builtin repr() takes native bytes without demotion
            "string_contains_nul": 1  # str containment keeps embedded NUL boundaries
        }
    );
    assert not wrong , f"(got, expected): {wrong}";
}

test "struct_pack: unpack, pack and calcsize return their CPython values" {
    (eng, _) = compile_native("struct_pack.jac");
    wrong = wrong_returns(
        lambda (fn: str) { get_func(eng, fn, ctypes.c_int64)(); },
        {
            "u_u32_le": 1,
            "u_i32_le": -1,
            "u_u32_be": 1,
            "u_i16_le": -2,
            "u_u16_le": 32768,
            "u_u8": 255,
            "u_i8": -1,
            "u_u64_le": 1,
            "u_two_le": 1002,
            "calcsize_mix": 8,
            "calcsize_pad": 4,
            "pack_unpack_u32_le": 305419896,
            "pack_unpack_u32_be": 305419896,
            "pack_multi": 7009,
            "unpack_short_raises": -1  # a short buffer raises
        }
    );
    assert not wrong , f"(got, expected): {wrong}";
    assert abs(get_func(eng, "u_f32", ctypes.c_double)() - 1.5) < 1e-9;
    assert abs(get_func(eng, "u_f64", ctypes.c_double)() - 3.25) < 1e-12;
}

test "struct pack wrong arg count is a compile error" {
    import contextlib;
    import io;
    buf = io.StringIO();
    prog = JacProgram();
    with contextlib.redirect_stderr(buf) {
        ir = prog.compile(
            file_path=str(os.path.join(FIXTURES, "struct_bad_pack.jac")),
            options=native_force_opts()
        );
    }
    assert not prog.errors_had , (
        f"the bad struct.pack is owned by bad_pack(), which must demote to "
        f"a seam, got: {[str(e) for e in prog.errors_had]}"
    );
    assert ir.gen.native_layout is not None , "whole-module native compile aborted";
    assert "bad_pack" not in ir.gen.native_layout.functions , (
        "a struct.pack with the wrong argument count must demote its "
        "function out of the native layout, never pack uninitialized tail "
        "bytes"
    );
    assert "struct.pack" in buf.getvalue() , (
        f"the demotion reason must name struct.pack, got:\n{buf.getvalue()}"
    );
}

test "binary_file: rb reads, readline and struct see every byte past a NUL" {
    (eng, _) = compile_native("binary_file.jac");
    for (blob, want) in [
        (
            b"\x78\x56\x34\x12\x00\x99\x00\x07",
            {
                "read_len": 8,
                "byte_after_nul": 153,
                "struct_from_file": 305419896,
                "read_with_ctx": 8
            }
        ),
        # the first line has a NUL before its newline
        (b"AB\x00C\nXY", {"first_line_len": 5, "first_line_byte_after_nul": 67})
    ] {
        (fd, path) = tempfile.mkstemp(suffix=".bin");
        os.write(fd, blob);
        os.close(fd);
        try {
            wrong = wrong_returns(
                lambda (fn: str) { native_str_func(
                    eng, fn, ctypes.c_int64, ctypes.c_char_p
                )(
                    path.encode("utf-8")
                ); },
                want
            );
            assert not wrong , f"{blob!r} (got, expected): {wrong}";
        } finally {
            os.unlink(path);
        }
    }
}

test "reused object locals preserve narrowed string operations" {
    (eng, _) = compile_native("rebound_string.jac");
    assert get_func(eng, "rebound_string", ctypes.c_int64)() == 0;
}
