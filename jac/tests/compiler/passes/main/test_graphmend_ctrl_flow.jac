"""GraphMend predicated control-flow (torch.where / torch.cond) tests.

Assertions run against the generated Python source (the lowering target),
plus the detection tag table where source alone cannot distinguish "not
detected" from "detected but declined by the predication pass"."""
import ast;
import os;
import tempfile;
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures", "graphmend"
     );

"""Compile a source file and return its generated Python source."""
def _compile_path(path: str, gm: bool) -> str {
    prog = JacProgram();
    mod = prog.compile(
        file_path=path, options=CompileOptions(graphmend=gm, type_check=False)
    );
    pa = mod.gen.py_ast;
    mod_ast = pa[0] if isinstance(pa, list) else pa;
    return ast.unparse(mod_ast);
}

"""Compile a checked-in .jac fixture and return its generated Python source."""
def _pysrc(name: str, gm: bool) -> str {
    return _compile_path(os.path.join(FIXTURES, name), gm);
}

"""Compile a fixture with graphmend on and list the detection tags recorded."""
def _break_kinds(name: str) -> list {
    prog = JacProgram();
    prog.compile(
        file_path=os.path.join(FIXTURES, name),
        options=CompileOptions(graphmend=True, type_check=False)
    );
    return [k.value for k in prog.graphmend_breaks.values()];
}

"""A Python-source model with data-dependent return branches.

Written to a temp file at test time rather than checked in as a .py fixture:
the repository does not accept new Python files, and the point of the fixture
is only that GraphMend ingests .py source, which a generated file exercises
just as well."""
glob PY_WHERE_SRC = '''
import torch


@torch.compile()
def f(a: torch.Tensor, b: torch.Tensor) -> torch.Tensor:
    x = a / (torch.abs(a) + 1)
    if b.sum() < 0:
        return x * (b * -1)
    else:
        return x * (b * -2)
''';

"""Compile the generated .py model above and return its Python lowering."""
def _py_fixture_src(gm: bool) -> str {
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(tmp, "py_where_return.py");
        with open(path, "w") as fh {
            fh.write(PY_WHERE_SRC);
        }
        return _compile_path(path, gm);
    }
}

test "return branches become torch.where" {
    src = _pysrc("where_return.jac", True);
    assert "torch.where(" in src;
    assert "return torch.where(" in src;
    assert "if " not in src;
    assert _break_kinds("where_return.jac") == ["dyn_ctrl_fl"];
}

test "assignment branches become torch.where" {
    src = _pysrc("where_assign.jac", True);
    assert "z = torch.where(" in src;
    assert "if " not in src;
}

test "py source: return branches become torch.where" {
    # The .py front-end (PyastBuildPass) produces UniIR whose nodes unparse
    # differently from .jac-origin nodes, so the rewrite must operate
    # structurally; this guards `jac run model.py --graphmend`.
    src = _py_fixture_src(True);
    assert "return torch.where(" in src;
    assert "if " not in src;
    src = _py_fixture_src(False);
    assert "torch.where(" not in src;
    assert "if " in src;
}

test "common call branches merge differing arg via torch.where" {
    src = _pysrc("where_common_call.jac", True);
    assert "torch.where(" in src;
    # the differing arg is merged inside the single preserved call
    assert "register_buffer('inv_freq', torch.where(" in src;
    assert "persistent=False" in src;
    assert "if " not in src;
}

test "common call merges multiple differing args, preserves kwargs" {
    src = _pysrc("where_multi_arg.jac", True);
    # both differing positional args merged independently; kwarg kept
    assert "combine(torch.where(" in src;
    assert src.count("torch.where(") == 2;
    assert "mode='x'" in src;
    assert "if " not in src;
}

test "item() dynamic signal in return branch becomes torch.where" {
    src = _pysrc("where_item_return.jac", True);
    assert "x.item() > 5" in src;
    assert "return torch.where(" in src;
    assert "if " not in src;
}

test "asymmetric call branches become torch.cond (runs one branch)" {
    src = _pysrc("cond_assign.jac", True);
    assert "z = torch.cond(__gm_cond_0," in src;
    assert "lambda: torch.relu(x) + y" in src;
    assert "lambda: torch.sigmoid(y) - x" in src;
    # not torch.where -- that would evaluate both calls
    assert "torch.where(" not in src;
    assert "if x.sum() > 0:" not in src;
}

test "different callees in branches are left untouched" {
    src = _pysrc("different_callees.jac", True);
    assert "torch.where(" not in src;
    assert "if x.sum() > 0:" in src;
    assert "foo(p)" in src;
    assert "bar(q)" in src;
}

test "static hasattr control flow is not tagged or rewritten" {
    # `if hasattr(self_obj, "flag")` has no tensor-data dependence; Dynamo
    # traces it without a break, so GraphMend must leave it alone. The tag
    # table is checked too: this shape WOULD be rewritten if mis-tagged.
    src = _pysrc("hasattr_static.jac", True);
    assert "torch.where(" not in src;
    assert "if hasattr(self_obj, 'flag')" in src;
    assert _break_kinds("hasattr_static.jac") == [];
}

