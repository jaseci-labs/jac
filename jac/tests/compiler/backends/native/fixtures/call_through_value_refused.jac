obj Thing {
    has key: str = "";

    def tag(n: int) -> str {
        return self.key * n;
    }
}

def store_bound(t: Thing) -> int {
    f: Callable = t.tag;
    return 1 if f else 0;
}

def call_any(tags: dict[str, any], key: str) -> any {
    archetype = tags["thing"];
    return archetype(key=key);
}

def call_bare_keyword(tags: dict[str, any], key: str) -> any {
    ctor: Callable = tags["thing"];
    return ctor(key=key);
}

def call_bare_positional(tags: dict[str, any], key: str) -> any {
    ctor: Callable = tags["thing"];
    return ctor(key);
}

glob tags: dict[str, any] = {"thing": Thing};

with entry {
    print(
        call_any(tags, "a"),
        call_bare_keyword(tags, "b"),
        call_bare_positional(tags, "c")
    );
}
