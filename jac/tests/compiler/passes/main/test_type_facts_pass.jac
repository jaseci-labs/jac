"""Tests for the shared TypeFacts pass.

Validates the backend-neutral type facts consumed by both the ownership
analysis and the C emitter: the reference-archetype set, function and method
return types, field types, and expression typing via ``type_of``. Also covers
caching on ``module.gen.type_facts`` and the first-wins import merge performed
by ``get_shared_type_facts``. Fixtures are the jac2c runtime-ABI fixtures.
"""

import from jaclang.compiler.passes.main.type_facts_pass {
    TypeFacts,
    TypeFactsPass,
    get_type_facts,
    get_shared_type_facts
}
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }
import os;
import from tests.support { JAC_ROOT }

glob FIXTURES: str = os.path.join(
         JAC_ROOT, "tests", "compiler", "c2jac", "fixtures"
     );

def _compile(fixture: str) -> tuple {
    prog = JacProgram();
    ir = prog.compile(file_path=os.path.join(FIXTURES, fixture));
    assert not prog.errors_had , f"errors in {fixture}: {[
        str(e) for e in prog.errors_had
    ]}";
    return (ir, prog);
}

def _facts(fixture: str) -> tuple {
    (ir, prog) = _compile(fixture);
    return (ir, get_type_facts(ir, prog));
}

test "reference archetypes are indexed as ref types" {
    (mod, tf) = _facts("obj_rc.jac");
    assert tf.is_ref("Counter") , "Counter is a ref archetype";
    assert "Counter" in tf.ref_types , "ref_types must contain Counter";
    assert not tf.is_ref("NotAType") , "unknown name is not a ref type";
}

test "field and method return types are indexed per class" {
    (mod, tf) = _facts("obj_rc.jac");
    assert "Counter" in tf.field_types , "field_types must contain Counter";
    assert "Counter" in tf.method_returns , "method_returns must contain Counter";
}

test "expression typing resolves literals and locals" {
    (mod, tf) = _facts("obj_rc.jac");
    # A string literal is typed str with no local context.
    for s in mod.body {
        if isinstance(s, uni.Ability)
        and s.name_ref is not None
        and s.name_ref.value == "run_counter" {
            ctor_assign = list(s.body)[0];
            # c = Counter(10): the call target names a ref archetype -> Counter.
            assert tf.type_of(ctor_assign.value, {}) == "Counter" , "constructor call types as its class";
        }
    }
}

test "facts are cached on module.gen and reused" {
    (mod, tf) = _facts("obj_rc.jac");
    again = get_type_facts(mod, None);
    assert again is tf , "get_type_facts must return the cached instance";
}

test "successfully built facts report ok" {
    (mod, tf) = _facts("obj_rc.jac");
    assert tf.ok , "facts built from a clean module must be ok";
}

test "shared facts are ok when every module is ok" {
    (mod, cached) = _facts("obj_rc.jac");
    merged = get_shared_type_facts([mod], None);
    assert merged.ok , "merged facts over ok modules must be ok";
}

test "shared facts merge modules first-wins" {
    prog = JacProgram();
    ir = prog.compile(file_path=os.path.join(FIXTURES, "obj_rc.jac"));
    assert not prog.errors_had , "obj_rc must compile clean";
    merged = get_shared_type_facts([ir], prog);
    assert "Counter" in merged.ref_types , "merged facts include Counter";
    assert "Counter" in merged.field_types , "merged facts include Counter fields";
}

test "shared facts are isolated from the cached per-module facts" {
    (mod, cached) = _facts("obj_rc.jac");
    merged = get_shared_type_facts([mod], None);
    # A consumer mutating the merged facts (as the C emitter does when it folds
    # in layout-derived field types) must not corrupt the cached facts that
    # other passes share.
    merged.field_types["Counter"]["injected"] = "int";
    assert "injected" not in cached.field_types["Counter"] , "merge must copy nested field maps, not alias them";
}

