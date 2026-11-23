"""A borrowed walk over a managed chain that calls a raw-memory helper on
every step. `word_bits` is a same-module function whose body is an
intrinsic; the walk stays a borrow, so the slot holds no reference."""

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

def word_bits(x: float) -> int {
    return __float_bits(x);
}

def borrowed_walk(p: parser, rule_type: int) -> int {
    head: &memo | None = &p.tokens[p.mark].memo_head;
    steps: int = 0;
    while head is not None {
        steps = steps + word_bits(0.0);
        if head.rule_type == rule_type {
            return head.end_mark + steps;
        }
        head = &head.next;
    }
    return -1;
}

def borrowed(rule_type: int) -> int {
    return borrowed_walk(build(), rule_type);
}
