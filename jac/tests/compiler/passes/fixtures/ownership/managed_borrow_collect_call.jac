"""Collecting cycles while a managed borrow is live may run the `drop` of a
collected cycle, and that `drop` may write the field the borrow reads
through, so the call stays E1322."""

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

obj cleaner {
    has target: parser | None = None,
        partner: cleaner | None = None;

    def drop {
        if self.target is not None {
            self.target.tokens[0].memo_head = None;
        }
    }
}

def check(p: parser) -> int {
    head: &memo | None = &p.tokens[0].memo_head;
    __rc_collect_cycles();
    return head.rule_type if head is not None else 0;
}
