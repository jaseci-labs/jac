def raising(v: int) -> int {
    if v % 2 == 0 {
        raise ValueError("even");
    }
    raise TypeError("odd");
}

def:pub recover(v: int) -> int {
    try {
        return raising(v);
    } except ValueError {
        return 2;
    } except TypeError {
        return 3;
    }
}
