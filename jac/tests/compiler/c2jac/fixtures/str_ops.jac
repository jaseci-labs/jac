"""Runtime-string fixture for the jac2c backend.

String literals stay plain C literals; concatenation, value equality, and length
lower to the jacrt string helpers. Also covers a string-typed object field and a
string-returning method.
"""

obj Named {
    has label: str;

    def init(s: str) {
        self.label = s;
    }

    def greeting -> str {
        return ("Hi " + self.label);
    }
}

def run_len -> int {
    g = "ab" + "cd";
    return len(g);
}

def run_eq -> int {
    a = "foo";
    b = ("f" + "oo");
    if a == b {
        return 1;
    }
    return 0;
}

def run_greet_len -> int {
    n = Named("Bob");
    return len(n.greeting());
}
