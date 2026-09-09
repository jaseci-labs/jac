"""String prefixes and erased arguments exercise former emitter crashes."""

obj Holder {
    has n: int = 0;
}


def tuple_startswith(s: str) -> int {
    if s.startswith(("'", '"')) {
        return 1;
    }
    return 0;
}


def plain_startswith(s: str) -> int {
    if s.startswith("r") {
        return 1;
    }
    return 0;
}


def takes_holder(h: Holder) -> int {
    return h.n;
}


def arg_shape_mismatch(s: str) -> int {
    # With checking on the critical path a plainly-typed mismatch is refused
    # before codegen, so the type is lost the only way that remains: through
    # an `any` box, which is exactly the "lost its type upstream" shape.
    _s: any = s;
    return takes_holder(_s);
}
