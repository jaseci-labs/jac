"""Structural operations on a list of owned archetypes: pop from the middle,
insert, del, extend from another owned list, and index-assign, each observable
through the element drop hook (#8984 A2, rule 3)."""

obj Cell {
    has v: int = 0;

    def drop { print("drop " + str(self.v)); }
}

def digest(xs: &list[own Cell]) -> str {
    parts: list[str] = [];
    for c in &xs { parts.append(str(c.v)); }
    return ",".join(parts);
}

def run -> int {
    xs: list[own Cell] = [];
    for i in range(5) { xs.append(Cell(v=i)); }
    mid: own Cell = xs.pop(1);
    print("popped " + str(mid.v) + " -> " + digest(&xs));
    xs.insert(0, Cell(v=9));
    print("inserted -> " + digest(&xs));
    del xs[2];
    print("deleted -> " + digest(&xs));
    xs[0] = Cell(v=7);
    print("assigned -> " + digest(&xs));
    ys: list[own Cell] = [];
    ys.append(Cell(v=11));
    ys.append(Cell(v=12));
    xs.extend(ys);
    print("extended -> " + digest(&xs));
    return len(xs);
}

with entry { print(run()); print("done"); }
