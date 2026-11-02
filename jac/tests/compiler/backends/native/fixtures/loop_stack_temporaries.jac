import os;

def spin(n: int) -> int {
    total = 0;
    for i in range(n) {
        p = os.path.realpath("/tmp/../tmp");
        s = ("  x" + str(i % 7) + "  ").strip();
        total += len(p) + len(s) + (1 if os.path.exists(p) else 0);
    }
    return total;
}

with entry {
    print(spin(50000) > 0);
}