test "multi-statement branches with shared call hoist and merge" {
    src = _pysrc("where_multi_stmt.jac", True);
    # data-dependent branch becomes a predicate assignment...
    assert "__gm_cond_0 = seq_len > omp" in src;
    assert "if seq_len > omp:" not in src;
    # ...with setups hoisted and the shared call emitted once via torch.where
    assert "register_buffer('inv_freq', torch.where(" in src;
    assert "self_obj.original_inv_freq = self_obj.original_inv_freq.to(device)" in src;
    # static hasattr guards are preserved (not rewritten)
    assert "if hasattr(self_obj.config" in src;
    assert "if not hasattr(self_obj, 'long_inv_freq')" in src;
    # `seq_len > omp` names no dynamic attr inline: only the use-def trace
    # (seq_len derives from torch.max) can tag it, and it must tag ONLY it.
    assert _break_kinds("where_multi_stmt.jac") == ["dyn_ctrl_fl"];
}

test "non-idempotent observable setup write is declined (soundness)" {
    src = _pysrc("where_unsafe_setup.jac", True);
    # `self_obj.calls = self_obj.calls + 1` is an observable, non-idempotent
    # write; hoisting it onto both paths would change state, so the legality
    # check declines and the break is left intact (no predication).
    assert "torch.where(" not in src;
    assert "if seq_len > 8:" in src;
    assert "self_obj.calls = self_obj.calls + 1" in src;
}

test "hasattr guard whose key is not the memoized attribute is declined" {
    src = _pysrc("guard_key_mismatch.jac", True);
    # The `hasattr` header does not close over `counter`/`long_inv_freq`, so the
    # body is not idempotent: matching the guard *shape* alone would hoist a
    # non-idempotent write onto the untaken path. Must decline.
    assert "torch.where(" not in src;
    assert "if seq_len > 8:" in src;
    assert "self_obj.counter = self_obj.counter + 1" in src;
}

test "hasattr guard body with extra observable effects is declined" {
    src = _pysrc("guard_body_effects.jac", True);
    # Key matches the memoized write, but the body also mutates `self_obj.log`;
    # that effect would fire on runs the original never took. Must decline.
    assert "torch.where(" not in src;
    assert "if seq_len > 8:" in src;
    assert "self_obj.log.append('init')" in src;
}

test "hasattr-initialized attribute read outside the region is declined" {
    src = _pysrc("guard_attr_escapes.jac", True);
    # Hoisting creates `long_inv_freq` earlier than the original would; another
    # reader in the module can observe that, so the state change is not
    # confined and the hoist is declined.
    assert "torch.where(" not in src;
    assert "if seq_len > 8:" in src;
}

test "a call paired with a literal branch value is declined" {
    src = _pysrc("call_vs_literal.jac", True);
    # torch.where would speculate the call onto the untaken path; torch.cond
    # cannot return the float. Neither is sound, so the branch stays.
    assert "torch.where(" not in src;
    assert "torch.cond(" not in src;
    assert "if x.sum() > 0:" in src;
    assert "__gm_true_0 = side_effecting" not in src;
}

test "existence-guarded init with an impure initializer is declined" {
    src = _pysrc("guard_impure_init.jac", True);
    # The attribute callee cannot be pinned to one table entry, so every
    # signature-compatible candidate must be pure; `_compute_dirty` prints, so
    # speculating the init could emit output on runs the original never made.
    assert "torch.where(" not in src;
    assert "if seq_len > 8:" in src;
}

test "nested guard in a data-dependent branch composes trap + predication" {
    src = _pysrc("nested_guard_in_branch.jac", True);
    # the data-dependent outer branch is predicated...
    assert "__gm_cond_0 = x.sum() > 0" in src;
    assert "out.copy_(torch.where(__gm_cond_0," in src;
    # ...and the inner validation guard is lowered to a graph-native assert,
    # re-gated on the branch predicate so it only fires when the branch is taken.
    assert "torch._assert_async(" in src;
    assert "torch.logical_or(torch.logical_not(__gm_cond_0), (x == y).all())" in src;
    # no raw control flow / raise survives -- one contiguous graph.
    assert "raise ValueError" not in src;
    assert "if x.sum()" not in src;
    assert "if not (x == y)" not in src;
}

test "nested-compound break preserved when graphmend disabled" {
    src = _pysrc("nested_guard_in_branch.jac", False);
    assert "torch.where(" not in src;
    assert "torch._assert_async(" not in src;
    assert "raise ValueError('x and y must match')" in src;
    assert "if not (x == y).all():" in src;
}

test "control flow preserved when graphmend disabled" {
    src = _pysrc("where_return.jac", False);
    assert "torch.where(" not in src;
    assert "if " in src;
}
