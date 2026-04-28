"""Test that properties are narrowed through CFG like regular fields."""

obj Holder {
    has _val: int | None = None;

    @property
    def val -> (int | None) {
        return self._val;
    }
}

def check(h: Holder) -> int {
    if h.val {
        return h.val;  # Should be narrowed to int, no E1053

    }
    return 0;
}

def check_isinstance(target: object) -> str {
    if isinstance(target, Holder) and target.val {
        x: int = target.val;  # Should be narrowed to int via AND + property
        return str(x);
    }
    return "none";
}
