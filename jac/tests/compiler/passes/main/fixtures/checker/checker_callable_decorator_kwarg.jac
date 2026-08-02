import from typing { Callable }

def deco(f: Callable) -> Callable {
    return f;
}

def command(name: str) -> Callable[[Callable], Callable] {
    def wrap(f: Callable) -> Callable {
        return f;
    }
    return wrap;
}

@deco
def bar(a: int = 0, b: str = "") -> int {
    return a;
}

@command("run")
def baz(a: int = 0, b: str = "") -> int {
    return a;
}

def call_kw -> int {
    return bar(a=1, b="x");
}

def call_pos -> int {
    return bar(1, "x");
}

def call_factory_kw -> int {
    return baz(a=2, b="y");
}
