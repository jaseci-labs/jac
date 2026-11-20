obj Thing {
    has key: str = "";
}

def make_inc -> any {
    def inc(x: int) -> int {
        return x + 1;
    }
    return inc;
}

def call_each {
    tags: dict[str, any] = {"thing": Thing, "obj": Thing(key="x")};
    for k in ["thing", "obj"] {
        try {
            bad: Callable[[str], str] = tags[k];
            print(bad("b"));
        } except TypeError as e {
            print("TypeError:", e);
        }
    }
}

def boxed_identity {
    def inc(x: int) -> int {
        return x + 1;
    }
    def dec(x: int) -> int {
        return x - 1;
    }
    a: any = inc;
    b: any = inc;
    c: any = dec;
    print(a is b, a is c, a is not b);
}

def seven -> int {
    return 7;
}

def bump_one(x: int) -> int {
    return x + 1;
}

def call_bare(f: Callable) -> int {
    return f() + 1;
}

def call_erased(f: Callable[[], any]) -> any {
    return f();
}

def call_boxed(f: Callable[[any], any], x: int) -> any {
    return f(x);
}

def run -> int {
    total = 0;
    for i in range(50) {
        f: Callable[[int], int] = make_inc();
        total += f(i);
    }
    return total;
}

with entry {
    call_each();
    print(run());
    boxed_identity();
    print(call_bare(seven), call_erased(seven), call_boxed(bump_one, 4));
    __rc_collect_cycles();
    __rc_debug_enable();
}
