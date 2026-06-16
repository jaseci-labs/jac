"""GraphMend graph-break detection pass tests."""
import os;
import from pathlib { Path }
import jaclang;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.compiler.passes.main.graphmend.graph_break_detect_pass {
    GraphBreakDetectPass
}

glob FIXTURES = os.path.join(
         str(Path(jaclang.__file__).parent.parent),
         "tests",
         "compiler",
         "passes",
         "main",
         "fixtures",
         "graphmend"
     );

"""Compile a fixture and, when `gm`, run ONLY the detection pass.

The transform passes replace the tagged nodes, so tags aren't observable on a
fully-transformed module; we compile without them and run GraphBreakDetectPass
standalone to assert detection in isolation."""
def _compile(name: str, gm: bool, scoped: bool = False) -> uni.Module {
    prog = JacProgram();
    mod = prog.compile(
        file_path=os.path.join(FIXTURES, name),
        options=CompileOptions(graphmend=False, type_check=False)
    );
    if gm {
        prog._compile_options = CompileOptions(graphmend=True, type_check=False);
        setattr(prog, '_graphmend_scoped_compile', scoped);
        GraphBreakDetectPass(ir_in=mod, prog=prog);
    }
    return mod;
}

"""Collect the GraphMend break-kind tag of every IfStmt in a module."""
def _if_kinds(mod: uni.Module) -> list {
    return [n?._gm_break_kind for n in mod.get_all_sub_nodes(uni.IfStmt)];
}

"""Collect non-empty GraphMend break-kind tags of FuncCalls in a module."""
def _call_kinds(mod: uni.Module) -> list {
    out = [];
    for n in mod.get_all_sub_nodes(uni.FuncCall) {
        k = n?._gm_break_kind;
        if k {
            out.append(k);
        }
    }
    return out;
}

test "detects data-dependent control flow" {
    mod = _compile("where_return.jac", True);
    assert "dyn_ctrl_fl" in _if_kinds(mod);
}

test "detects validation guard" {
    mod = _compile("val_guard.jac", True);
    assert "val_guard" in _if_kinds(mod);
}

test "detects print side effect" {
    mod = _compile("side_effect.jac", True);
    assert "side_effect" in _call_kinds(mod);
}

test "detects logger method call as a side effect" {
    mod = _compile("side_effect_logger.jac", True);
    assert "side_effect" in _call_kinds(mod);
}

test "validation guard with cleanup before raise is a val_guard" {
    mod = _compile("guard_multi_stmt.jac", True);
    assert "val_guard" in _if_kinds(mod);
    assert "dyn_ctrl_fl" not in _if_kinds(mod);
}

test "no detection when graphmend disabled" {
    mod = _compile("where_return.jac", False);
    assert _if_kinds(mod) == [None];
}

test "static hasattr control flow is not tagged" {
    mod = _compile("hasattr_static.jac", True);
    assert "dyn_ctrl_fl" not in _if_kinds(mod);
    assert "val_guard" not in _if_kinds(mod);
}

test "detects transitive data-dependence via use-def trace" {
    mod = _compile("where_transitive.jac", True);
    assert "dyn_ctrl_fl" in _if_kinds(mod);
}

test "detects an entry point wrapped at a call site via a variable" {
    mod = _compile("callsite_var.jac", True);
    assert "dyn_ctrl_fl" in _if_kinds(mod);
}

test "whole-module scope tags model code with no local torch.compile entry" {
    # no local entry -> nothing is tagged
    plain = _compile("scoped_module.jac", True);
    assert "dyn_ctrl_fl" not in _if_kinds(plain);
    # under --graphmend-scope (whole-module), the same branch is tagged
    scoped = _compile("scoped_module.jac", True, scoped=True);
    assert "dyn_ctrl_fl" in _if_kinds(scoped);
}
