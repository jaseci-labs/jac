"""A pop from the list the borrow reads through releases an element, which
may be the token the borrow was reached through, so the call is E1322."""

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
    p.tokens.pop(0);
    return head.rule_type if head is not None else 0;
}
