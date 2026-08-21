"""Torch-gated: guard lowering collapses the split forward pass back to one FX graph."""
import ast;
import os;
import from tests.support { GRAPHMEND_FIXTURES as FIXTURES }
import from jaclang.jac0core.jaclib { __jac_trap_guard__ }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

"""Import torch or skip the calling test."""
def _torch -> any {
    try {
        import torch;
        return torch;
    } except ImportError {
        testskip("torch not installed");
    }
}

"""Compile a fixture (with/without graphmend) and exec its generated Python.

``@torch.compile`` is rebound while exec'ing: to identity when `eager` is
False (the caller drives the raw function through a counting backend), or to
a REAL eager-backend compile when `eager` is True (the graph-native assert
then fails asynchronously at the call boundary, where the injected
``@__jac_trap_guard__`` decorator catches it -- exactly the production path)."""
def _exec_gm(fixture: str, graphmend: bool, eager: bool) -> dict {
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
        def _wrap(f: any) -> any {
            return orig_compile(f, backend="eager") if eager else f;
        }
        if a {
            return _wrap(a[0]);
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
    ns = _exec_gm(fixture, graphmend, False);
    graphs: list = [];
    def _backend(gm: any, inputs: any) -> any {
        graphs.append(gm);
        return gm.forward;
    }
    torch._dynamo.reset();
    torch.compile(ns[fn_name], backend=_backend)(*args);
    return len(graphs);
}

test "validation guards defragment to one contiguous graph" {
    torch = _torch();
    x = torch.tensor([1.0, 2.0, 3.0]);
    mask = torch.tensor([True, True, True]);
    for (fixture, args) in [
        ("val_guard_all.jac", (x, mask)),
        ("val_guard.jac", (x, x.clone()))
    ] {
        orig = _count_graphs(fixture, False, "f", args);
        fixed = _count_graphs(fixture, True, "f", args);
        assert orig >= 2 , f"{fixture}: expected >=2 graphs without GraphMend, got {orig}";
        assert fixed == 1 , f"{fixture}: expected 1 graph with GraphMend, got {fixed}";
    }
}

test "trap guard restores exception type and message" {
    # A failing tensor-bool guard must surface as the ORIGINAL exception type
    # (ValueError) with the original message, not a raw RuntimeError --
    # restored by the boundary trap-guard decorator after the graph-native
    # assert fails.
    torch = _torch();
    ns = _exec_gm("val_guard_all.jac", True, True);
    x = torch.tensor([1.0, 2.0, 3.0]);
    good = torch.tensor([True, True, True]);
    bad = torch.tensor([True, False, True]);

    torch._dynamo.reset();
    out = ns["f"](x, good);
    assert torch.allclose(out, torch.sin(torch.relu(x)) * 2.0);

    torch._dynamo.reset();
    raised = None;
    try {
        ns["f"](x, bad);
    } except BaseException as e {
        raised = e;
    }
    assert type(raised) is ValueError , f"expected ValueError, got {repr(raised)}";
    assert str(raised) == "mask must be all true" , f"message lost: {repr(raised)}";
    assert "GM-TRAP" not in str(raised) , "internal trap marker leaked to the user";
}

test "declined guard keeps its original exception contract intact" {
    # The counterpart to the two tests above: where the exception cannot be
    # reconstructed at the boundary, GraphMend leaves the guard alone, so the
    # ORIGINAL raise still runs -- full f-string message, interpolation and all.
    # Lowering it anyway would have produced ValueError('').
    torch = _torch();
    ns = _exec_gm("guard_fstring_msg.jac", True, True);
    x = torch.tensor([1.0, 2.0, 3.0]);
    bad = torch.tensor([True, False, True]);

    torch._dynamo.reset();
    raised = None;
    try {
        ns["f"](x, bad);
    } except BaseException as e {
        raised = e;
    }
    assert type(raised) is ValueError , f"expected ValueError, got {repr(raised)}";
    assert "mask must be all true" in str(raised) , f"message lost: {repr(raised)}";
    assert "torch.Size([3])" in str(raised) , f"interpolated detail lost: {repr(
        raised
    )}";
}

test "shape mismatch trips the torch.equal precheck" {
    # (a == b).all() would broadcast [1,2,3] against [[1,2,3]] to True; the
    # static shape/dtype precheck in tensor_eq_assert must keep the lowered
    # guard faithful to torch.equal, which reports them unequal, and raise.
    torch = _torch();
    ns = _exec_gm("val_guard.jac", True, True);
    a = torch.tensor([1.0, 2.0, 3.0]);

    torch._dynamo.reset();
    out = ns["f"](a, a.clone());
    assert torch.allclose(out, torch.sin(torch.relu(a)) * 2.0);

    torch._dynamo.reset();
    raised = None;
    try {
        ns["f"](a, a.reshape(1, 3));
    } except BaseException as e {
        raised = e;
    }
    assert type(raised) is ValueError , f"expected ValueError, got {repr(raised)}";
    assert str(raised) == "unsupported attention mask" , f"message lost: {repr(
        raised
    )}";
}

"""Raise a RuntimeError carrying `text` verbatim (trap-guard parse probe)."""
def _raise_runtime(text: str) {
    raise RuntimeError(text);
}

"""A non-tensor mask: `.all()` matches the guard shape but returns a plain bool."""
obj FakeMask {
    has value: bool = False;

    def all -> bool {
        return self.value;
    }
}

test "non-tensor guard condition keeps its original exception contract" {
    # The `.all()` match is structural; with `mask: any` there is no static
    # proof of tensor-ness, so the lowering DECLINES and the original guard
    # runs unchanged: a duck-typed receiver keeps its exact Python semantics.
    torch = _torch();
    ns = _exec_gm("guard_unproven_receiver.jac", True, False);
    x = torch.tensor([1.0, 2.0, 3.0]);
    out = ns["f"](x, FakeMask(value=True));
    assert torch.allclose(out, torch.sin(torch.relu(x)) * 2.0);
    raised = None;
    try {
        ns["f"](x, FakeMask(value=False));
    } except BaseException as e {
        raised = e;
    }
    assert type(raised) is ValueError , f"expected ValueError, got {repr(raised)}";
    assert str(raised) == "mask must be all true" , f"message lost: {repr(raised)}";
}

test "partial trap-marker text propagates unchanged" {
    # An unrelated RuntimeError that happens to contain marker-like text must
    # come out of the boundary guard exactly as it went in: not an IndexError
    # from an unchecked split, and not a mis-restored exception.
    wrapped = __jac_trap_guard__(_raise_runtime);
    for text in ["dynamo says [[GM-TRAP oops", "[[GM-TRAP ValueError]]never closed"] {
        raised = None;
        try {
            wrapped(text);
        } except BaseException as e {
            raised = e;
        }
        assert type(raised) is RuntimeError , f"wrong type: {repr(raised)}";
        assert str(raised) == text , f"text mangled: {repr(raised)}";
    }
}
