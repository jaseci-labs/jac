"""A borrow of a path rooted at a parameter, walked and returned."""

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

def check(p: parser, rule_type: int) -> memo | None {
    head: &memo | None = &p.tokens[p.mark].memo_head;
    while head is not None {
        if head.rule_type == rule_type {
            p.mark = head.end_mark;
            return head;
        }
        head = &head.next;
    }
    return None;
}

def update(p: parser, rule_type: int, mark: int) -> None {
    head: &mut memo | None = &mut p.tokens[0].memo_head;
    while head is not None {
        if head.rule_type == rule_type {
            head.end_mark = mark;
            return;
        }
        head = &mut head.next;
    }
}
