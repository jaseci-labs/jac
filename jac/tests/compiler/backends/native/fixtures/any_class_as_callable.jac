"""A class read out of `any` as a `Callable` is refused at the call, not called.

Natively a class value is its name, not a constructor, so it cannot be
called through a closure; reading it as one raises TypeError instead of
jumping through the name's bytes.
"""

obj Thing {
    has key: str = "";
}

def make_label(key: str) -> str {
    return "label:" + key;
}

glob tags: dict[str, any] = {"thing": Thing, "label": make_label};
with entry {
    label: Callable[[str], str] = tags["label"];
    print(label("a"));
    try {
        ctor: Callable[[str], Thing] = tags["thing"];
        print(ctor("b").key);
    } except TypeError as e {
        print("TypeError:", e);
    }
}
