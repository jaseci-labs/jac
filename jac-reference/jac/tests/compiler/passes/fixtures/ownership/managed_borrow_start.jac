"""A borrow rooted at an ordinary local is E1323."""

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
    t = p.tokens[0];
    head: &memo | None = &t.memo_head;
    return head.rule_type if head is not None else 0;
}
