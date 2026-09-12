"""Native fixture for loop `else` clauses (#8629).

Python loop semantics: the else body runs only when the loop exhausts
normally; a `break` bypasses it. Each probe returns whether the else
body ran, so exhaustion and skip-on-break are observable per loop form.
The forms cover every lowering path: while, C-style iter-for, range for
(indexed), list and string for (iter protocol)."""

def while_else_ran(n: int) -> bool {
    ran: bool = False;
    j: int = 0;
    while j < n {
        j = j + 1;
    } else {
        ran = True;
    }
    return ran;
}

def while_else_break_skips(n: int) -> bool {
    ran: bool = False;
    j: int = 0;
    while j < n {
        if j == 2 {
            break;
        }
        j = j + 1;
    } else {
        ran = True;
    }
    return ran;
}

def iter_for_else_ran(n: int) -> bool {
    ran: bool = False;
    for i = 0 while i < n with i += 1 {
    } else {
        ran = True;
    }
    return ran;
}

def iter_for_else_break_skips(n: int) -> bool {
    ran: bool = False;
    for i = 0 while i < n with i += 1 {
        if i == 2 {
            break;
        }
    } else {
        ran = True;
    }
    return ran;
}

def range_for_else_ran() -> bool {
    ran: bool = False;
    for i in range(3) {
    } else {
        ran = True;
    }
    return ran;
}

def range_for_else_break_skips() -> bool {
    ran: bool = False;
    total: int = 0;
    for i in range(5) {
        if i == 3 {
            break;
        }
        total = total + i;
    } else {
        ran = True;
    }
    return ran and total == 3;
}

def range_for_else_contributes() -> int {
    total: int = 0;
    for i in range(4) {
        total = total + i;
    } else {
        total = total + 1000;
    }
    return total;
}

def list_for_else_ran() -> bool {
    ran: bool = False;
    items = [10, 20, 30];
    for v in items {
    } else {
        ran = True;
    }
    return ran;
}

def list_for_else_break_skips() -> bool {
    ran: bool = False;
    items = [10, 20, 30];
    for v in items {
        if v == 20 {
            break;
        }
    } else {
        ran = True;
    }
    return not ran;
}

def str_for_else_ran() -> bool {
    count: int = 0;
    for c in "abc" {
        count = count + 1;
    } else {
        count = count + 100;
    }
    return count == 103;
}
