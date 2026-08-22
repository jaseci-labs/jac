"""Reading through a container the emitter only sees as a bare pointer.

`CoalesceBBPass.enter_node` searches `bbs['bb_stmts']` -- a `list[UniCFGNode]`
reached through a `dict[int, dict[str, list[...]]]`, whose inner value arrives
as an untyped `i8*` because the outer dict stores pointer-valued entries with
no layout attached. Both reads used to compile to something else entirely:
`bucket['items']` became a character load off the inner dict's header, and
`nd in bucket['items']` handed `strstr` a list (or, for an object needle, a
`%Tag*` that llvmlite rejected outright).

The layout is not recoverable here, so these methods now demote and Python
answers them -- which is what this fixture pins: the same values out of every
lane. `require=["na"]` is deliberately absent; the day the erasure itself is
fixed, turning it on is the test that the shape really lowers.
"""

obj Tag {
    has n: int = 0;
}

obj Bag {
    has words: dict[int, dict[str, list[str]]] = {},
        tags: dict[int, dict[str, list[Tag]]] = {};

    def seed_words {
        self.words[0] = {'items': ["alpha", "beta"]};
    }

    def seed_tags(t: Tag) {
        self.tags[0] = {'items': [t]};
    }

    def has_word(w: str) -> int {
        for bucket in self.words.values() {
            if w in bucket['items'] {
                return 1;
            }
        }
        return 0;
    }

    def lacks_word(w: str) -> int {
        for bucket in self.words.values() {
            if w not in bucket['items'] {
                return 1;
            }
        }
        return 0;
    }

    def has_tag(t: Tag) -> int {
        for bucket in self.tags.values() {
            if t in bucket['items'] {
                return 1;
            }
        }
        return 0;
    }
}

def in_erased_py -> dict {
    b = Bag();
    t1 = Tag(n=1);
    t2 = Tag(n=2);
    b.seed_words();
    b.seed_tags(t1);
    return {
        "has_alpha": b.has_word("alpha"),
        "has_beta": b.has_word("beta"),
        "has_zeta": b.has_word("zeta"),
        "lacks_zeta": b.lacks_word("zeta"),
        "lacks_alpha": b.lacks_word("alpha"),
        "has_t1": b.has_tag(t1),
        "has_t2": b.has_tag(t2)
    };
}

def in_erased_cl -> dict {
    b = Bag();
    t1 = Tag(n=1);
    t2 = Tag(n=2);
    b.seed_words();
    b.seed_tags(t1);
    return {
        "has_alpha": b.has_word("alpha"),
        "has_beta": b.has_word("beta"),
        "has_zeta": b.has_word("zeta"),
        "lacks_zeta": b.lacks_word("zeta"),
        "lacks_alpha": b.lacks_word("alpha"),
        "has_t1": b.has_tag(t1),
        "has_t2": b.has_tag(t2)
    };
}

def in_erased_na -> dict[str, any] {
    b = Bag();
    t1 = Tag(n=1);
    t2 = Tag(n=2);
    b.seed_words();
    b.seed_tags(t1);
    return {
        "has_alpha": b.has_word("alpha"),
        "has_beta": b.has_word("beta"),
        "has_zeta": b.has_word("zeta"),
        "lacks_zeta": b.lacks_word("zeta"),
        "lacks_alpha": b.lacks_word("alpha"),
        "has_t1": b.has_tag(t1),
        "has_t2": b.has_tag(t2)
    };
}
