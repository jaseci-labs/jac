def process_type(cls: type) -> str {
    return "processed";
}

class Animal {}
class Dog(Animal) {}
class Cat(Animal) {}

with entry {
    v1: str = process_type(Animal);  # OK - native Jac class
    v2: str = process_type(Dog);     # OK - subclass
    v3: str = process_type(Cat);     # OK - subclass
    v4: str = process_type(int);     # OK - builtin type
    v5: str = process_type(str);     # OK - builtin type

    e1: str = process_type(Animal());  # Error - instance, not class
}
