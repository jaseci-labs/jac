"""Native tests for optional-string comparison and enum-class lowering (#7851).

Comparing a possibly-None `str` (an unset `str | None` field) against a string
literal used to dereference NULL inside `strcmp` and segfault. `str | None`
lowers to a tagged JacOptional value, so equality is tag arithmetic plus a
payload strcmp only when both sides carry values: None == "" is False,
None == None is True. Ordering against an un-narrowed optional is an E1121
check-time diagnostic (pinned in test_native_optional_ptr.jac). Separately, an
enum-class used in a type must lower to its backing integer even when the
enum's defining module is walked after the module referencing it.
"""

import ctypes;
import os;
import from pathlib { Path }
import from tests.support { compile_native, get_func, native_force_opts }
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");
test "optional string equality is tag arithmetic, matching Python" {
    (eng, _) = compile_native("nullsafe_strcmp_enum.jac");
    # b.label is unset (None); comparing it must be safe, and None == "" is
    # False just like Python.
    assert get_func(eng, "null_eq_empty", ctypes.c_int64)() == 0;
    # None == None is True.
    assert get_func(eng, "null_eq_null", ctypes.c_int64)() == 1;
    # None != "" is True.
    assert get_func(eng, "null_ne_empty", ctypes.c_int64)() == 1;
    # None == "hi" is False.
    assert get_func(eng, "null_ne_word", ctypes.c_int64)() == 0;
    # A set string still compares by value.
    assert get_func(eng, "set_then_eq", ctypes.c_int64)() == 1;
}

test "un-narrowed optional ordering is rejected at check time" {
    prog = JacProgram();
    prog.compile(
        file_path=str(os.path.join(FIXTURES, "optional_ptr_diag.jac")),
        options=native_force_opts()
    );
    msgs = [str(e) for e in prog.errors_had];
    assert any("used where an ordered operand is required" in m for m in msgs) , (
        f"expected the E1121 ordering diagnostic, got: {msgs}"
    );
}

test "enum-class parameter and return type lower cleanly" {
    (eng, _) = compile_native("nullsafe_strcmp_enum.jac");
    flip = get_func(eng, "flip", ctypes.c_int64, ctypes.c_int64);
    assert flip(0) == 1;
    assert flip(1) == 0;
    mode_is_on = get_func(eng, "mode_is_on", ctypes.c_int64, ctypes.c_int64);
    assert mode_is_on(1) == 1;
    assert mode_is_on(0) == 0;
}

test "imported enum in container types survives module walk order" {
    # opcodes_entry imports opcodes_use_mid (a glob and an obj field typed
    # dict[Opcode, int]) which imports opcodes_mod (the enum), so the using
    # module is walked before Opcode is name-registered. Without the
    # structural enum fallback, lowering the glob's dict type fails with
    # E5092 (compile_native then raises on prog.errors_had).
    (eng, _) = compile_native("opcodes_entry.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "imported_enum_tally", ctypes.c_int64);
    result = f();
    assert result == 1231 , f"Expected 1231, got {result}";
}
