"""A named element whose binding is dead after the append moves in; live ones copy."""

def dead_after -> int {
    xs: list[str] = [];
    s = f"hel{1}o";
    xs.append(s);
    return len(xs);
}

def alive_after -> int {
    ys: list[str] = [];
    t = f"wor{1}d";
    ys.append(t);
    print(t);
    return len(ys);
}

with entry {
    print(dead_after());
    print(alive_after());
    print("end");
}
