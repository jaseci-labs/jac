import from jaclang.lib.effects { effects }

node Thing { has name: str; }

@effects(reads=["Thing"], writes=[])
def read_things(holder: Root) -> list[str] {
    rows: list[str] = [];
    for t in [holder-->[?:Thing]] {
        rows.append(t.name);
    }
    return rows;
}

def read_things_undeclared(holder: Root) -> list[str] {
    rows: list[str] = [];
    for t in [holder-->[?:Thing]] {
        rows.append(t.name);
    }
    return rows;
}

walker:protect ListThings {
    can start with Root entry {
        report read_things(here);
    }
}

walker:protect ListThingsUndeclared {
    can start with Root entry {
        report read_things_undeclared(here);
    }
}
