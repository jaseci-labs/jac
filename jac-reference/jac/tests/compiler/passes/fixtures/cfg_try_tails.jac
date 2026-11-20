def f(c: bool) -> int {
    y = 0;
    try {
        if c {
            y = 1;
        }
    } finally {
        y = 2;
    }
    return y;
}

def g(c: bool) -> int {
    y = 0;
    try {
        y = 3;
    } except ValueError {
        y = 4;
    } else {
        y = 5;
    }  finally {
        y = 6;
    }
    return y;
}
