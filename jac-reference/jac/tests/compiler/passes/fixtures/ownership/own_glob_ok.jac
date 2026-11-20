"""owned module globals: `glob x: own T` puts process-lifetime state in
the owned world -- licensed in enforced modules (no header, no
teardown; the process end is the extent), readable and mutable from
functions, no diagnostics."""

glob counts: own list[int] = [0, 0, 0],
     total: own str = "t" + "0";

def bump(i: int) {
    counts[i] = counts[i] + 1;
}

with entry {
    bump(0);
    bump(2);
    bump(0);
    print(counts[0] + counts[1] + counts[2]);
    print(total);
}
