"""Assigning a field through a shared borrow is E1320."""

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

def check(p: parser) {
    head: &memo | None = &p.tokens[0].memo_head;
    if head is not None {
        head.end_mark = 1;
    }
}
