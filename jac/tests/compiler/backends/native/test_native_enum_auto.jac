"""`auto()` members fold, so an enum read off the class lowers (#8288).

`ParameterCategory` in `types.jac` spells its three members `auto()`, and
that one detail cost the type evaluator a fifth of its file. A member value
reached the backend through `fold_const`, which sees a `FuncCall` and answers
"not a constant", so the member had no literal, the class-form layout dropped
it, and `ParameterCategory.ArgsList` lowered to nothing --
`get_type_of_ability` demoted on the read, `get_type_of_expression` demoted on
the call, and twenty-one more methods demoted on that.

`auto()` has no value of its own to fold; CPython generates one from the
members already assigned. That makes it a question about the declaration
rather than the expression, which is why the answer lives beside the enum's
layout instead of in the constant folder: the members arrive in source order
and the generated value is `max(seen) + 1`, counting from 1.

Counting from the largest rather than the last is the part worth pinning.
`High = 10; Low = 3; Next = auto()` is `11` in CPython, not `4`, and a rule
that tracked the previous member would answer the second and stay wrong
quietly, because nothing else in the file would disagree with it.

Two things still refuse, and they refuse rather than guess. A generated value
that follows a member the fold could not reach has no maximum to count from,
so it stays unknown; such an enum is refused under E5092 where it is used,
never lowered with guessed zeros. And the name is matched through its symbol,
not its spelling: a module-local function called `auto` is not `enum`'s, so
`enum_auto_shadow.jac` demotes the function that reads it and the server lane
answers what CPython answers.
"""

import ctypes;
import os;
import subprocess;
import tempfile;
import from tests.support {
    TESTS_DIR,
    compile_mir,
    compile_native,
    compile_native_refused,
    diagnostics_text,
    error_codes,
    get_func,
    jac_command
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     EXPECTED: tuple[str, ...] = ("1", "2", "3", "10", "3", "1112", "129", "4");


def sv_lines(fixture: str) -> list[str] {
    proc = subprocess.run(
        jac_command("run", os.path.join(FIXTURES, fixture)),
        capture_output=True,
        text=True,
        timeout=900
    );
    assert proc.returncode == 0 , f"server run failed: {proc.stderr[-800:]}";
    return [
        _l
        for _l in proc.stdout.split("\n")
        if _l.strip()
    ];
}


def na_lines(fixture: str) -> list[str] {
    out_bin = os.path.join(tempfile.mkdtemp(), "probe.bin");
    comp = subprocess.run(
        jac_command(
            "build", "--native", os.path.join(FIXTURES, fixture), "-o", out_bin
        ),
        capture_output=True,
        text=True,
        timeout=900
    );
    assert comp.returncode == 0 , f"nacompile failed: {comp.stderr[-900:]}";
    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
    assert proc.returncode == 0 , f"binary exited {proc.returncode}: {proc.stderr[-400:]}";
    return [
        _l
        for _l in proc.stdout.split("\n")
        if _l.strip()
    ];
}


test "an all-auto enum lowers with nothing demoted" {
    demoted = compile_mir("enum_auto.jac").demoted();
    assert not any(reason.startswith("attribute") for reason in demoted.values()) , (
        f"a member read off the class still refused: {demoted}"
    );
}


test "generated values count from the largest already assigned" {
    (eng, _) = compile_native("enum_auto.jac");
    category = get_func(eng, "category", ctypes.c_int64, ctypes.c_int64);
    assert [category(0), category(1), category(2)] == [1, 2, 3] , (
        "the all-auto enum did not count from 1"
    );
    counted = get_func(eng, "counted", ctypes.c_int64)();
    assert counted == 1112 , (
        f"Mixed generated {counted}; counting from the last member rather than "
        "the largest would read 405"
    );
}


test "the declared-enum spelling generates the same way" {
    (eng, _) = compile_native("enum_auto.jac");
    stepped = get_func(eng, "stepped", ctypes.c_int64)();
    assert stepped == 129 , f"Step generated {stepped}";
}


test "generated values answer as CPython does" {
    sv = sv_lines("enum_auto.jac");
    assert sv == list(EXPECTED) , f"server lane printed {sv}";
    na = na_lines("enum_auto.jac");
    assert na == sv , f"native {na} != server {sv}";
}


test "a module-local auto is not read as the enum's" {
    fx = compile_mir("enum_auto_shadow.jac");
    assert fx.is_demoted("loudness") , (
        f"this module's own `auto` was counted as a generated value: {fx.demoted()}"
    );
    sv = sv_lines("enum_auto_shadow.jac");
    assert sv == ["40"] , f"server lane printed {sv}";
}


test "an unencodable declared enum refuses where it is used" {
    result = compile_native_refused("enum_unencodable.jac");
    text = diagnostics_text(result);
    assert "E5092" in error_codes(result) and "Ratio" in text , (
        f"a use of an unencodable enum lowered with guessed zeros: {text}"
    );
    assert "Unread" not in text and "enum_unencodable_lib" not in text , (
        f"an enum nothing uses refused its module: {text}"
    );
}
