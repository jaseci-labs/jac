"""Ownership moves the nogc ownership pass hands on without a retain: a value
built through a class object into an `own` field, a take() and a swap() of
own fields, borrowed text and bytes copied into owned fields, a list of
borrows that never drops what it points at, and an own value returned out of
a comprehension temporary. Drop hooks print each lifetime, so a leak or a
double drop shows up as a diff against the Python backend."""

obj Part {
    has id: int = 0;

    def drop {
        print(f"drop part {self.id}");
    }
}

obj Slot {
    has part: own Part,
        spare: own Part | None = None,
        label: str = "",
        raw: bytes = b"";

    def drop {
        print(f"drop slot {self.label}");
    }
}

def build(kind: type[Slot], n: int) -> own Slot {
    return kind(part=Part(id=n), label=f"s{n}");
}

def label_of(text: &str, data: &bytes) -> own Slot {
    s = Slot(part=Part(id=40), label=text, raw=data);
    return s;
}

def exchange -> int {
    a = Slot(part=Part(id=1), spare=Part(id=2), label="a");
    b = Slot(part=Part(id=3), label="b");
    taken = take(a.spare);
    swap(&mut a.part, &mut b.part);
    print(f"a.part={a.part.id} b.part={b.part.id}");
    if taken is not None {
        print(f"took {taken.id}");
    }
    return a.part.id * 10 + b.part.id;
}

def borrows(xs: &list[own Part]) -> int {
    seen: list[&Part] = [];
    for p in &xs {
        if p.id > 5 {
            seen.append(p);
        }
    }
    return len(seen);
}

def firsts -> int {
    parts = [Part(id=k) for k in range(7, 10)];
    print(f"borrowed {borrows(&parts)}");
    kept = parts.pop();
    return kept.id;
}

def run {
    s = build(Slot, 5);
    print(f"built {s.part.id} {s.label}");
    t = label_of("copied", b"xyz");
    print(f"label {t.label} {len(t.raw)}");
    print(exchange());
    print(firsts());
}

with entry {
    run();
    print("done");
}
