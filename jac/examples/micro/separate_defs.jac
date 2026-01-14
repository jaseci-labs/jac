"""Modified for separate defs/decls."""

obj MyObj {
    has:protect a: int;

    def:priv init(a: int) -> None;
    def:pub set_a(val: int) -> None;
}

impl MyObj.init{
    self.a = a;
}

impl MyObj.set_a{
    self.a = val;
}
