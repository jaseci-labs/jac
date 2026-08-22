"""Fixture for #8085: an explicit `return` inside a `-> None` callable.

`-> None` lowers to an LLVM function returning `void`, so every one of these
has to end in `ret void`. A `return <expr>` that lowered as `ret <expr>`
produced a value-returning terminator inside a void function, which LLVM
refuses to parse -- taking the whole module's codegen with it.

`bump` is called from each of them so the side effect is observable: a return
still has to evaluate its expression before discarding the value.
"""

glob COUNTER: int = 0;

obj Box {
    has n: int = 0;

    def touch -> None;
    def touch_call -> None;
}

def bump -> None {
    COUNTER += 1;
}

impl Box.touch -> None {
    self.n += 1;
    return None;
}

impl Box.touch_call -> None {
    return bump();
}

def free_fn -> None {
    return None;
}

def run -> int {
    COUNTER = 0;
    b = Box();
    b.touch();
    b.touch();
    b.touch_call();
    free_fn();
    return b.n * 100 + COUNTER;
}

with entry {
    assert run() == 201;
    print("ok");
}
