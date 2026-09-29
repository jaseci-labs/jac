"""Field access through a secondary-base-narrowed reference (issue #8163).

Archetype layouts are flattened: a derived class inlines every ancestor field
in MRO order, so a field declared on a *secondary* base sits at a different
slot in the derived struct than in that base's own struct. Reading it off a
reference whose static type is the base therefore has to pick the slot from
the runtime class, which `_emit_dispatched_field_ptr` does by comparing the
object's vtable pointer against each candidate class.

That dispatch is driven by the compiling module's layout registry, and
`_register_imported_hierarchy` used to copy an imported module's
`class_parents` and `mro_order` into it but not its `layouts`. The registry
could then answer "what is `Item`'s MRO" while returning `None` for "what is
`Flagged`'s layout", so the dispatch bailed on its first guard and the flat
base-slot offset was emitted instead. Same-module hierarchies were unaffected,
which is why this only ever showed up across a module boundary.

The shape mirrors `Assignment(AstTypedVarNode, EnumBlockStmt, CodeBlockStmt)`
in the compiler's own tree, which is where this was found: the base slot for
`flagged` names the `tag` pointer inside `Item`, so the wrong offset reads
that pointer's low byte and the answer flips with whether `tag` happens to be
set -- the per-instance drift that dropped commas from impl-based enum bodies
in the sealed native parser.
"""

import ctypes;
import os;
import from tests.support {
    TESTS_DIR,
    compile_native,
    native_address,
    native_force_opts
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

"""Call `name` in the JIT engine over the five fixture instances."""
def probe(eng: any, name: str) -> list[int] {
    addr = native_address(eng, name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    f = ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(addr);
    return [f(k) for k in range(5)];
}

test "secondary-base field read is independent of the neighbouring pointer" {
    (eng, _) = compile_native("secondary_base_xmod_main.jac");
    assert probe(eng, "read_narrowed") == [0, 0, 1, 1, 1] , (
        "a read through the narrowed base must land on `flagged`, not on the "
        "`tag` pointer the base's slot index names inside `Item`"
    );
}

test "secondary-base field read outside the isinstance condition agrees" {
    (eng, _) = compile_native("secondary_base_xmod_main.jac");
    assert probe(eng, "read_direct") == [0, 0, 1, 1, 1] , (
        "a narrowed read in a separate statement must resolve the same slot"
    );
}

test "secondary-base field write lands on the field, not the neighbour" {
    (eng, _) = compile_native("secondary_base_xmod_main.jac");
    assert probe(eng, "write_narrowed") == [1, 1, 1, 1, 1] , (
        "a store through the narrowed base must be visible through the concrete type"
    );
}

test "a secondary-base write does not clobber a neighbouring field" {
    (eng, _) = compile_native("secondary_base_xmod_main.jac");
    assert probe(eng, "tag_intact") == [0, 1, 0, 1, 0] , (
        "storing `flagged` through the base must leave the `tag` pointer alone"
    );
}

test "a method declared on the secondary base still dispatches to itself" {
    (eng, _) = compile_native("secondary_base_xmod_main.jac");
    assert probe(eng, "call_narrowed") == [20, 20, 20, 20, 20] , (
        "the vtable slot for a secondary base's method must not resolve to the "
        "primary base's method"
    );
}

test "the same hierarchy inside one module keeps resolving correctly" {
    (eng, _) = compile_native("secondary_base_field.jac");
    assert probe(eng, "read_narrowed") == [0, 0, 1, 1, 1] , "single-module read";
    assert probe(eng, "read_direct") == [0, 0, 1, 1, 1] , "single-module split read";
    assert probe(eng, "write_narrowed") == [1, 1, 1, 1, 1] , "single-module write";
    assert probe(eng, "tag_intact") == [0, 1, 0, 1, 0] , "single-module neighbour";
}
