"""Tests for non-materializing gen_or_none and py_ast eviction (#7422)."""

import os;
import from tests.support { JAC_ROOT }
import jaclang;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.codeinfo { CodeGenTarget }
import from jaclang.jac0core.passes { PyBytecodeGenPass }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures"
     );


test "CodeGenTarget defaults are falsy" {
    # Guard-check correctness depends on these staying falsy: a future
    # default-flip would turn `if nd.gen_or_none?.py_ast` into always-true.
    t = CodeGenTarget();
    assert not t.jac;
    assert t.es_ast is None;
    assert not t.py_ast;
    assert t.py_bytecode is None;
}


test "gen_or_none does not materialize CodeGenTarget" {
    nd = uni.Module.make_stub();
    assert nd._gen is None;
    assert nd.gen_or_none is None;
    assert nd._gen is None , "gen_or_none must not allocate";

    materialized = nd.gen;
    assert materialized is not None;
    assert nd._gen is materialized;
    assert nd.gen_or_none is materialized;
}


test "Module.evict_py_ast nulls py_ast" {
    prog = JacProgram();
    ir = prog.compile(file_path=os.path.join(FIXTURES, "func.jac"));
    assert ir.gen.py_ast , "expected py_ast before eviction";
    assert ir.gen.py_bytecode is not None;

    # Plant a back-link like PyJacAstLinkPass does, then evict.
    py_root = ir.gen.py_ast[0];
    py_root.jac_link = [ir];
    ir.evict_py_ast();

    assert ir.gen_or_none is not None;
    assert not ir.gen_or_none.py_ast , "evict_py_ast must clear py_ast";
    assert ir.gen.py_bytecode is not None , "bytecode must survive eviction";
    for nd in ir.flatten() {
        assert not (nd.gen_or_none and nd.gen_or_none.py_ast) , (
            "eviction must clear py_ast on every node in the module tree"
        );
    }
}


test "user compile keeps py_ast by default" {
    prog = JacProgram();
    ir = prog.compile(file_path=os.path.join(FIXTURES, "func.jac"));
    assert ir.gen.py_bytecode is not None;
    assert ir.gen.py_ast , "non-internal compiles must keep py_ast by default";
}


test "JAC_PYAST_EVICT_ALL clears py_ast after compile" {
    prev_all = os.environ.get("JAC_PYAST_EVICT_ALL");
    prev_no = os.environ.get("JAC_NO_PYAST_EVICT");
    os.environ.pop("JAC_NO_PYAST_EVICT", None);
    os.environ["JAC_PYAST_EVICT_ALL"] = "1";
    try {
        prog = JacProgram();
        ir = prog.compile(file_path=os.path.join(FIXTURES, "func.jac"));
        assert ir.gen.py_bytecode is not None;
        for nd in ir.flatten() {
            assert not (nd.gen_or_none and nd.gen_or_none.py_ast) , (
                "JAC_PYAST_EVICT_ALL must schedule eviction for user programs"
            );
        }
    } finally {
        if prev_all is None {
            os.environ.pop("JAC_PYAST_EVICT_ALL", None);
        } else {
            os.environ["JAC_PYAST_EVICT_ALL"] = prev_all;
        }
        if prev_no is None {
            os.environ.pop("JAC_NO_PYAST_EVICT", None);
        } else {
            os.environ["JAC_NO_PYAST_EVICT"] = prev_no;
        }
    }
}


test "JAC_NO_PYAST_EVICT is a no-op even with EVICT_ALL" {
    prev_all = os.environ.get("JAC_PYAST_EVICT_ALL");
    prev_no = os.environ.get("JAC_NO_PYAST_EVICT");
    os.environ["JAC_PYAST_EVICT_ALL"] = "1";
    os.environ["JAC_NO_PYAST_EVICT"] = "1";
    try {
        prog = JacProgram();
        ir = prog.compile(file_path=os.path.join(FIXTURES, "func.jac"));
        assert ir.gen.py_bytecode is not None;
        assert ir.gen.py_ast , "JAC_NO_PYAST_EVICT must leave py_ast intact";
    } finally {
        if prev_all is None {
            os.environ.pop("JAC_PYAST_EVICT_ALL", None);
        } else {
            os.environ["JAC_PYAST_EVICT_ALL"] = prev_all;
        }
        if prev_no is None {
            os.environ.pop("JAC_NO_PYAST_EVICT", None);
        } else {
            os.environ["JAC_NO_PYAST_EVICT"] = prev_no;
        }
    }
}


test "PyBytecodeGenPass.post_transform evicts only when the program flag is set" {
    # No dedicated eviction pass: the after-pass hook on PyBytecodeGenPass drops
    # py_ast, gated by JacProgram._evict_py_ast.
    prog = JacProgram();
    ir = prog.compile(file_path=os.path.join(FIXTURES, "func.jac"));
    assert ir.gen.py_ast , "expected py_ast before re-running the pass";
    py_root = ir.gen.py_ast[0];
    py_root.jac_link = [ir];

    # Flag off: re-running the pass regenerates bytecode but keeps py_ast.
    prog._evict_py_ast = False;
    PyBytecodeGenPass(ir_in=ir, prog=prog);
    assert ir.gen.py_bytecode is not None;
    assert ir.gen.py_ast , "post_transform must not evict when the flag is off";

    # Flag on: the hook clears py_ast across the whole module tree.
    prog._evict_py_ast = True;
    PyBytecodeGenPass(ir_in=ir, prog=prog);
    assert ir.gen.py_bytecode is not None , "bytecode must survive eviction";
    for nd in ir.flatten() {
        assert not (nd.gen_or_none and nd.gen_or_none.py_ast) , (
            "post_transform must clear py_ast when the flag is on"
        );
    }
}


test "release_compile_closure evicts py_ast before clearing hub" {
    prog = JacProgram();
    ir = prog.compile(file_path=os.path.join(FIXTURES, "func.jac"));
    assert ir.gen.py_ast;
    py_root = ir.gen.py_ast[0];
    py_root.jac_link = [ir];

    prev = os.environ.get("JAC_NO_UNIT_EVICT");
    os.environ.pop("JAC_NO_UNIT_EVICT", None);
    try {
        prog.release_compile_closure();
        assert not prog.mod.hub;
        assert not ir.gen_or_none.py_ast , (
            "release_compile_closure must share Module.evict_py_ast"
        );
    } finally {
        if prev is None {
            os.environ.pop("JAC_NO_UNIT_EVICT", None);
        } else {
            os.environ["JAC_NO_UNIT_EVICT"] = prev;
        }
    }
}
