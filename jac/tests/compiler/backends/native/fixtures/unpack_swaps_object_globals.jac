"""A swap of two module globals that hold objects keeps both objects."""

obj Box {
    has label: str;
}

glob left: Box = Box(label="L"),
     right: Box = Box(label="R");

def swap() {
    (left, right) = (right, left);
}

with entry {
    for i in range(3) {
        swap();
        junk = [Box(label="x" + str(i)), Box(label="y" + str(i))];
        print(left.label, right.label, len(junk));
    }
}
