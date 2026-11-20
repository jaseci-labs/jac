glob first: str = "a",
     second: str = "b";
glob count: int = 0;
glob names: list[str] = [];
glob maybe: str | None = None;

def swap {
    (first, second) = (second, first);
}

def reset(tag: str) {
    (first, second, count) = (tag + "1", tag + "2", count + 1);
}

def collect(extra: str) {
    (names, maybe) = (names + [extra], extra);
}

def local_only -> str {
    (left, right) = ("l", "r");
    return left + right;
}

with entry {
    (first, second, count) = ("Hello", "World", 1);
    print(first, second, count);
    swap();
    print(first, second, count);
    reset("x");
    reset("y");
    print(first, second, count);
    collect("p");
    collect("q");
    print(names, maybe, local_only());
}
