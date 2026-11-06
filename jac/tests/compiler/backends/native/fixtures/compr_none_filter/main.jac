"""A comprehension's `is not None` filter tests each element as it was bound."""
obj Pred {
    has n: int = 0,
        inverted: bool = False;
}

obj Finder {
    def find(v: int) -> (Pred | None) {
        if v > 0 {
            return Pred(n=v);
        }
        return None;
    }

    def matched(values: list[int]) -> int {
        preds = [self.find(v) for v in values];
        kept = [
            p
            for p in preds
            if p is not None
        ];
        positive = [
            p
            for p in kept
            if not p.inverted
        ];
        return len(kept) * 10 + len(positive);
    }
}

def chk_compr_none_filter -> int {
    return Finder().matched([1, 0, 2]);
}

with entry {
    print(chk_compr_none_filter());
}
