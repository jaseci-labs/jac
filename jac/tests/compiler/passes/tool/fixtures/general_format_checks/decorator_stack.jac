def star(func: Any) {
    def inner(x: Any) {
        print(("*" * 30));
        func(x);
        print(("*" * 30));
    }
    return inner;
}

def percent(func: Any) {
    def inner(y: Any) {
        print(("%" * 30));
        func(y);
        print(("%" * 30));
    }
    return inner;
}

def percent2(func: Any) {
    def inner(y: Any) {
        print(("-" * 30));
        func(y);
        print(("+" * 30));
    }
    return inner;
}

@star
@percent
@percent2
def printer(msg: Any) {
    print(msg);
}

with entry {
    printer("Hello");
}
