"""Frozen aliases borrow the region without consuming its owner."""

glob drops: int = 0;

obj Resource {
    def drop {
        drops += 1;
    }
}

def observe_alias -> bool {
    drops = 0;
    region: own Region = Region();
    in region {
        resource = Resource();
    }
    first = imm region;
    second = first;
    explicit: imm Region = second;
    third = explicit;
    return id(first) != 0
        and id(first) == id(second)
        and id(second) == id(explicit)
        and id(explicit) == id(third)
        and drops == 0;
}

def read_drops -> int {
    return drops;
}

def static_alias -> str {
    first: imm str = "stable";
    second = first;
    return second;
}
