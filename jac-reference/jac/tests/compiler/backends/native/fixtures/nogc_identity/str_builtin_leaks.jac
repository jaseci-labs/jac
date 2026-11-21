"""`str()` copies and `len()` temporaries are freed: nothing leaks under nogc."""

def label(n: int) -> str {
    return f"item{n}";
}

def measure(i: int) -> int {
    t = label(i);
    return len(t) + len(str(t)) + len(label(i));
}

with entry {
    total = 0;
    for i in range(50) {
        total += measure(i);
    }
    print(str("literal"), total);
}
