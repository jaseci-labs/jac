impl UniPass.postinit -> None {
    super.postinit();
}

impl UniPass.before_pass -> None { }

impl UniPass.after_pass -> None { }

impl UniPass.enter_node(nd: uni.UniNode) -> None {
    nd.accept_enter(self);
}

impl UniPass.exit_node(nd: uni.UniNode) -> None {
    nd.accept_exit(self);
}


impl UniPass.default_enter(nd: uni.UniNode) -> None { }

impl UniPass.default_exit(nd: uni.UniNode) -> None { }

impl UniPass.prune -> None {
    self.prune_signal = True;
}

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
