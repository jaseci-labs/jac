"""Torch-gated integration tests for GraphMend predicated control flow.

Confirm the runtime claim that predication defragments the FX graph: compile
each fixture with and without graphmend and count how many contiguous graphs
TorchDynamo's backend actually receives. A data-dependent branch splits the
forward pass into multiple graphs; GraphMend collapses it back to one.

Graph count (via a counting backend) is used rather than
``explain().graph_break_count`` (which under-reports for small functions) or
``fullgraph=True`` (which is stricter than how models actually run).

Skipped automatically when PyTorch is not installed."""
import ast;
import os;
import pytest;
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures", "graphmend"
     );

"""Import torch or skip the calling test."""
def _torch -> any {
    try {
        import torch;
        return torch;
    } except ImportError {
        pytest.skip("torch not installed");
    }
}

"""Compile a fixture (with/without graphmend) and exec its generated Python.

``@torch.compile`` is rebound to identity while exec'ing; the caller drives
the raw function through a counting backend itself."""
def _exec_gm(fixture: str, graphmend: bool) -> dict {
    torch = _torch();
    prog = JacProgram();
    mod = prog.compile(
        file_path=os.path.join(FIXTURES, fixture),
        options=CompileOptions(graphmend=graphmend, type_check=False)
    );
    pa = mod.gen.py_ast;
    src = ast.unparse(pa[0] if isinstance(pa, list) else pa);
    ns: dict = {};
    orig_compile = torch.compile;
    def _shim(*a: any, **k: any) -> any {
        if a {
            return a[0];
        }
        def _wrap(f: any) -> any {
            return f;
        }
        return _wrap;
    }
    torch.compile = _shim;
    try {
        exec(compile(src, fixture, "exec"), ns);
    } finally {
        torch.compile = orig_compile;
    }
    return ns;
}

"""Count the contiguous graphs the backend receives for one call of `fn_name`."""
def _count_graphs(fixture: str, graphmend: bool, fn_name: str, args: tuple) -> int {
    torch = _torch();
    ns = _exec_gm(fixture, graphmend);
    graphs: list = [];
    def _backend(gm: any, inputs: any) -> any {
        graphs.append(gm);
        return gm.forward;
    }
    torch._dynamo.reset();
    torch.compile(ns[fn_name], backend=_backend)(*args);
    return len(graphs);
}

test "data-dependent branches defragment to one contiguous graph" {
    torch = _torch();
    a = torch.tensor([1.0, 2.0, 3.0]);
    b = torch.tensor([4.0, 5.0, 6.0]);
    r = torch.randn(4);
    s = torch.randn(4);
    for (fixture, fn_name, args) in [
        ("where_return.jac", "with_breaks", (a, b)),
        ("where_assign.jac", "f", (a, b)),
        ("cond_assign.jac", "f", (r, s))
    ] {
        orig = _count_graphs(fixture, False, fn_name, args);
        fixed = _count_graphs(fixture, True, fn_name, args);
        assert orig >= 2 , f"{fixture}: expected >=2 graphs without GraphMend, got {orig}";
        assert fixed == 1 , f"{fixture}: expected 1 graph with GraphMend, got {fixed}";
    }
}

test "nested guard in a branch defragments via trap + predication" {
    # A data-dependent branch containing a validation guard collapses to one
    # graph only if trap lowering (assert) composes with predication.
    torch = _torch();
    x = torch.tensor([1.0, 2.0, 3.0]);
    y = torch.tensor([1.0, 2.0, 3.0]);
    orig = _count_graphs("nested_guard_in_branch.jac", False, "f", (x, y));
    fixed = _count_graphs("nested_guard_in_branch.jac", True, "f", (x, y));
    assert orig >= 2 , f"expected >=2 graphs without GraphMend, got {orig}";
    assert fixed == 1 , f"expected 1 graph with GraphMend, got {fixed}";
}

test "re-gated assert stays dormant when its branch is not taken" {
    # The hoisted assert is re-gated on the branch predicate: it must NOT fire
    # when the branch that held it is not taken, even if its check would fail.
    # Here x.sum() <= 0 selects the else branch, so the guard (x == y).all(),
    # which is False, must be vacuously satisfied rather than raising.
    torch = _torch();
    ns = _exec_gm("nested_guard_in_branch.jac", True);
    x = torch.tensor([-1.0, -2.0, -3.0]);
    y = torch.tensor([9.0, 9.0, 9.0]);
    out = ns["f"](x, y);
    assert torch.allclose(out, x * 3.0) , "untaken-branch guard changed result";
}
