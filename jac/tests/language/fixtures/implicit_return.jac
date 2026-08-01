"""Rust-style implicit returns: the final expression of a function, ability,
or lambda body without a trailing ';' is the return value."""

def add(a: int, b: int) -> int {
    a + b
}

def classify(n: int) -> str {
    if n > 0 {
        return "pos";
    }
    "non-pos"
}

def shout(msg: str) -> str {
    loud = msg.upper();
    loud + "!"
}

obj Greeter {
    has name: str;

    def greet -> str {
        "hello " + self.name
    }

    def farewell -> str;
}

impl Greeter.farewell -> str {
    "bye " + self.name
}

def styled -> dict {
    {"color": "red", "size": 4}
}

def pair(n: int) -> tuple {
    (n, n + 1)
}

with entry {
    print(add(1, 2));
    print(classify(5));
    print(classify(-5));
    print(shout("jac"));
    g = Greeter(name="mars");
    print(g.greet());
    print(g.farewell());
    print(styled());
    print(pair(7));
}

glob single = lambda (x: int) -> int { x * 2 };

with entry {
    print(single(21));
    multi = lambda (x: int) -> int {
        y = x + 1;
        y * 10
    };
    print(multi(3));
}
