impl UniNode.accept_enter(v: UniPass) -> None {
    v.default_enter(self);
}

impl UniNode.accept_exit(v: UniPass) -> None {
    v.default_exit(self);
}
