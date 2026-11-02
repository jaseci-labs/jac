"""The second module defining `node Passage`, `edge Holds`, `obj Info` and
`walker Tally`, with layouts unlike `scoped_arch_routes`'s (fields of other
types, in another order)."""

node Room {
    has name: str;
}

node Passage {
    has width: float,
        label: str,
        doors: int = 0;
}

edge Holds: Room --> Passage {
    has note: str = "",
        depth: float = 0.0;
}

obj Info {
    has label: str,
        scale: float = 1.0;

    def total -> float {
        return self.scale * float(len(self.label));
    }
}

walker Tally {
    has labels: list[str] = [],
        width: float = 0.0;

    can start with Room entry {
        visit [here->:Holds:->];
    }

    can count with Passage entry {
        self.labels.append(here.label);
        self.width += here.width;
    }
}

def build_rooms -> Room {
    r = Room(name="hall");
    r +>:Holds(note="n", depth=0.5):+> Passage(width=2.5, label="east", doors=2);
    r +>:Holds(note="s", depth=1.5):+> Passage(width=1.25, label="west");
    return r;
}

def rooms_desc(r: Room) -> str {
    parts: list[str] = [];
    for p in [r->:Holds:->][?:Passage] {
        parts.append(f"{p.label}:{p.width}:{p.doors}");
    }
    depth = 0.0;
    for e in [edge r->:Holds:->] {
        parts.append(e.note);
        depth += e.depth;
    }
    parts.append(str(depth));
    return ",".join(parts);
}

def rooms_tally(r: Room) -> str {
    t = r spawn Tally();
    return f"{t.labels}/{t.width}";
}

def rooms_info -> float {
    return Info(label="abcd", scale=0.5).total();
}

def is_room_passage(x: any) -> bool {
    return isinstance(x, Passage);
}
