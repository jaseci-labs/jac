"""Storing an owned value into an unannotated field is still the E1402 seal."""

obj Buffer {
    has n: int = 0;
}

obj Keeper {
    has held: Buffer = Buffer();
}

def use_keeper(k: own Keeper) -> int {
    return k.held.n;
}

with entry {
    a: own Buffer = Buffer();
    k: own Keeper = Keeper();
    k.held = a;
    print(use_keeper(k));
}
