"""Native fixture exercising the C-style iter-for loop.

`for <init> to <cond> by <step> { ... }` runs <init> once, then loops
while <cond> holds, running <step> after each iteration. `break` and
`continue` must respect the step block (continue advances the counter).
"""

def sum_n(n: int) -> int {
    total: int = 0;
    for i = 0; i < n; i += 1 {
        total = total + i;
    }
    return total;
}

def count_down(start: int) -> int {
    c: int = 0;
    for i = start; i > 0; i -= 1 {
        c = c + 1;
    }
    return c;
}

def with_break(n: int) -> int {
    total: int = 0;
    for i = 0; i < n; i += 1 {
        if i == 3 {
            break;
        }
        total = total + i;
    }
    return total;
}

def with_continue(n: int) -> int {
    total: int = 0;
    for i = 0; i < n; i += 1 {
        if i == 2 {
            continue;
        }
        total = total + i;
    }
    return total;
}
