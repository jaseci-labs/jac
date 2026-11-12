import from typing { SupportsInt }

obj Meters {
    has value: int = 3;

    def __int__ -> int {
        return self.value;
    }
}

glob MaybeInt = int | None;

def as_int(x: SupportsInt) -> int {
    return int(x);
}

def same(items: Iterable[int]) -> bool {
    return items == items and items.__class__ is not None;
}

def maybe(name: "Meters" | None, flags: set[int]) -> (str, int) | None {
    flags = flags | {1};
    return None;
}

def leaked(text: str, pair: tuple[int, int]) {
    text.__ror__(1);
    pair.__or__(None);
    a = text | None;
    b = pair | None;
}

with entry {
    as_int(Meters());
    same([1, 2]);
    as_int("text");
}
