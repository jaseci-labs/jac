"""An error raised while an object is written out leaves it printable."""

obj Fussy {
    has mood: int = 0;

    def __repr__() -> str {
        if self.mood > 0 {
            raise ValueError("not now");
        }
        return "calm";
    }
}

obj Holder {
    has name: str,
        inner: Fussy;
}

def show(h: Holder) -> str {
    return str(h);
}

def deeper(h: Holder, levels: int) -> str {
    if levels > 0 {
        return deeper(h, levels - 1);
    }
    return show(h);
}

with entry {
    h = Holder(name="h", inner=Fussy());
    print(show(h));
    h.inner.mood = 1;
    try {
        print(show(h));
    } except ValueError as e {
        print("refused:", e);
    }
    h.inner.mood = 0;
    print(deeper(h, 5));
    print(show(h));
}
