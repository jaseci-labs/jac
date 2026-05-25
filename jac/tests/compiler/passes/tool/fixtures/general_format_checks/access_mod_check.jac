def : priv hash(func: any) -> Callable {
    def inner(a: any) {
        print(("#" * 20));
        func(a);
        print(("#" * 20));
    }
    return inner;
}

def : protect exclaim(func: any) -> Callable {
    def inner(b: any) {
        print(("!" * 20));
        func(b);
        print(("!" * 20));
    }
    return inner;
}

@hash
@exclaim
def greeter(name: any) {
    print("Hello, " + name + "!");
}

with entry {
    greeter("World");
}
