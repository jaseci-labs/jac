"""An insert into the list the borrow reads through shifts its elements but
releases none of them: the token the borrow was reached through stays alive
at a new index."""

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
    fresh = token();
    head: &memo | None = &p.tokens[0].memo_head;
    p.tokens.insert(0, fresh);
    return head.rule_type if head is not None else 0;
}
