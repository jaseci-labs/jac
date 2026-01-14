"""Basic class implementation and spawning example."""

obj Person {
    has:protect age: int;  # no need ot use `_age`
    has:pub name: str;

    def:priv init(name: str, age: int) -> None {
        self.name = name;
        self.age = age;
    }

    def:pub greet -> None {  # public is default if `pub` is not specified
        print("Hello, my name is ", self.name, " and I'm ", self.age, " years old.");
    }
}

glob my_guy = Person("John", 42);

with entry {
    my_guy.greet();
}
