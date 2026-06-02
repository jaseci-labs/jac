def make(a: int, b: int, c: int) -> None { }
def greet(name: str, greeting: str) -> None { }

with entry {
    # A `*`/`**` spread of statically-unknown contents may supply a param, but
    # we cannot prove it did -- so a later explicit keyword for that param is
    # NOT a duplicate. None of the calls below should emit E1057.
    nums = (1, 2);
    make(*nums, c=3);  # *-spread covers a, b -- explicit c is not a duplicate

    opts = {"greeting": "hello"};
    greet(**opts, name="bob");  # **-spread covers greeting -- explicit name is fine

    extra = {"b": 2};
    make(1, **extra, c=3);  # positional a + **-spread + explicit c -- none duplicated

    # Preserved behavior: a spread still satisfies the required-param check, so
    # the params it may supply are not reported as missing.
    full = {"a": 1, "b": 2, "c": 3};
    make(**full);
}
