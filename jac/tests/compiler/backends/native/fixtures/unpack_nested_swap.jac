"""A swap through a nested tuple keeps every object, global or local."""

obj Box {
    has label: str;
}

glob left: Box = Box(label="L"),
     right: Box = Box(label="R"),
     turns: int = 0;

def swap_globals() {
    ((left, turns), right) = ((right, turns + 1), left);
}

def swap_locals(rounds: int) -> str {
    a = Box(label="a");
    b = Box(label="b");
    count = 0;
    for i in range(rounds) {
        ((a, count), b) = ((b, count + 1), a);
        junk = [Box(label="x" + str(i)), Box(label="y" + str(i))];
        count += len(junk) - 2;
    }
    return a.label + b.label + str(count);
}

with entry {
    for i in range(3) {
        swap_globals();
        junk = [Box(label="x" + str(i)), Box(label="y" + str(i))];
        print(left.label, right.label, turns, len(junk));
    }
    print(swap_locals(3));
}
