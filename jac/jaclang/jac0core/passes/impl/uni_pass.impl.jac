"""Implementation for uni_pass constructs."""

"""Initialize parser."""
impl UniPass.postinit -> None {
    super.postinit();
}

"""Run once before pass."""
impl UniPass.before_pass -> None { }

"""Run once after pass."""
impl UniPass.after_pass -> None { }

"""Run on entering node."""
impl UniPass.enter_node(nd: uni.UniNode) -> None {
    import from jaclang.jac0core.helpers { pascal_to_snake }
    if hasattr(self, f"enter_{pascal_to_snake(type(nd).__name__)}") {
        getattr(self, f"enter_{pascal_to_snake(type(nd).__name__)}")(nd);
    }
}

"""Run on exiting node."""
impl UniPass.exit_node(nd: uni.UniNode) -> None {
    import from jaclang.jac0core.helpers { pascal_to_snake }
    if hasattr(self, f"exit_{pascal_to_snake(type(nd).__name__)}") {
        getattr(self, f"exit_{pascal_to_snake(type(nd).__name__)}")(nd);
    }
}

"""Prune traversal."""
impl UniPass.prune -> None {
    self.prune_signal = True;
}

"""Recalculate parents."""
impl UniPass.recalculate_parents(nd: uni.UniNode) -> None {
    if not nd {
        return;
    }
    for i in nd.kid {
        if i {
            i.parent = nd;
            self.recalculate_parents(i);
        }
    }
}

"""Run pass."""
impl UniPass.transform(ir_in: uni.Module) -> uni.Module {
    self.ir_out = ir_in;
    if not isinstance(ir_in, uni.UniNode) {
        return ir_in;
    }
    self.before_pass();
    if not isinstance(ir_in, uni.UniNode) {
        raise self.ice('Current node is not an UniNode.');
    }
    self.traverse(ir_in);
    self.after_pass();
    return self.ir_in;
}

"""Traverse tree."""
impl UniPass.traverse(nd: uni.UniNode) -> uni.UniNode {
    if self.is_canceled() {
        return nd;
    }
    self.cur_node = nd;
    self.enter_node(nd);
    if not self.prune_signal {
        for i in nd.kid {
            if i {
                self.traverse(i);
            }
        }
    } else {
        self.prune_signal = False;
    }
    self.cur_node = nd;
    if self.is_canceled() {
        return nd;
    }
    self.exit_node(nd);
    return nd;
}
