"""GraphMend graph-break detection pass tests."""
import os;
import from tests.support { JAC_ROOT }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.compiler.passes.main.graphmend.graph_break_detect_pass {
    GraphBreakDetectPass
}
import from jaclang.compiler.passes.main.graphmend.break_kind { BreakKind }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures", "graphmend"
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

"""Collect the GraphMend break-kind tag of every conditional in a module.

`get_all_sub_nodes` matches the exact node type, so `IfStmt` and `ElseIf` (the
`elif` heads) are queried separately to cover whole if/elif chains."""
def _if_kinds(mod: uni.Module) -> list {
    out = [];
    for n in mod.get_all_sub_nodes(uni.IfStmt) {
        out.append(n?._gm_break_kind);
    }
    for n in mod.get_all_sub_nodes(uni.ElseIf) {
        out.append(n?._gm_break_kind);
    }
    return out;
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
    assert BreakKind.DYN_CTRL_FL in _if_kinds(mod);
}

test "detects validation guard" {
    mod = _compile("val_guard.jac", True);
    assert BreakKind.VAL_GUARD in _if_kinds(mod);
}

test "detects print side effect" {
    mod = _compile("side_effect.jac", True);
    assert BreakKind.SIDE_EFFECT in _call_kinds(mod);
}

test "detects logger method call as a side effect" {
    mod = _compile("side_effect_logger.jac", True);
    assert BreakKind.SIDE_EFFECT in _call_kinds(mod);
}

test "logger method is tagged even if a same-named module function exists" {
    mod = _compile("side_effect_logger_shadow.jac", True);
    assert BreakKind.SIDE_EFFECT in _call_kinds(mod);
}

test "validation guard with cleanup before raise is a val_guard" {
    mod = _compile("guard_multi_stmt.jac", True);
    assert BreakKind.VAL_GUARD in _if_kinds(mod);
    assert BreakKind.DYN_CTRL_FL not in _if_kinds(mod);
}

test "no detection when graphmend disabled" {
    mod = _compile("where_return.jac", False);
    assert all(k is None for k in _if_kinds(mod));
}

test "static hasattr control flow is not tagged" {
    mod = _compile("hasattr_static.jac", True);
    assert BreakKind.DYN_CTRL_FL not in _if_kinds(mod);
    assert BreakKind.VAL_GUARD not in _if_kinds(mod);
}

test "detects transitive data-dependence via use-def trace" {
    mod = _compile("where_transitive.jac", True);
    assert BreakKind.DYN_CTRL_FL in _if_kinds(mod);
}

test "detects a data-dependent elif under a static leading if" {
    mod = _compile("elif_dynamic.jac", True);
    assert BreakKind.DYN_CTRL_FL in _if_kinds(mod);
}

test "a raise inside an elif is not tagged val_guard or dyn_ctrl_fl" {
    mod = _compile("elif_guard.jac", True);
    assert BreakKind.VAL_GUARD not in _if_kinds(mod);
    assert BreakKind.DYN_CTRL_FL not in _if_kinds(mod);
}

test "detects a data-dependent branch in a torch.compile-decorated class" {
    mod = _compile("decorated_class.jac", True);
    assert BreakKind.DYN_CTRL_FL in _if_kinds(mod);
}

test "detects an entry point wrapped at a call site via a variable" {
    mod = _compile("callsite_var.jac", True);
    assert BreakKind.DYN_CTRL_FL in _if_kinds(mod);
}

test "factory call torch.compile(make_model()) does not tag the factory body" {
    mod = _compile("callsite_factory.jac", True);
    assert BreakKind.SIDE_EFFECT not in _call_kinds(mod);
}

test "torch.compile(model) on a parameter does not tag the wrapper body" {
    mod = _compile("callsite_param.jac", True);
    assert BreakKind.DYN_CTRL_FL not in _if_kinds(mod);
}

test "detects a bare function wrapped directly via torch.compile(fn)" {
    mod = _compile("callsite_func.jac", True);
    assert BreakKind.DYN_CTRL_FL in _if_kinds(mod);
}

test "detects an entry passed by keyword: torch.compile(model=Model())" {
    mod = _compile("callsite_kwarg.jac", True);
    assert BreakKind.DYN_CTRL_FL in _if_kinds(mod);
}

test "resolves a reassigned compile target to its last assignment" {
    mod = _compile("callsite_reassign.jac", True);
    assert BreakKind.DYN_CTRL_FL in _if_kinds(mod);
}

test "whole-module scope tags model code with no local torch.compile entry" {
    # no local entry -> nothing is tagged
    plain = _compile("scoped_module.jac", True);
    assert BreakKind.DYN_CTRL_FL not in _if_kinds(plain);
    # under --graphmend-scope (whole-module), the same branch is tagged
    scoped = _compile("scoped_module.jac", True, scoped=True);
    assert BreakKind.DYN_CTRL_FL in _if_kinds(scoped);
}
