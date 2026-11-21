"""A `drop` that raises while a frame holds another owned local.

`swap` holds `kept` while it rebinds `bad`, and that release runs
`Bad.drop`, which raises. Python ignores an exception raised by a finalizer
(it prints "Exception ignored in" on stderr), so `swap` goes on and its
return releases `kept`, which runs `Loud.drop`.
"""

glob drops: list[str] = [];

obj Loud {
    has name: str = "";

    def drop {
        drops.append(self.name);
    }
}

obj Bad {
    has v: int = 0;

    def drop {
        raise ValueError(f"bad drop {self.v}");
    }
}

def swap(k: int) -> int {
    kept = Loud(name=f"kept {k}");
    bad: Bad | None = Bad(v=k);
    bad = None;
    if k < 0 {
        raise ValueError("negative");
    }
    return len(kept.name);
}

with entry {
    total = 0;
    for k in range(3) {
        total += swap(k);
    }
    print(total, drops);
}
