"""Clearing a list releases every element. The cleared list may alias the one
the borrow reads through (the rule is about elements on any object, as it is
for fields), so the call is E1322."""

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
        spare: list[token] = [];
}

def check(p: parser) -> int {
    head: &memo | None = &p.tokens[0].memo_head;
    p.spare.clear();
    return head.rule_type if head is not None else 0;
}
