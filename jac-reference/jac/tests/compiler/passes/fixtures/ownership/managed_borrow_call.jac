"""A call that may write the field the borrow reads through is E1322."""

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

def clear(p: parser) {
    p.tokens[0].memo_head = None;
}

def check(p: parser) -> int {
    head: &memo | None = &p.tokens[0].memo_head;
    clear(p);
    return head.rule_type if head is not None else 0;
}
