"""Enforced: a raising call is clean when every frame up to the entry handles or propagates it."""

def parse_port(s: &str) -> int {
    if len(s) == 0 {
        raise ValueError("empty port");
    }
    return int(s);
}

def load(s: &str) -> int {
    return parse_port(s) + 1;
}

def load_or_default(s: &str) -> int {
    try {
        return load(s);
    } except ValueError {
        return 8080;
    }
}

with entry {
    p: own str = "80";
    print(load_or_default(&p));
}
