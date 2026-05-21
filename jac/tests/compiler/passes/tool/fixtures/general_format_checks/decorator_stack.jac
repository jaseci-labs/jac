import from typing { Callable }

def star(func: Callable) -> Callable {
    def inner(x: any) {
        print(("*" * 30));
        func(x);
        print(("*" * 30));
    }
    return inner;
}

def percent(func: Callable) -> Callable {
    def inner(y: any) {
        print(("%" * 30));
        func(y);
        print(("%" * 30));
    }
    return inner;
}

def percent2(func: Callable) -> Callable {
    def inner(y: any) {
        print(("-" * 30));
        func(y);
        print(("+" * 30));
    }
    return inner;
}

@star
@percent
@percent2
def printer(msg: any) {
    print(msg);
}

with entry {
    printer("Hello");
}
