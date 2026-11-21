"""Under enforcement `raise` propagates through a hidden error slot instead of
an unwinder: a raising callee returns to a handling caller, owned locals on
the error path drop at their static points, and `finally` runs, identically
in every memory mode (#8984 rule 6)."""

obj Cfg {
    has port_text: str = "80";
}

obj Guard {
    has id: int = 0;

    def drop { print("drop " + str(self.id)); }
}

def parse_port(s: &str) -> int {
    if len(s) == 0 {
        raise ValueError("empty port");
    }
    return int(s);
}

def load(cfg: &Cfg) -> int {
    g: own Guard = Guard(id=1);
    return parse_port(&cfg.port_text) + 1;
}

def load_or_default(cfg: &Cfg) -> int {
    try {
        return load(cfg);
    } except ValueError {
        return 8080;
    }
}

def run -> None {
    c: own Cfg = Cfg();
    print(load_or_default(&c));
    c.port_text = "";
    print(load_or_default(&c));
    try {
        print(parse_port(&c.port_text));
    } except ValueError {
        print("caught");
    } finally {
        print("finally");
    }
}

with entry { run(); print("done"); }
