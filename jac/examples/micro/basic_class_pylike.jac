"""A bit more chill approach."""

obj rson {
    has age: int,
        name: str;

    def init(name: str, age: int) -> None {
        self.name = name;
        self.age = age;
    }

    def greet -> None {
        print("Hello, my name is ", self.name, " and I'm ", self.age, " years old.");
    }
}

with entry {
    Person("John", 42).greet();
}
