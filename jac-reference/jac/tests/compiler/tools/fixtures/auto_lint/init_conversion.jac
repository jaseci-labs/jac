"""Test fixture for __init__ and __post_init__ conversion."""

class Person {
    has name: str;
    has age: int;

    def __init__(self: Person, name: str, age: int) -> None {
        self.name = name;
        self.age = age;
    }

    def greet(self: Person) -> str {
        return f"Hello, I'm {self.name}";
    }
}

class Employee(Person) {
    has employee_id: str;
    has department: str;

    def __init__(self: Employee, name: str, age: int, employee_id: str) -> None {
        super.__init__(name, age);
        Person().__init__(name, age);
        self.employee_id = employee_id;
        __init__ = 5;
        print(__init__);
    }

    def __post_init__(self: Employee) -> None {
        self.department = "Unassigned";
    }
}

obj DataClass {
    has x: int;
    has y: int;
    has computed: int;

    def __post_init__()  -> None {
        self.computed = self.x + self.y;
    }
}
