"""Round-trip tests for the ownership qualifier encoding (OwnershipKind).

These pin the two things the single-enum refactor fixed or must not regress:
  1. `jac format` / unparse preserves every qualifier — `own`, `&`, `&mut`,
     `val`. The `val` prefix was previously dropped.
  2. JIR serialize -> deserialize preserves `ownership` as a real OwnershipKind
     on both SubTag (annotation) and UnaryExpr (borrow expression).
"""

import os;
import jaclang.jac0core.unitree as uni;
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.jir_passes { JirWriter, JirReader }
import from jaclang.jac0core.constant { OwnershipKind }

glob FIXTURE = os.path.join(
         JAC_ROOT,
         "tests",
         "compiler",
         "passes",
         "main",
         "fixtures",
         "ownership",
         "roundtrip_all_qualifiers.jac"
     );

def sub_kinds(mod: uni.Module) -> list {
    return [nd.ownership for nd in mod.get_all_sub_nodes(uni.SubTag)];
}

def unary_kinds(mod: uni.Module) -> list {
    return [nd.ownership for nd in mod.get_all_sub_nodes(uni.UnaryExpr)];
}

test "format preserves every ownership qualifier (own/&/&mut/val)" {
    prog = JacProgram.jac_file_formatter(FIXTURE);
    formatted = prog.mod.main.gen.jac;
    for qualifier in ["own Buffer", "&Buffer", "&mut Buffer", "val Buffer"] {
        assert qualifier in formatted , f"'{qualifier}' dropped by format:\n{formatted}";
    }
}

test "JIR round-trip preserves OwnershipKind on SubTag and UnaryExpr" {
    prog = JacProgram();
    mod = prog.compile(FIXTURE, type_check=True);
    before_sub = sub_kinds(mod);
    before_un = unary_kinds(mod);

    blob = JirWriter().write_module(mod);
    mod2 = JirReader().read_module(blob);
    assert mod2 is not None , "JIR read_module returned None";

    after_sub = sub_kinds(mod2);
    after_un = unary_kinds(mod2);

    assert all(isinstance(k, OwnershipKind) for k in after_sub) , f"SubTag ownership not enum: {after_sub}";
    assert all(isinstance(k, OwnershipKind) for k in after_un) , f"Unary ownership not enum: {after_un}";
    assert before_sub == after_sub , f"SubTag ownership changed: {before_sub} -> {after_sub}";
    assert before_un == after_un , f"Unary ownership changed: {before_un} -> {after_un}";

    for kind in [
        OwnershipKind.OWN,
        OwnershipKind.BORROW,
        OwnershipKind.MUT_BORROW,
        OwnershipKind.VAL,

    ] {
        assert kind in after_sub , f"{kind} missing after JIR round-trip: {after_sub}";
    }
}
