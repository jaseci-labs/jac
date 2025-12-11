import math;

glob RAD = 5;

glob DIA = 10;

# this comment is for walker
walker decorator_walk {
    def hash(func: Any) {
        def inner(a: Any) {
            print(("#" * 20));
            func(a);
            print(("#" * 20));
        }
        return inner;
    }

    def exclaim(func: Any) {
        def inner(b: Any) {
            print(("!" * 20));
            func(b);
            print(("!" * 20));
        }
        return inner;
    }

    def tilde(func: Any) {
        def inner(c: Any) {
            print(("~" * 20));
            func(c);
            print(("~" * 20));
        }
        return inner;
    }

    def greeter(name: Any) {
        print("Hello, " + name + "!");
    }

    # Entry point for the walker
    can start with entry {
        # Apply decorators to greeter
        decorated_greeter = hash(exclaim(tilde(greeter)));

        # Call the decorated greeter function
        decorated_greeter("World");
        # this is another comment
    }
}

with entry {
    root spawn decorator_walk();
}
