def foo() -> str {
    return "Hello";
}

obj vehicle {
    has name: str = "Car";
}

enum Size {
    Small=1, Medium=2, Large=3
}

with entry {
    car = vehicle();
    print(foo());
    print(car.name);
    print(Size.Medium.value);
}