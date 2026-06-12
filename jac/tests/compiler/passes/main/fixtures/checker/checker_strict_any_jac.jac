"""Strict `Any` semantics in Jac modules.

In `.jac` files, `Any` can no longer be *silently* assigned to a declared
non-Any type: function arguments and return statements reject an `Any`
source. Nested cases like `list[any] -> list[T]` are caught too — they
recurse into the same element-level `Any -> T` check.

An assignment that carries an explicit type annotation (`x: T = ...`,
`has x: T = ...`) is NOT a silent flow: the annotation is the dev
explicitly absorbing the permissive source into a declared type (the
annotation itself is the narrowing), so it is allowed. This is what
makes Python-interop boundaries typable without cast() noise:
    row: tuple[str, str] | None = cursor.fetchone();

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

    # Annotated declaration absorbs Any — OK, no error. The annotation
    # is the dev explicitly typing the Any boundary.
    t: Task = a;
    print(t);

    # Same for containers: the annotation absorbs the permissive source.
    xs: list[any] = [a];
    ts: list[Task] = xs;
    print(ts);

    # Function arg: passing Any to a declared-typed parameter is a
    # SILENT flow: ERROR (1)
    needs_task(a);
}

def returns_task -> Task {
    # Return Any from a function with a declared non-Any return type is a
    # SILENT flow: ERROR (2)
    return make_any();
}
