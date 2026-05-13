"""Strict `Any` semantics in Jac modules.

In `.jac` files, `Any` can no longer be silently assigned to a declared
non-Any type. The rule applies uniformly at every "destination has a
declared type" site: annotated assignments, has-var initializers,
function arguments, and return statements. Nested cases like
`list[any] -> list[T]` are caught too — they recurse into the same
element-level `Any -> T` check.

Inferred destinations (no annotation) keep PEP 484 semantics: `Any`
flows through, so users always have an escape valve by simply not
typing the local. Declaring the destination as `any` explicitly is
also fine — that is the user opting in to permissive semantics.
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
    a = make_any();           # a: any (inferred destination — OK)

    # Inferred destination keeps PEP 484 — OK, no error.
    x = a;
    print(x);

    # Explicit `any` annotation — OK, no error.
    y: any = a;
    print(y);

    # Top-level Any -> declared T: ERROR (1)
    t: Task = a;
    print(t);

    # Container nesting: list[any] -> list[Task]: ERROR (2)
    xs: list[any] = [a];
    ts: list[Task] = xs;
    print(ts);

    # Function arg: passing Any to a declared-typed parameter: ERROR (3)
    needs_task(a);
}

def returns_task -> Task {
    # Return Any from a function with a declared non-Any return type: ERROR (4)
    return make_any();
}
