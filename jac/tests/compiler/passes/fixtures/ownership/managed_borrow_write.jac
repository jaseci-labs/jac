"""Writing a field the live borrow was reached through is E1321."""

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
    p.tokens[0].memo_head = None;
    return head.rule_type if head is not None else 0;
}
