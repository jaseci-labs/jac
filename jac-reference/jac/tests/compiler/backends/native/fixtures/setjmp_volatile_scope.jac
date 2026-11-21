"""Which locals of a function that arms a setjmp frame stay volatile.

A local is kept in memory only when a protected body writes it before a call
that can raise and the handler path reads that value before writing it again.
"""

def risky(n: int) -> int {
    if n < 0 {
        raise ValueError("negative");
    }
    return n;
}

def loop_after_try(n: int) -> int {
    k = 0;
    try {
        k = risky(n);
    } except ValueError {
        k = 1;
    }
    total = 0;
    i = 0;
    while i < n {
        total = total + i * k;
        i = i + 1;
    }
    return total;
}

def loop_inside_try(n: int) -> int {
    total = 0;
    try {
        i = 0;
        while i < n {
            total = total + risky(i);
            i = i + 1;
        }
    } except ValueError {
        total = -1;
    }
    return total;
}

def read_in_handler(n: int) -> int {
    seen = 5;
    try {
        seen = 7;
        risky(n);
        seen = 9;
    } except ValueError {
        return seen;
    }
    return seen;
}

def stored_after_call(n: int) -> int {
    got = 0;
    try {
        got = risky(n);
    } except ValueError {
        return got - 1;
    }
    total = 0;
    for i in range(got) {
        total += i;
    }
    return total;
}

with entry {
    print(loop_after_try(10), loop_after_try(-3));
    print(loop_inside_try(10));
    print(read_in_handler(-1), read_in_handler(1));
    print(stored_after_call(-1), stored_after_call(4));
}
