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
    __rc_collect_cycles();
    __rc_debug_enable();
}
