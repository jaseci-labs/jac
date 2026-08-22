"""Erased distinct types (#8030 B1): check-time brand, runtime primitive.

`type X := int;` brands X nominally in the checker while every
lowering (jac0, sv, native) erases it to the base primitive; X(v) is a
zero-cost cast. `obj X(builtin)` is rejected with a pointer at the
distinct form (E1106); a distinct alias over a non-primitive base is
rejected (E1107).
"""

import os;
import from tests.support { JAC_ROOT }
import from jaclang { JacRuntime as Jac }
import from jaclang { JacRuntimeInterface }
import from jaclang.jac0 { compile_jac }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.parser.frontend { parse_diags }

glob FIXTURE_DIR = os.path.join(
         JAC_ROOT, "tests", "compiler", "fixtures", "distinct"
     );


def compile_fixture(name: str) -> list {
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURE_DIR, name), no_cgen=True, type_check=True);
    return prog.errors_had;
}


test "distinct alias parses clean and non-distinct still works" {
    (bad, pdiags, _l) = parse_diags(
        "type NodeId := int;\ntype Plain = int;\n", "d.jac"
    );
    assert not bad , f"parse errors: {[d.message for d in pdiags]}";
}


test "distinct stays usable as an ordinary identifier" {
    (bad, pdiags, _l) = parse_diags(
        "with entry {\n    distinct = 4;\n    print(distinct);\n}\n", "d.jac"
    );
    assert not bad , f"parse errors: {[d.message for d in pdiags]}";
}


test "branded flows compile clean" {
    errs = compile_fixture("brands.jac");
    assert not errs , f"{[str(e) for e in errs]}";
}


test "cross-brand and raw-base assignments are rejected" {
    errs = compile_fixture("brand_violations.jac");
    assert len(errs) == 2 , f"expected 2 brand errors: {[str(e) for e in errs]}";
    assert "UserId" in str(errs[0]);
    assert "GroupId" in str(errs[1]);
}


test "obj inheriting a builtin primitive is E1106" {
    errs = compile_fixture("obj_builtin.jac");
    codes = [
        e.code.code
        for e in errs
        if e.code is not None
    ];
    assert "E1106" in codes , f"{[str(e) for e in errs]}";
}


test "distinct over a non-primitive base is E1107" {
    errs = compile_fixture("bad_base.jac");
    codes = [
        e.code.code
        for e in errs
        if e.code is not None
    ];
    assert "E1107" in codes , f"{[str(e) for e in errs]}";
}


test "runtime value is the erased primitive" {
    Jac.set_base_path(FIXTURE_DIR);
    JacRuntimeInterface.attach_program(JacProgram());
    (m, ) = Jac.jac_import("brands", base_path=FIXTURE_DIR);
    assert m.mk_user(5) == 5;
    assert m.double_user(m.mk_user(5)) == 10;
    assert m.runtime_erased(3) , "type(UserId(x)) must be the erased base";
}


test "jac0 bootstrap erases distinct to a plain alias" {
    py_src = compile_jac(
        "type NodeId := int;\n\ndef f(x: NodeId) -> NodeId {\n"
            + "    return NodeId(x);\n}\n",
        "d.jac"
    );
    assert "NodeId = int" in py_src , py_src;
    assert "distinct" not in py_src , py_src;
}
