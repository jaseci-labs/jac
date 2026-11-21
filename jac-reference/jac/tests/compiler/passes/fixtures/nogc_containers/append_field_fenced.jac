"""Must fence (E1406): appending an obj field read would alias field storage."""
obj Cfg {
    has name: own str = "";
}

def run -> int {
    c = Cfg(name="n");
    xs = [];
    xs.append(c.name);
    return len(xs);
}

with entry {
    print(run());
}
