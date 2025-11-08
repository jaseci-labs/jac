def foo -> str;

obj vehicle;

enum Size; #implementations

impl foo -> str {
    return ("Hello");
}

impl vehicle  {
    has name: str = "Car";
}

impl Size {
    Small=1,
    Medium=2,
    Large=3
}

with entry {
    car = vehicle();
    print(foo());
    print(car.name);
    print(Size.Medium.value);
}
