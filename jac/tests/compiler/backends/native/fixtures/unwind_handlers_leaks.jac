"""The handler fixture with an RC live-object dump at exit."""

obj AppError(Exception) {
    has code: int = 0,
        detail: list[str] = [];
}

def raise_plain(n: int) -> int {
    if n >= 0 {
        raise ValueError("fixed");
    }
    return n;
}

def raise_obj(n: int) -> int {
    note = f"n={n}";
    if n >= 0 {
        raise AppError(code=n, detail=[note, "x"]);
    }
    return n;
}

def rethrow(n: int) -> int {
    buf = [str(n)];
    try {
        return raise_obj(n) + len(buf);
    } except AppError {
        raise;
    }
}

def run -> int {
    total = 0;
    for i in range(100) {
        try {
            raise_plain(i);
        } except ValueError {
            total += 1;
        }
        try {
            raise_obj(i);
        } except AppError as err {
            total += err.code;
        }
        try {
            raise_obj(i);
        } except AppError {
            total += 2;
        }
        try {
            rethrow(i);
        } except AppError as again {
            total += len(again.detail);
        }
        try {
            [1, 2][i + 5];
        } except IndexError {
            total += 3;
        }
    }
    return total;
}

with entry {
    print(run());
    __rc_collect_cycles();
    __rc_debug_enable();
}
