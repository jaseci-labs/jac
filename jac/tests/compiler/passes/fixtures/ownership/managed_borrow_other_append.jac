"""An append to a list the borrow does not read through releases nothing:
an append only adds an element, so it cannot free what the borrow points at
even when the lists alias."""

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
        mark: int = 0,
        log: list[int] = [];
}

def check(p: parser) -> int {
    head: &memo | None = &p.tokens[0].memo_head;
    p.log.append(p.mark);
    return head.rule_type if head is not None else 0;
}
