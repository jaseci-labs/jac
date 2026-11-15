"""Containers read back out of a list through enumerate and zip."""
obj Side {
    has name: str = "";
}

def lengths(groups: list[list[Side]]) -> list[str] {
    out: list[str] = [];
    for (number, sides) in enumerate(groups) {
        out.append(str(number) + ":" + str(len(sides)));
    }
    return out;
}

def nested(groups: list[list[Side]]) -> list[str] {
    out: list[str] = [];
    for (number, sides) in enumerate(groups) {
        for (which, side) in enumerate(sides) {
            out.append(str(number) + str(which) + side.name);
        }
    }
    return out;
}

def paired(rows: list[list[int]], names: list[dict[str, int]]) -> list[int] {
    out: list[int] = [];
    for (row, lookup) in zip(rows, names) {
        out.append(len(row) * 10 + len(lookup) + sum(row));
    }
    return out;
}

def member_counts(groups: list[set[str]]) -> list[int] {
    out: list[int] = [];
    for (index, members) in enumerate(groups) {
        out.append(index + len(members) + (100 if "x" in members else 0));
    }
    return out;
}

with entry {
    groups = [[Side(name="a"), Side(name="b")], [Side(name="c")], []];
    print(lengths(groups));
    print(nested(groups));
    print(paired([[1, 2, 3], [4]], [{"p": 1}, {"q": 2, "r": 3}]));
    print(member_counts([{"x", "y"}, {"z"}]));
}
