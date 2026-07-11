"""Tests for the OwnershipFacts policy pass.

Validates the backend-neutral ownership analysis: value category (owned vs
borrowed) per expression and proven last-use per binding in straight-line
bodies. The pass has no consumers yet; these tests assert the facts it computes
are sound and non-trivial. Fixtures are the jac2c runtime-ABI fixtures.
"""

import from jaclang.compiler.passes.main.ownership_facts_pass {
    OwnershipFacts,
    OwnershipFactsPass,
    get_ownership_facts
}
import from jaclang.compiler.ownership { Ownership }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }
import os;
import from tests.support { JAC_ROOT }

glob FIXTURES: str = os.path.join(
         JAC_ROOT, "tests", "compiler", "c2jac", "fixtures"
     );

def _facts(fixture: str) -> tuple {
    prog = JacProgram();
    ir = prog.compile(file_path=os.path.join(FIXTURES, fixture));
    assert not prog.errors_had , f"errors in {fixture}: {[
        str(e) for e in prog.errors_had
    ]}";
    return (ir, get_ownership_facts(ir, prog));
}

def _compile(fixture: str) -> tuple {
    prog = JacProgram();
    ir = prog.compile(file_path=os.path.join(FIXTURES, fixture));
    assert not prog.errors_had , f"errors in {fixture}: {[
        str(e) for e in prog.errors_had
    ]}";
    return (ir, prog);
}

def _find_fn(mod: uni.Module, name: str) -> object {
    for s in mod.body {
        if isinstance(s, uni.Ability)
        and s.name_ref is not None
        and s.name_ref.value == name {
            return s;
        }
    }
    return None;
}

test "constructor calls are owned, plain reads are borrowed" {
    (mod, facts) = _facts("obj_rc.jac");
    fn = _find_fn(mod, "run_counter");
    stmts = list(fn.body);
    # c = Counter(10): the constructor call produces an owned reference.
    ctor_assign = stmts[0];
    assert facts.is_owned(ctor_assign.value) , "constructor call should be owned";
    # return (a + b): an int arithmetic result is not an owned reference.
    ret = stmts[len(stmts) - 1];
    assert not facts.is_owned(ret.expr) , "int expression should be borrowed";
}

test "string concatenation is owned" {
    (mod, facts) = _facts("str_ops.jac");
    fn = _find_fn(mod, "run_len");
    concat_assign = list(fn.body)[0];
    assert facts.is_owned(concat_assign.value) , "string concat should be owned";
}

test "proven last uses are recorded for straight-line bodies" {
    (mod, facts) = _facts("obj_rc.jac");
    # run_box is straight-line (inner, box) and run_counter (c, a, b); each
    # local's final read is a provable last use.
    assert len(facts.last_uses) >= 2 , f"expected last-use facts, got {len(
        facts.last_uses
    )}";
}

test "callee conventions mark escaping params consumed and read params borrowed" {
    (mod, facts) = _facts("obj_move.jac");
    # Wrap.init stores its parameter into the sole field and uses it nowhere
    # else -> the parameter is consumed (ownership transfers into the object).
    assert facts.is_consumed("Wrap", 0) , "Wrap.init param should be consumed";
    # Keep.init also reads its parameter (self.seed = inner.get()) -> it is only
    # borrowed, so the conservative default holds.
    assert not facts.is_consumed("Keep", 0) , "Keep.init param should stay borrowed";
    # An unknown callee falls back to borrowed.
    assert not facts.is_consumed("Nope", 0) , "unknown callee must be borrowed";
}

test "get_ownership_facts with no prog and no cache raises" {
    # A freshly compiled module has no cached ownership facts (the pass is lazy,
    # not in the compile schedule). Asking for facts without a prog to build them
    # must fail loudly rather than hand back silent empty facts, mirroring
    # get_type_facts.
    (ir, prog) = _compile("obj_rc.jac");
    assert ir.gen.ownership_facts is None , "fresh module must start with no cached facts";
    raised = False;
    try {
        get_ownership_facts(ir, None);
    } except ValueError {
        raised = True;
    }
    assert raised , "None prog with no cache must raise ValueError";
    # Once built with a real prog, the None-prog cache read succeeds.
    built = get_ownership_facts(ir, prog);
    assert get_ownership_facts(ir, None) is built , "cached read with None prog returns the built facts";
}

test "facts default to the conservative answer for unknown nodes" {
    fresh = OwnershipFacts();
    # An unknown node (here the facts object itself stands in for one) must fall
    # back to borrowed / not-a-last-use, so a consumer that ignores the table
    # stays conservative and correct.
    assert fresh.category_of(fresh) == Ownership.BORROWED , "default category must be borrowed";
    assert not fresh.is_last_use(fresh) , "default last-use must be false";
}
