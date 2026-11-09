"""Calls whose callee has no native signature are refused, not miscompiled.

A value typed `any` has no call signature. A bare `Callable` lowers to a
closure taking no arguments, so a keyword or extra positional argument
passed to it has nowhere to go: it used to be dropped (a keyword) or crash
the backend (a positional). Each function here is demoted with a hint.
"""

obj Thing {
    has key: str = "";
}

def call_any(tags: dict[str, any], tag: str, key: str) -> any {
    archetype = tags[tag];
    return archetype(key=key);
}

def call_bare_keyword(tags: dict[str, any], tag: str, key: str) -> any {
    ctor: Callable = tags[tag];
    return ctor(key=key);
}

def call_bare_positional(tags: dict[str, any], tag: str, key: str) -> any {
    ctor: Callable = tags[tag];
    return ctor(key);
}

glob tags: dict[str, any] = {"thing": Thing};
with entry {
    print(call_any(tags, "thing", "a"));
    print(call_bare_keyword(tags, "thing", "b"));
    print(call_bare_positional(tags, "thing", "c"));
}
