"""`type(err).__name__` for a caught exception on the native tier.

The name bound by `except ... as err` holds the message when the clause
catches a builtin, so its class used to be read out of a string, which
crashed. The name comes from the exception's type code, or from the object
when a class instance was raised."""
obj Trouble(Exception) {
    has code: int = 0;
}

def kind_of(which: int) -> str {
    xs: list[int] = [1];
    try {
        if which == 0 {
            raise ValueError("boom");
        } elif which == 1 {
            raise Trouble("custom");
        } elif which == 2 {
            return str(xs[5]);
        } elif which == 3 {
            raise RuntimeError("late");
        }
    } except ValueError as verr {
        return f"{type(verr).__name__}/{verr}";
    } except Exception as err {
        return f"{type(err).__name__}/{err}";
    }
    return "none";
}

with entry {
    out = "";
    for rep in range(100) {
        out = " ".join([kind_of(i) for i in range(5)]);
    }
    print(out);
}
