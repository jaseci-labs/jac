"""Printing and formatting floats releases every text buffer it builds."""

def half -> float {
    return 1.5;
}

def scaled(i: int) -> float {
    return i * 0.125 + 100.0;
}

def run -> int {
    total = 0;
    for i in range(200) {
        print(half());
        print(scaled(i), -2.5, 3.0);
        s = str(scaled(i));
        a = f"{half()}|{scaled(i):.2f}|{half()!r}";
        b = "v={} w={} n={}".format(half(), scaled(i), i);
        total += len(s) + len(a) + len(b);
    }
    return total;
}

with entry {
    print(run());
    __rc_collect_cycles();
    __rc_debug_enable();
}
