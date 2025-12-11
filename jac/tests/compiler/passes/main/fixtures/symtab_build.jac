obj Person {
    has age: int;

    def greet {
        self.name = "John";
    }

    static def create_person {
        self.first_name = "John";
        self.first_name = 12;
    }

    @classmethod
    def class_info {
        self.type = "Human";
        print("This is the Person class");
    }
}

with entry {
    alice = Person(age=30);
    alice.age = '909';  # <-- Error
}
