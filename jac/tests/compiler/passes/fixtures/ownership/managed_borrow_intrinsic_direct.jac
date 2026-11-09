"""An intrinsic called while a managed borrow is live writes no field the
borrow reads through: it reads bits, never a counted field."""

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

def check(p: parser) -> int {
    head: &memo | None = &p.tokens[0].memo_head;
    seen = __float_bits(1.5);
    return seen + (head.rule_type if head is not None else 0);
}
