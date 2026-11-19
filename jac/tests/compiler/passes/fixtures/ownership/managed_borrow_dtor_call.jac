"""The intrinsic that runs a destructor may free anything, so calling it
while a managed borrow is live stays E1322."""

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
        dtor: int = 0,
        victim: int = 0;
}

def check(p: parser) -> int {
    head: &memo | None = &p.tokens[0].memo_head;
    __mem_call_dtor(p.dtor, p.victim);
    return head.rule_type if head is not None else 0;
}
