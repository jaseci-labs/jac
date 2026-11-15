"""A caught exception is freed when its handler ends: its object and message
under every handler shape, including one the handler re-raises for an outer
handler to catch, one a newer error replaces, and one left through `continue`,
`break` or `return`."""

obj OutOfRange(IndexError) {}

def inner(i: int) -> int {
    raise OutOfRange(f"inner {i}");
}

def unbound(i: int) -> int {
    try {
        return inner(i);
    } except IndexError {
        return 1;
    }
    return 0;
}

def builtin_bound(i: int) -> int {
    try {
        raise ValueError(f"value {i}");
    } except ValueError as e {
        return len(str(e));
    }
    return 0;
}

def struct_bound(i: int) -> int {
    try {
        raise OutOfRange("literal message");
    } except OutOfRange as e {
        return len(str(e)) + i - i;
    }
    return 0;
}

def rethrow(i: int) -> int {
    try {
        return inner(i);
    } except IndexError {
        raise;
    }
    return 0;
}

def rethrow_named(i: int) -> int {
    try {
        return inner(i);
    } except IndexError as e {
        raise e;
    }
    return 0;
}

def replaced(i: int) -> int {
    try {
        try {
            raise OutOfRange(f"first {i}");
        } except IndexError {
            raise ValueError(f"second {i}");
        }
    } except ValueError as e {
        return len(str(e));
    }
    return 0;
}

def looped(i: int) -> int {
    n = 0;
    for k in range(4) {
        try {
            raise OutOfRange(f"loop {k}");
        } except IndexError as e {
            if k == 1 {
                continue;
            }
            if k == 3 {
                break;
            }
            n += len(str(e));
        }
    }
    return n + i - i;
}

def finals(i: int) -> int {
    n = 0;
    try {
        try {
            raise OutOfRange(f"fin {i}");
        } finally {
            n += 1;
        }
    } except IndexError as e {
        n += len(str(e));
    }
    return n;
}

def runtime(i: int) -> int {
    xs = [1, 2, 3];
    try {
        return xs[i + 10];
    } except IndexError as e {
        return len(str(e));
    }
    return 0;
}

with entry {
    total = 0;
    for i in range(20) {
        try {
            rethrow(i);
        } except IndexError as e {
            total += len(str(e));
        }
        try {
            rethrow_named(i);
        } except Exception as e {
            total += len(str(e));
        }
        total += unbound(i) + builtin_bound(i) + struct_bound(i) + replaced(i);
        total += looped(i) + finals(i) + runtime(i);
    }
    print(total);
}
