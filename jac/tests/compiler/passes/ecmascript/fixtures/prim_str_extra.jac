"""String methods not covered by prim_str_methods / prim_jac_runtime.

Covers: format_map, expandtabs, translate + maketrans, op_mod (%), encode.
"""

def str_extra_py() -> dict {
    # format_map
    fm1: str = "{name} is {age}".format_map({"name": "Bob", "age": "30"});
    fm2: str = "{x}{y}{x}".format_map({"x": "a", "y": "b"});

    # expandtabs — use chr(9) to construct tab chars (avoids escape issues in JS compilation)
    tab: str = chr(9);
    et1: str = ("a" + tab + "b" + tab + "c").expandtabs(4);
    et2: str = (tab + tab).expandtabs(8);
    et3: str = "no tabs here".expandtabs(4);

    # maketrans + translate
    table = str.maketrans("helo", "HELO");
    tr1: str = "hello world".translate(table);

    # op_mod (string formatting)
    mod1: str = "Hello %s" % "world";
    mod2: str = "Value: %d" % 42;

    # encode — convert to list of ints for JSON comparison
    enc1: list = list("hello".encode());
    enc2: list = list("".encode());

    return {
        "fm1": fm1, "fm2": fm2,
        "et1": et1, "et2": et2, "et3": et3,
        "tr1": tr1,
        "mod1": mod1, "mod2": mod2,
        "enc1": enc1, "enc2": enc2
    };
}

cl def str_extra_cl() -> dict {
    fm1: str = "{name} is {age}".format_map({"name": "Bob", "age": "30"});
    fm2: str = "{x}{y}{x}".format_map({"x": "a", "y": "b"});

    tab: str = chr(9);
    et1: str = ("a" + tab + "b" + tab + "c").expandtabs(4);
    et2: str = (tab + tab).expandtabs(8);
    et3: str = "no tabs here".expandtabs(4);

    table = str.maketrans("helo", "HELO");
    tr1: str = "hello world".translate(table);

    mod1: str = "Hello %s" % "world";
    mod2: str = "Value: %d" % 42;

    enc1: list = list("hello".encode());
    enc2: list = list("".encode());

    return {
        "fm1": fm1, "fm2": fm2,
        "et1": et1, "et2": et2, "et3": et3,
        "tr1": tr1,
        "mod1": mod1, "mod2": mod2,
        "enc1": enc1, "enc2": enc2
    };
}
