"""Local inference under nogc enforcement (#8984 rule 1). Contract positions
stay explicit; an unmarked local takes its state from its right-hand side: a
call, container literal, f-string, concatenation or `own` copy is `own`; a
string literal is `imm`; a field or element read borrows its root, mutably
when the root allows it and the local is written through; a reborrow follows
its source; a conditional whose arms agree takes their state. Each fixture is
compiled through the real type-check schedule with enforcement enabled,
matching `jac build --native --memory nogc`.
"""
import os;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.unitree { Assignment, Name }
import from jaclang.compiler.frontend.constant { OwnershipKind }
import from tests.support { JAC_ROOT }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "fixtures", "nogc_locals"
     );

def enforced(fixture: str) -> tuple {
    path = os.path.join(FIXTURES, fixture);
    prog = JacProgram();
    mod = prog.compile(
        file_path=path, options=CompileOptions(aot_mode=True, memory_profile="nogc")
    );
    codes: set[str] = set();
    for alert in list(prog.errors_had) {
        if alert.code is not None {
            codes.add(alert.code.code);
        }
    }
    return (sorted(codes), mod);
}

def local_states(mod: any) -> dict[str, OwnershipKind] {
    out: dict[str, OwnershipKind] = {};
    for asg in mod.get_all_sub_nodes(Assignment) {
        if len(asg.target) != 1 or asg.type_tag is not None {
            continue;
        }
        tgt = asg.target[0];
        if isinstance(tgt, Name) and tgt.sym is not None and tgt.sym_name not in out {
            out[tgt.sym_name] = tgt.sym.ownership;
        }
    }
    return out;
}

test "unmarked locals infer own, imm and borrows from the right-hand side" {
    (codes, mod) = enforced("infer_clean.jac");
    assert codes == [];
    states = local_states(mod);
    assert states["lit"] == OwnershipKind.IMM;
    assert states["cat"] == OwnershipKind.OWN;
    assert states["tern"] == OwnershipKind.IMM;
    assert states["n"] == OwnershipKind.BORROW;
    assert states["t"] == OwnershipKind.BORROW;
    assert states["m"] == OwnershipKind.BORROW;
    assert states["nm"] == OwnershipKind.BORROW;
    assert states["s"] == OwnershipKind.OWN;
}

test "an element read written through a mutable root infers a mutable borrow" {
    (codes, mod) = enforced("infer_clean.jac");
    assert codes == [];
    kinds: list[str] = [];
    for asg in mod.get_all_sub_nodes(Assignment) {
        if len(asg.target) != 1 or asg.type_tag is not None {
            continue;
        }
        tgt = asg.target[0];
        if isinstance(tgt, Name) and tgt.sym is not None and tgt.sym_name == "it" {
            kinds.append(str(tgt.sym.ownership));
        }
    }
    assert sorted(kinds)
        == sorted([str(OwnershipKind.BORROW), str(OwnershipKind.MUT_BORROW)]);
}

test "E1401: a conditional whose arms disagree is written out by hand" {
    (codes, _) = enforced("ternary_disagree.jac");
    assert codes == ["E1401"];
}

test "E1318: a container mutator through an inferred shared borrow is rejected" {
    (codes, _) = enforced("mutate_through_shared.jac");
    assert codes == ["E1318"];
}

test "an inferred borrow cannot leave as an owned return" {
    (codes, _) = enforced("projection_escape.jac");
    assert codes != [];
    assert all([c.startswith("E13") for c in codes]);
}
