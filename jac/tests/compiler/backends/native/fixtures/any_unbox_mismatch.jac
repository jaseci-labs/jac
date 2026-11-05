"""A value Python would carry through a typed slot unchanged cannot be held
by a native slot of another type: the read raises TypeError naming both."""
def pick(i: int) -> any {
    items: list[any] = [2.5, "seven"];
    return items[i];
}

with entry {
    try {
        n: int = pick(0);
        print("int", n);
    } except TypeError as e {
        print("TypeError:", e);
    }
    try {
        flag: bool = pick(1);
        print("bool", flag);
    } except TypeError as e {
        print("TypeError:", e);
    }
}
