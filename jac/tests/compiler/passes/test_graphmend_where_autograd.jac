"""Predication autograd gate: torch.where evaluates both operands and routes
the untaken one into the backward pass, so the rewrite must decline whenever
the region is reachable under gradient tracking."""
import from jaclang.testing.test { parametrize }
import from tests.support {
    graphmend_break_kinds as _break_kinds,
    graphmend_pysrc as _pysrc
}

glob AUTOGRAD_DECLINES = [
         ("requires_grad keyword", "autograd_requires_grad_kw.jac"),
         ("requires_grad_ attribute call", "autograd_requires_grad_attr.jac"),
         ("train() call", "autograd_train_call.jac"),
         ("training-flag read", "autograd_training_read.jac"),
         ("grad attribute read", "autograd_grad_read.jac"),
         ("torch.optim import", "autograd_optim_path.jac"),
         ("optimizer-spelled step() call", "autograd_optim_step.jac"),
         ("torch autograd submodule import", "autograd_autograd_item.jac"),
         ("enable_grad nested inside no_grad", "autograd_enable_grad_inner.jac"),
         ("unrecognized context before no_grad", "autograd_opaque_ctx.jac"),
         ("shadowed torch root cannot prove no_grad", "autograd_shadowed_no_grad.jac")
     ];

def _autograd_declines(row: tuple[any, ...]) {
    src = _pysrc(row[1], True);
    assert "torch.where(" not in src , f"{row[0]}: predication must decline";
    assert "if x.sum() > 0:" in src , f"{row[0]}: original branch must survive";
}

with entry {
    parametrize(
        "autograd signal declines predication",
        AUTOGRAD_DECLINES,
        _autograd_declines,
        id_fn=lambda (c: tuple[any, ...]) -> str { return c[0]; }
    );
}

test "a backward() call in the module declines predication" {
    src = _pysrc("autograd_backward.jac", True);
    assert "torch.where(" not in src;
    assert "if x.sum() > 0:" in src;
    assert "loss.backward()" in src;
    # detection still tags the break; only the rewrite declines
    assert _break_kinds("autograd_backward.jac") == ["dyn_ctrl_fl"];
}

test "a branch inside torch.no_grad() still predicates in a training module" {
    src = _pysrc("autograd_no_grad_with.jac", True);
    assert "z = torch.where(" in src;
    assert "if x.sum() > 0:" not in src;
    assert "with torch.no_grad():" in src;
    assert "loss.backward()" in src;
}

test "a no-arg inference_mode decorator on the entry still predicates" {
    src = _pysrc("autograd_inference_deco.jac", True);
    assert "z = torch.where(" in src;
    assert "if x.sum() > 0:" not in src;
    assert "loss.backward()" in src;
}

test "an autograd-free module still predicates (coverage guard)" {
    src = _pysrc("where_return.jac", True);
    assert "return torch.where(" in src;
    assert "if " not in src;
}
