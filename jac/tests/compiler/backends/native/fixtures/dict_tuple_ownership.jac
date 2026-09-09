"""Dictionary tuple reads preserve object ownership across receiver lifetimes."""
glob dropped: int = 0;
obj DictTupleItem {
    has value: int;

    def drop {
        dropped += 1;
    }
}

def pairs -> dict[str, tuple[DictTupleItem, DictTupleItem]] {
    return {"items": (DictTupleItem(5), DictTupleItem(8))};
}

def local_objects -> int {
    values = pairs();
    (first, second) = values["items"];
    return first.value + second.value;
}

def temporary_objects -> int {
    (first, second) = pairs()["items"];
    return first.value + second.value;
}

def drop_count -> int {
    return dropped;
}
