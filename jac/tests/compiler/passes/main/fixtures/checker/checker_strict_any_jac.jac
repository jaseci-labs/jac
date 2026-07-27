"""Uniform gradual `Any` semantics in Jac modules.

`Any` is assignable to every type in every codespace (the standard
mypy/pyright gradual-typing rule), so assigning an `any`-typed value to a
declared non-Any destination is permitted at every "destination has a
declared type" site: annotated assignments, has-var initializers, function
arguments, and return statements, and it recurses into containers
(`list[any] -> list[T]` is fine too).

This replaced an earlier codespace-split policy that rejected `Any -> T`
narrowing in server/client code while permitting it in native (which unboxes
`any` through jacval). Splitting the verdict on identical code by codespace
broke cross-backend congruence; declaring `any` is the opt-in to dynamism,
and consuming it at a concrete type is now honored uniformly.
"""

obj Task {
    has title: str = "";
}

def make_any -> any {
    return 1;
}

def needs_task(t: Task) {
    print(t.title);
}

with entry {
    a = make_any();           # a: any (inferred destination)

    # Inferred destination keeps PEP 484 — OK.
    x = a;
    print(x);

    # Explicit `any` annotation — OK.
    y: any = a;
    print(y);

    # Top-level Any -> declared T: OK (gradual).
    t: Task = a;
    print(t);

    # Container nesting: list[any] -> list[Task]: OK (gradual, recurses).
    xs: list[any] = [a];
    ts: list[Task] = xs;
    print(ts);

    # Function arg: passing Any to a declared-typed parameter: OK (gradual).
    needs_task(a);
}

def returns_task -> Task {
    # Return Any from a function with a declared non-Any return type: OK.
    return make_any();
}
