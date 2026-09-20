def text(number: int) -> str {
    return "key" + str(number);
}

def optional_text(number: int) -> str | None {
    return text(number);
}

def pair(number: int) -> tuple[str, str] {
    return (text(number), text(number + 1));
}

def check -> bool {
    first = text(42);
    second = text(31);
    maybe = optional_text(17);
    values = pair(50);
    return first == "key42"
        and second == "key31"
        and maybe == "key17"
        and values[0] == "key50"
        and values[1] == "key51";
}

glob dropped = 0;
obj Tracked {
    has value: int;

    def drop {
        dropped += 1;
    }
}

def boxed(value: Tracked) -> tuple[Tracked, int] {
    return (value, 42);
}

def discard_box(value: Tracked) {
    item = boxed(value);
}

def box_preserves_owner -> bool {
    dropped = 0;
    value = Tracked(42);
    discard_box(value);
    return dropped == 0 and value.value == 42;
}
