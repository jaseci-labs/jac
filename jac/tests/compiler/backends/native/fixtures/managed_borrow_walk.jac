"""A borrowed walk over a managed chain, and the same walk owning it."""

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

def build -> parser {
    p = parser();
    t = token();
    t.memo_head = memo(
        rule_type=1,
        end_mark=11,
        next=memo(rule_type=2, end_mark=22, next=memo(rule_type=3, end_mark=33))
    );
    p.tokens.append(t);
    return p;
}

def borrowed_walk(p: parser, rule_type: int) -> int {
    head: &memo | None = &p.tokens[p.mark].memo_head;
    while head is not None {
        if head.rule_type == rule_type {
            return head.end_mark;
        }
        head = &head.next;
    }
    return -1;
}

def owning_walk(p: parser, rule_type: int) -> int {
    head = p.tokens[p.mark].memo_head;
    while head is not None {
        if head.rule_type == rule_type {
            return head.end_mark;
        }
        head = head.next;
    }
    return -1;
}

def borrowed(rule_type: int) -> int {
    return borrowed_walk(build(), rule_type);
}

def owning(rule_type: int) -> int {
    return owning_walk(build(), rule_type);
}
