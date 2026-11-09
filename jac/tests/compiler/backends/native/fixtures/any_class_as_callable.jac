"""A class or an instance read out of `any` as a `Callable` raises, not called.

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

glob tags: dict[str, any] = {
         "thing": Thing,
         "label": make_label,
         "instance": Thing(key="x")
     },
     label: Callable[[str], str] = tags["label"];

with entry {
    print(label("a"));
    try {
        ctor: Callable[[str], Thing] = tags["thing"];
        print(ctor("b").key);
    } except TypeError as e {
        print("TypeError:", e);
    }
    try {
        not_fn: Callable[[str], str] = tags["instance"];
        print(not_fn("c"));
    } except TypeError as e {
        print("TypeError:", e);
    }
}
