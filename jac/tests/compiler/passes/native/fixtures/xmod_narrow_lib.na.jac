"""Native cross-module flow-narrowing fixture (issue #6667): the `is not None`
narrowing lives in the LIBRARY, not the consumer. `pick` returns `Box | None`
and `use_it` -- compiled on the imported-dependency path, never as the entry
module -- narrows that union with `if b is not None { ... }` (block narrowing)
and `gone.name if gone is not None else ...` (ternary narrowing), then reads
fields off the narrowed value.

Block / ternary `is not None` narrowing walks the CFG (bb_in/bb_out edges).
The entry-module compile builds that CFG via the full IR-gen schedule; an
imported native module was compiled symtab-only (CFG never built) yet still ran
type inference, so the narrowing silently failed and `b.name` was typed
`Box | None` -> E1099 / E1115 / E1053. The narrowing must apply identically
regardless of whether the module is the entry or an imported dependency."""

obj Box {
    has name: str = "hit";
    has size: int = 5;
}

def pick(flag: bool) -> Box | None {
    if flag {
        return Box();
    }
    return None;
}

def use_it() -> dict[str, any] {
    present = "void";
    sz = -1;
    b = pick(True);
    if b is not None {
        present = b.name;
        sz = b.size;
    }
    gone = pick(False);
    absent = gone.name if gone is not None else "void";
    return {"present": present, "size": sz, "absent": absent};
}
