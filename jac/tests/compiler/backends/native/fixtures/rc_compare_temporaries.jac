"""Comparisons must release temporaries without consuming borrowed operands."""
glob dropped: int = 0;
obj Item {
    has value: int = 7;

    def drop {
        dropped += 1;
    }
}

def maybe_item -> Item | None {
    return Item();
}

def maybe_items -> list[Item] | None {
    return [Item()];
}

def boxed_item -> object {
    return Item();
}

def drop_count -> int {
    return dropped;
}

def direct_item -> bool {
    return maybe_item() is not None;
}

def direct_list -> bool {
    return maybe_items() is not None;
}

def none_item -> bool {
    return maybe_item() is None;
}

def reversed_item -> bool {
    return None is not maybe_item();
}

def equal_item -> bool {
    return maybe_item() == None;
}

def unequal_item -> bool {
    return None != maybe_item();
}

def named_item -> bool {
    value = maybe_item();
    ok = value is not None;
    return ok and value.value == 7 if value is not None else False;
}

def named_list -> bool {
    value = maybe_items();
    ok = value is not None;
    return ok and value[0].value == 7;
}

def boxed_none -> bool {
    return boxed_item() is not None;
}

def boxed_reversed -> bool {
    return None is boxed_item();
}

def boxed_identity -> bool {
    return boxed_item() is boxed_item();
}

def boxed_nonidentity -> bool {
    return boxed_item() is not boxed_item();
}

def chain_true -> bool {
    return None is not maybe_item() is not None;
}

def chain_false -> bool {
    return None is maybe_item() is not None;
}

def borrowed(value: Item | None) -> bool {
    return value is not None;
}

def borrowed_item -> bool {
    value = maybe_item();
    ok = borrowed(value);
    return ok and value.value == 7 if value is not None else False;
}

def empty_item -> Item | None {
    return None;
}

def empty_is_none -> bool {
    return empty_item() is None;
}

def empty_is_not_none -> bool {
    return None is not empty_item();
}
