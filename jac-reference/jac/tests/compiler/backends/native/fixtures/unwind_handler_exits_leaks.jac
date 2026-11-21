"""The handler-exit fixture with an RC live-object dump at exit."""

obj Failure(Exception) {}

obj Wrapped(Exception) {
    has code: int = 0;
}

def required(v: int) -> int {
    if v == 0 {
        raise Failure();
    }
    return v;
}

def return_with_finally(n: int) -> int {
    held: list[int] = [n];
    try {
        return required(n % 2);
    } except Failure {
        return -1;
    } finally {
        held.append(1);
    }
}

def return_plain(n: int) -> int {
    try {
        return required(n % 2);
    } except Failure {
        return -2;
    }
}

def raise_from_handler(n: int) -> int {
    try {
        return required(n % 2);
    } except Failure {
        raise Wrapped(code=n);
    }
}

def nested_in_handler(n: int) -> int {
    try {
        return required(n % 2);
    } except Failure {
        try {
            return required(0);
        } except Failure {
            return -3;
        }
    }
}

def loop_exits(n: int) -> int {
    total = 0;
    for i in range(n) {
        try {
            total += required(i % 3);
        } except Failure {
            if i % 2 == 0 {
                continue;
            }
            break;
        }
    }
    return total;
}

def run -> int {
    total = 0;
    for i in range(100) {
        total += return_with_finally(i) + return_plain(i) + nested_in_handler(i);
        try {
            total += raise_from_handler(i);
        } except Wrapped as err {
            total += err.code;
        }
        total += loop_exits(i % 7);
    }
    return total;
}

with entry {
    print(run());
    __rc_collect_cycles();
    __rc_debug_enable();
}
