def : priv hash(func: Any) {
    def inner(a: Any) {
        print(("#" * 20));
        func(a);
        print(("#" * 20));
    }
    return inner;
}

def : protect exclaim(func: Any) {
    def inner(b: Any) {
        print(("!" * 20));
        func(b);
        print(("!" * 20));
    }
    return inner;
}

@hash
@exclaim
def greeter(name: Any) {
    print("Hello, " + name + "!");
}

with entry {
    greeter("World");
}
