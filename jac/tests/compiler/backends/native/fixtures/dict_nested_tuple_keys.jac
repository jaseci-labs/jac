"""Dictionary keys that hold a boxed tuple, built from a method in a loop."""

obj Binding {
    has provider: str,
        form: str,
        name: str = "",
        alias: str = "";

    def key -> tuple[str, str, str, str] {
        return (self.provider, self.form, self.name, self.alias);
    }
}

def bindings -> list[Binding] {
    return [
        Binding(provider="runtime.na_stdlib._replace_native", form="from", name="x"),
        Binding(provider="runtime.na_stdlib.os", form="from", name="y", alias="z")
    ];
}

def:pub setdefault_nested_keys -> int {
    bound: dict[tuple[str, tuple[str, str, str, str]], int] = {};
    for (i, b) in enumerate(bindings()) {
        bound.setdefault(("", b.key()), i + 1);
    }
    first = bound.get(("", ("runtime.na_stdlib._replace_native", "from", "x", "")));
    second = bound.get(("", ("runtime.na_stdlib.os", "from", "y", "z")));
    names = "".join([k[1][2] for k in bound.keys()]);
    return (
        (first if first is not None else 0) * 100
        + (second if second is not None else 0) * 10
        + (1 if names == "xy" else 0)
    );
}

def:pub get_nested_keys -> int {
    bound: dict[tuple[str, tuple[str, str, str, str]], int] = {};
    bound[("", ("runtime.na_stdlib.os", "from", "y", "z"))] = 7;
    hits = 0;
    for b in bindings() {
        if bound.get(("", b.key()), 0) == 7 {
            hits += 1;
        }
    }
    return hits;
}
