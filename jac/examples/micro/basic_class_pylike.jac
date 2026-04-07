"""A bit more chill approach."""

obj Person {
    has age: int,
        name: str;

    def init(name: str, age: int) {
        self.name = name;
        self.age = age;
    }

    def greet {
        print("Hello, my name is ", self.name, " and I'm ", self.age, " years old.");
    }
}

with entry {
    Person("John", 42).greet();
}
