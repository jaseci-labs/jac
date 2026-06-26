"""Base visitor double-dispatch for UniNode.

The base accept routes to the pass's default hook; `jac gen-uni-dispatch`
generates per-node-kind overrides (in dispatch.impl.jac) that call the pass's
specific enter_<kind>/exit_<kind> ability instead. See unitree.jac UniNode.
"""

impl UniNode.accept_enter(v: UniPass) -> None {
    v.default_enter(self);
}

impl UniNode.accept_exit(v: UniPass) -> None {
    v.default_exit(self);
}
