"""Fixture for #8085: an explicit `return` inside a `-> None` callable.

`-> None` lowers to an LLVM function returning `void`, and so does a callable
with no `-> T` at all (#7139), so every one of these has to end in
`ret void`. A `return <expr>` that lowered as `ret <expr>` produced a
value-returning terminator inside a void function, which LLVM refuses to
parse -- taking the whole module's codegen with it.

`bump` is called from each of them so the side effect is observable: a return
still has to evaluate its expression before discarding the value.
`discard_forms`, `await_form` and `flow_form` drop a void call's result in
every position that does so, and `reassigned` stores it into a declared
`object | None` slot as None; they must all stay native. `compare_forms`
compares a void call with None directly, which must answer as Python does.
"""

glob COUNTER: int = 0;

obj Box {
    has n: int = 0;

    def touch -> None;
    def touch_call -> None;
    def bare_touch;
}

def bump {
    COUNTER += 1;
}

impl Box.touch -> None {
    self.n += 1;
    return None;
}

impl Box.touch_call -> None {
    return bump();
}

impl Box.bare_touch {
    self.n += 1;
}

def free_fn -> None {
    return None;
}

def discard_forms {
    (bump());
    bump() if COUNTER > 99 else bump();
}

async def abump {
    bump();
}

async def await_form {
    await abump();
}

def flow_form {
    flow bump() ;
}

def reassigned -> (object | None) {
    res: object | None = None;
    res = None if COUNTER > 99 else bump();
    return res;
}

def outer {
    def inner {
        bump();
    }
    inner();
}

def noop {}

def compare_forms -> bool {
    b = Box();
    return noop() is None
        and not (noop() is not None)
        and noop() == None
        and free_fn() is None
        and b.touch() is None
        and b.bare_touch() is None;
}

def run -> int {
    COUNTER = 0;
    if not compare_forms() {
        return -1;
    }
    b = Box();
    b.touch();
    b.touch();
    b.touch_call();
    b.bare_touch();
    free_fn();
    outer();
    discard_forms();
    reassigned();
    return b.n * 100 + COUNTER;
}

with entry {
    assert run() == 305;
    print("ok");
}
