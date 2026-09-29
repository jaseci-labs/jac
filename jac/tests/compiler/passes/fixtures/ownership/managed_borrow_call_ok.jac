"""A call that writes nothing the borrow reads through is accepted."""

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

def peek(t: token) -> int {
    return 1 if t.memo_head is not None else 0;
}

def check(p: parser) -> int {
    head: &memo | None = &p.tokens[0].memo_head;
    seen = peek(p.tokens[0]);
    return seen + (head.rule_type if head is not None else 0);
}
