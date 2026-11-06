"""A variadic tuple prints as a tuple, directly, inside a container and
through an any value, and an any value read back is a tuple again."""
def pair(n: int) -> tuple[any, ...] {
    (n, n + 1)
}

def words -> tuple[str, ...] {
    return ("a", "b", "c");
}

def lone -> tuple[int, ...] {
    return (5, );
}

def nothing -> tuple[int, ...] {
    return ();
}

def back(v: any) -> tuple[int, ...] {
    return v;
}

with entry {
    print(pair(7));
    print(words());
    print(lone());
    print(nothing());
    print(f"{words()} and {lone()}");
    print([words(), words()]);
    held: list[any] = [pair(1), words()];
    print(held);
    print(back(lone()));
    print(len(words()), words()[1]);
}