test "empty facts default to empty maps" {
    fresh = TypeFacts();
    assert not fresh.is_ref("Anything") , "empty facts have no ref types";
    assert fresh.type_of(None, {}) == "" , "typing an unknown node yields the empty string";
    assert not fresh.ok , "a fresh (never-built) facts object is not ok";
}

test "every reference archetype in the module is indexed" {
    (mod, tf) = _facts("obj_rc.jac");
    # obj_rc declares two ref archetypes; both must be present, and nothing
    # spurious besides.
    assert tf.is_ref("Counter") and tf.is_ref("Box") , "both ref archetypes indexed";
    assert len(tf.ref_types) == 2 , f"expected exactly 2 ref types, got {tf.ref_types}";
}

test "free-function return types are indexed by name" {
    (mod, tf) = _facts("obj_rc.jac");
    # func_returns was never asserted before -- guard the actual mapping.
    assert tf.func_returns.get("run_counter") == "int" , "run_counter returns int";
    assert tf.func_returns.get("run_box") == "int" , "run_box returns int";
}

test "field types carry the declared type name" {
    (mod, tf) = _facts("obj_rc.jac");
    assert tf.field_types["Counter"]["n"] == "int" , "Counter.n is int";
    # A ref-typed field records the archetype name, not a lowered/primitive tag.
    assert tf.field_types["Box"]["c"] == "Counter" , "Box.c is a Counter";
}

test "method return types carry the signature return" {
    (mod, tf) = _facts("obj_rc.jac");
    assert tf.method_returns["Counter"]["bump"] == "int" , "Counter.bump returns int";
    assert tf.method_returns["Counter"]["get"] == "int" , "Counter.get returns int";
    # A constructor with no return annotation records the empty string.
    assert tf.method_returns["Counter"]["init"] == "" , "init has no declared return";
}

test "type_of resolves a local name through the local context" {
    (mod, tf) = _facts("obj_rc.jac");
    for s in mod.body {
        if isinstance(s, uni.Ability)
        and s.name_ref is not None
        and s.name_ref.value == "run_counter" {
            # `c = Counter(10)` -- the assignment target is the local name `c`.
            name = list(list(s.body)[0].target)[0];
            assert tf.type_of(name, {"c": "Counter"}) == "Counter" , "local name resolves via local_types";
            # With no local context the same name is untyped.
            assert tf.type_of(name, {}) == "" , "unknown local yields the empty string";
        }
    }
}

test "shared facts merge free functions from every module" {
    (a, pa) = _compile("obj_rc.jac");
    (b, pb) = _compile("obj_move.jac");
    merged = get_shared_type_facts([a, b], pa);
    # Non-colliding free functions from both modules survive the merge.
    assert merged.func_returns.get("run_counter") == "int" , "obj_rc function present";
    assert merged.func_returns.get("run_move") == "int" , "obj_move function present";
}

test "get_type_facts with no prog and no cache raises" {
    # A freshly compiled module has no cached facts (TypeFactsPass is lazy, not
    # in the compile schedule). Asking for facts without a prog to build them
    # must fail loudly rather than hand back silent empty facts.
    (ir, prog) = _compile("obj_rc.jac");
    assert ir.gen.type_facts is None , "fresh module must start with no cached facts";
    raised = False;
    try {
        get_type_facts(ir, None);
    } except ValueError {
        raised = True;
    }
    assert raised , "None prog with no cache must raise ValueError";
    # Once built with a real prog, the None-prog cache read succeeds.
    built = get_type_facts(ir, prog);
    assert get_type_facts(ir, None) is built , "cached read with None prog returns the built facts";
}

test "shared merge is first-wins on colliding archetype names" {
    (a, pa) = _compile("obj_rc.jac");
    (b, pb) = _compile("obj_move.jac");
    # Both modules define a `Counter`, but only obj_rc's has a `bump` method.
    ab = get_shared_type_facts([a, b], pa);
    assert "bump" in ab.method_returns["Counter"] , "first module (obj_rc) wins";
    ba = get_shared_type_facts([b, a], pb);
    assert "bump" not in ba.method_returns["Counter"] , "first module (obj_move) wins";
}
