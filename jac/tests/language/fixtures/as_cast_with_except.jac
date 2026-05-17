"""The `as`-cast must not disturb the `as` alias of `with` / `except`.

`with <ctx> as <name>` and `except <type> as <name>` keep their own `as`,
including when the context/type is a ternary; a parenthesized `(x as T)`
still casts.
"""

import from contextlib { suppress }

with entry {
    flag = True;

    # `with` over a ternary context expression, then its own `as` alias.
    with (suppress(ValueError) if flag else suppress(KeyError)) as ctx {
        print("with-ternary-ok");
    }

    # Parenthesized cast as the context, plus the `with` alias.
    with (suppress(ValueError) as suppress) as ctx2 {
        print("with-paren-cast-ok");
    }

    # `except ... as e` keeps its alias; an `as`-cast is used in the body.
    try {
        raise ValueError("boom");
    } except ValueError as e {
        text: any = str(e);
        print(text as str);
    }
}
