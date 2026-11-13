"""A same-module function whose body is an intrinsic writes no field the
borrow reads through. The checker resolves no ability for an intrinsic
callee, so `bits` inherits "writes anything" and the call is E1322."""

obj memo {
    has rule_type: int,
        end_mark: int,
        next: memo | None = None;
}

obj token {
    has memo_head: memo | None = None;
}

obj parser {
    has tokens: list[token] = [],
        mark: int = 0;
}

def bits(x: float) -> int {
    return __float_bits(x);
}

def check(p: parser) -> int {
    head: &memo | None = &p.tokens[0].memo_head;
    seen = bits(1.5);
    return seen + (head.rule_type if head is not None else 0);
}
