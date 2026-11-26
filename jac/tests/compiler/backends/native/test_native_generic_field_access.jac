"""Field access through a generic archetype's type-erased slot, by value.

A generic archetype is laid out once, not once per instantiation, so a `has`
slot typed by the class's type parameter lowers to a bare pointer carrying no
class. The offset is not the problem -- it is the same slot for every
instantiation -- but the load came back untyped, so the next `.field` off it
had nothing to resolve against and the whole enclosing callable demoted to a
Python-only seam. In the sealed parser that is `self.hint.tag.value` and
`self.access.tag.name` through `SubTag[Token]`, which is seven of the twenty
eight unitree seam waivers.

The access site's static type argument is what names the value, so these read
back through every shape that carries one: off a local, off a slot after the
erased one (a wrong offset shows as a wrong number), through a `| None`
option, through a union arm narrowed by `isinstance`, off `self` inside a
method, after a store into the erased slot, out of a returning call, through
a parameter annotation, and across a module boundary.

Every answer is additionally checked against the sv/bytecode result of the
same fixture -- a load that silently drops its payload is still well typed
and still compiles, so only the value catches it.
"""

import ctypes;
import os;
import from tests.support {
    TESTS_DIR,
    native_address,
    native_force_opts,
    native_str_func
}
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.compiler.frontend.codeinfo {
    get_effective_default_codespace_override,
    set_effective_default_codespace
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     FIXTURE = "generic_field_access.jac",
     XMOD = "generic_field_xmod_main.jac",
     ALL_FNS = [
         "direct_num",
         "direct_kind",
         "direct_name_len",
         "opt_num",
         "method_num",
         "method_name_len",
         "rank_ord",
         "union_num",
         "store_num",
         "returned_num",
         "param_num"
     ],
     XMOD_FNS = ["local_built", "lib_built", "lib_name_len"],
     FLAGS = [0, 1, 2];


"""Compile a fixture natively; a demotion here is the bug, not a symptom."""
def _compile(fixture: str) -> object {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)), options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    return eng;
}


"""ctypes handle for an (int) -> int function in the JIT engine."""
def _get(eng: any, name: str) -> object {
    addr = native_address(eng, name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(addr);
}


"""Import a fixture through the sv/bytecode pathway."""
def _sv_module(fixture: str) -> object {
    prev = get_effective_default_codespace_override();
    set_effective_default_codespace("server");
    try {
        mods = JacRuntime.jac_import(
            target=fixture[:-4], base_path=FIXTURES, reload_module=True
        );
    } finally {
        set_effective_default_codespace(prev);
    }
    assert mods , f"sv import of {fixture} produced no module";
    return mods[0];
}


"""Every E5092 the native compile of a fixture reported."""
def _demotions(fixture: str) -> list[str] {
    prog = JacProgram();
    prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)), options=native_force_opts()
    );
    return [
        d.pretty_print()
        for d in (prog.errors_had or [])
        if d.code is not None and d.code.code == "E5092"
    ];
}


test "a read through an erased generic slot lowers rather than demoting" {
    assert not _demotions(FIXTURE) , (
        f"generic field access did not lower: {_demotions(FIXTURE)}"
    );
}


test "every erased-slot read agrees with the sv result" {
    eng = _compile(FIXTURE);
    sv = _sv_module(FIXTURE);
    for name in ALL_FNS {
        na_fn = _get(eng, name);
        sv_fn = getattr(sv, name);
        for flag in FLAGS {
            assert na_fn(flag) == sv_fn(flag) , (
                f"{name}({flag}): native {na_fn(flag)} != sv {sv_fn(flag)}"
            );
        }
    }
}


test "an imported generic's erased slot reads through the import's type arg" {
    assert not _demotions(XMOD) , (
        f"cross-module generic field access did not lower: {_demotions(XMOD)}"
    );
    eng = _compile(XMOD);
    sv = _sv_module(XMOD);
    for name in XMOD_FNS {
        na_fn = _get(eng, name);
        sv_fn = getattr(sv, name);
        for flag in FLAGS {
            assert na_fn(flag) == sv_fn(flag) , (
                f"{name}({flag}): native {na_fn(flag)} != sv {sv_fn(flag)}"
            );
        }
    }
}
