"""Optional containers keep their element layout when walked (jac#8201 S3).

`has parts: (list[Item] | None)` lowers to a `JacOpt` -- a presence tag beside
the container pointer. Every loop, comprehension and slice over such a slot
used to hand that wrapper to the container helpers, which crashed the IR
builder: an internal compiler error, reported as a per-function demotion and
never as a wrong answer, but a crash all the same. The `x or []` spelling failed differently and worse -- the empty
display picked its own element flavour, the phi unified the two container
pointers to `i8*`, and the element type was gone by the time the loop asked
for it.

Two properties are pinned:

* every shape lowers, so none of these functions may be demoted, and
* the native answer equals the sv answer, including the `None` arm -- walking
  an absent optional raises `TypeError` on both pathways rather than
  silently iterating nothing.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, compile_mir, compile_native, native_address }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.compiler.frontend.codeinfo {
    get_effective_default_codespace_override,
    set_effective_default_codespace
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     FIXTURE = "optional_elem_iter.jac";

glob CASES: list[str] = [
         "opt_list_direct_loop",
         "opt_list_or_loop",
         "opt_list_direct_compr",
         "opt_list_or_compr",
         "opt_list_filtered_compr",
         "opt_str_list_loop",
         "opt_dict_direct_loop",
         "opt_dict_or_loop",
         "empty_optional_or_loop",
         "empty_optional_or_compr",
         "none_direct_loop_raises",
         "annotated_local_loop",
         "optional_local_loop",
         "opt_list_slice_len",
         "opt_list_index",
         "none_slice_raises"
     ];

"""Call a no-argument int-returning function out of the JIT engine."""
def native_call(eng: any, name: str) -> int {
    addr = native_address(eng, name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64)(addr)();
}

"""Import the fixture through the sv pathway and return its module."""
def sv_module -> any {
    prev = get_effective_default_codespace_override();
    set_effective_default_codespace("server");
    try {
        mods = JacRuntime.jac_import(
            target=FIXTURE[:-4], base_path=FIXTURES, reload_module=True
        );
    } finally {
        set_effective_default_codespace(prev);
    }
    assert mods , "sv import of the fixture produced no module";
    return mods[0];
}


test "every optional-container walk lowers natively" {
    fx = compile_mir(FIXTURE);
    missing = [
        fn
        for fn in CASES
        if fx.is_demoted(fn)
    ];
    assert not missing , (
        "these optional-container walks demoted instead of lowering: "
        + f"{missing}: {fx.demoted()}"
    );
}


test "optional-container walks answer the same on both pathways" {
    (eng, _) = compile_native(FIXTURE);
    sv = sv_module();
    for fn in CASES {
        na_v = native_call(eng, fn);
        sv_v = int(getattr(sv, fn)());
        assert na_v == sv_v , f"native {fn}() == {na_v} but sv gives {sv_v}";
    }
}


test "the answers are the fixture's, not a shared wrong answer" {
    (eng, _) = compile_native(FIXTURE);
    # 1 + 2 + 4 over the three items, every spelling of the walk.
    for fn in [
        "opt_list_direct_loop",
        "opt_list_or_loop",
        "opt_list_direct_compr",
        "opt_list_or_compr",
        "annotated_local_loop"
    ] {
        assert native_call(eng, fn) == 7 , f"{fn}() must sum the three items";
    }
    assert native_call(eng, "opt_list_filtered_compr") == 6 , "2 + 4 past the filter";
    assert native_call(eng, "opt_str_list_loop") == 5 , "len('ab') + len('cde')";
    assert native_call(eng, "opt_dict_direct_loop") == 3 , "len('a') + len('bb')";
    assert native_call(eng, "opt_dict_or_loop") == 3 , "len('a') + len('bb')";
    assert native_call(eng, "empty_optional_or_loop") == 7 , "an absent list adds 0";
    assert native_call(eng, "empty_optional_or_compr") == 5 , "an absent list adds 0";
    assert native_call(eng, "optional_local_loop") == 8 , "3 + 5";
    # The `None` arm is the one a silent empty-walk would get wrong: CPython
    # raises TypeError, so the fixture's `except` arm has to be the one that
    # runs on the native pathway too.
    assert native_call(eng, "none_direct_loop_raises") == -1 , (
        "iterating an absent optional must raise TypeError, not walk nothing"
    );
    assert native_call(eng, "opt_list_slice_len") == 7 , "a slice keeps the elements";
    assert native_call(eng, "opt_list_index") == 2 , "the second item";
    assert native_call(eng, "none_slice_raises") == -1 , (
        "slicing an absent optional must raise TypeError, not read a null"
    );
}
