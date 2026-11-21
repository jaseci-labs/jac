"""int() of an optional value: a local, a node field and an IntEnum field."""
import from enum { IntEnum, auto }

class Cat(IntEnum) {
    with entry {
        A = auto();
        B = auto();
    }
}

node P {
    has n: (int | None) = None,
        cat: (Cat | None) = None;

    def code -> int {
        if self.cat is None {
            return 0;
        }
        return int(self.cat);
    }
}

def of_none(c: (int | None)) -> str {
    try {
        return str(int(c));
    } except TypeError {
        return "E";
    }
}

def of_local -> int {
    c: (int | None) = 2;
    if c is not None {
        return int(c);
    }
    return -1;
}

with entry {
    print("local", of_local());
    p = P(n=7, cat=Cat.B);
    if p.n is not None {
        print("field", int(p.n));
    }
    print("enum", p.code(), P().code());
    print("none", of_none(None), of_none(5));
}
