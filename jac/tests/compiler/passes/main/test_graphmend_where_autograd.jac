"""Predication autograd gate: torch.where evaluates both operands and routes
the untaken one into the backward pass, so the rewrite must decline whenever
the region is reachable under gradient tracking."""
import from tests.support {
    graphmend_break_kinds as _break_kinds,
    graphmend_pysrc as _pysrc
}

test "a backward() call in the module declines predication" {
    src = _pysrc("autograd_backward.jac", True);
    assert "torch.where(" not in src;
    assert "if x.sum() > 0:" in src;
    assert "loss.backward()" in src;
    # detection still tags the break; only the rewrite declines
    assert _break_kinds("autograd_backward.jac") == ["dyn_ctrl_fl"];
}

test "a requires_grad keyword in the module declines predication" {
    src = _pysrc("autograd_requires_grad_kw.jac", True);
    assert "torch.where(" not in src;
    assert "if x.sum() > 0:" in src;
}

test "a requires_grad_ attribute call declines predication" {
    src = _pysrc("autograd_requires_grad_attr.jac", True);
    assert "torch.where(" not in src;
    assert "if x.sum() > 0:" in src;
}

test "a train() call declines predication" {
    src = _pysrc("autograd_train_call.jac", True);
    assert "torch.where(" not in src;
    assert "if x.sum() > 0:" in src;
}

test "a training-flag read declines predication" {
    src = _pysrc("autograd_training_read.jac", True);
    assert "torch.where(" not in src;
    assert "if x.sum() > 0:" in src;
}

test "a grad attribute read declines predication" {
    src = _pysrc("autograd_grad_read.jac", True);
    assert "torch.where(" not in src;
    assert "if x.sum() > 0:" in src;
}

test "a torch.optim import declines predication" {
    src = _pysrc("autograd_optim_path.jac", True);
    assert "torch.where(" not in src;
    assert "if x.sum() > 0:" in src;
}

test "an optimizer-spelled step() call declines predication" {
    src = _pysrc("autograd_optim_step.jac", True);
    assert "torch.where(" not in src;
    assert "if x.sum() > 0:" in src;
}

test "a torch autograd submodule import declines predication" {
    src = _pysrc("autograd_autograd_item.jac", True);
    assert "torch.where(" not in src;
    assert "if x.sum() > 0:" in src;
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

test "enable_grad nested inside no_grad blocks the permit" {
    src = _pysrc("autograd_enable_grad_inner.jac", True);
    assert "torch.where(" not in src;
    assert "if x.sum() > 0:" in src;
}

test "an unrecognized context between the branch and no_grad fails closed" {
    src = _pysrc("autograd_opaque_ctx.jac", True);
    assert "torch.where(" not in src;
    assert "if x.sum() > 0:" in src;
}

test "a shadowed torch root cannot prove its no_grad" {
    src = _pysrc("autograd_shadowed_no_grad.jac", True);
    assert "torch.where(" not in src;
    assert "if x.sum() > 0:" in src;
}

test "an autograd-free module still predicates (coverage guard)" {
    src = _pysrc("where_return.jac", True);
    assert "return torch.where(" in src;
    assert "if " not in src;
}
