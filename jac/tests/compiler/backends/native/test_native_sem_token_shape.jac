"""`NameAtom.sem_token`'s two backend gaps, asserted by value.

`sem_token` shipped as an `abort()` stub in the sealed native parser, waived
four times over (the base plus its re-emission on `Name`, `SpecialVarRef` and
`BuiltinType`). Two independent causes kept it there, and each is checked
here on its own before they are checked together:

*An enum member's value came from the syntax of its initialiser.* Only an
`Int`/`String` literal node produced one, so a member written `1 << 0` had no
value. A class-form enum (`class M(IntFlag)` -- `JacSemTokenModifier`'s
shape) dropped such a member from its layout and the read refused with
E5092; a Jac `enum` kept the member and gave it `0`, which is a wrong answer
with no diagnostic attached. The `kind_of` assertions below are the ones that
catch the silent half: they would pass a "did it compile?" check.

*`__class__.__name__` refused a receiver that did not lower to a pointer to a
struct the unit knows.* `sem_token` reads `type(self.type).__name__`, and
`self.type` is `TypeBase | None` -- a class reached through a typing-only
import, so the slot is an opaque object pointer with no struct to freeze a
name against and no known vtable to walk, exactly like a type-erased generic
slot. The read has to resolve the runtime class the way
`_emit_isinstance_ptr_tags` does, off the class-name stamp in the rc header.
An option is here for the same reason with different storage: its JacOpt
payload has to be unwrapped before anything can be read off it, and the absent
arm is `NoneType`.

Every function is additionally compared against the sv/bytecode result of the
same fixture, the parity idiom `union_slot_ops` uses: a class-name read that
answers the *declared* class instead of the runtime one, and an enum member
that lowers to the wrong constant, both produce well-typed values that only a
value comparison rejects.

Refs #8039, #8052
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
     FIXTURE = "sem_token_shape.jac",
     ALL_FNS = [
         "kind_of",
         "mod_of",
         "kind_and_mod",
         "open_name_rank",
         "open_dunder_rank",
         "opt_name_rank",
         "known_name_rank",
         "sem_token_rank"
     ],
     PICKS = [0, 1, 2, 3],
     _ENG: list[any] = [];


"""Compile the fixture natively once and return the JIT engine."""
def _compile -> object {
    if _ENG {
        return _ENG[0];
    }
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, FIXTURE)), options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {FIXTURE}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {FIXTURE}";
    _ENG.append(eng);
    return eng;
}


"""ctypes handle for an (int) -> int function in the JIT engine."""
def _get(eng: any, name: str) -> object {
    addr = native_address(eng, name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(addr);
}


"""Import the same fixture through the sv/bytecode pathway."""
def _sv_module -> object {
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


test "the class name off an open receiver is the name, not a stand-in" {
    eng = _compile();
    f = native_str_func(eng, "open_name", ctypes.c_char_p, ctypes.c_int64);
    assert f(1) == b"Leaf" , "the rank mapping could pass on any three values";
    assert f(2) == b"Branch" , "so the string itself is read back too";
    assert f(0) == b"Node" , "the base class reports its own name";
}


test "every function agrees with the sv result" {
    eng = _compile();
    sv = _sv_module();
    for name in ALL_FNS {
        na_fn = _get(eng, name);
        sv_fn = getattr(sv, name);
        for pick in PICKS {
            assert na_fn(pick) == sv_fn(pick) , (
                f"{name}({pick}): native {na_fn(pick)} != sv {sv_fn(pick)}"
            );
        }
    }
}
