
# Function (full).
def fn1(bar: int, baz: int) -> None {}
sem fn1 = "A function that takes two integers and returns nothing.";
sem fn1.bar = "The first integer parameter.";
sem fn1.baz = "The second integer parameter.";

# Function (Missing baz)
def fn2(bar: int, baz: int) -> None {}
sem fn2 = "A function that takes one integer and returns nothing.";
sem fn2.bar = "The first integer parameter.";

# Function (Without sem at all)
def fn3(bar: int, baz: int) -> None {}

# Architype (with body).
obj Arch1 {
    has bar: int;
    has baz: int;
}
sem Arch1 = "An object that contains two integer properties.";
sem Arch1.bar = "The first integer property.";
sem Arch1.baz = "The second integer property.";

# Architype (without body).
obj Arch2;
impl Arch2 {
    has bar: int;
    has baz: int;
}
sem Arch2 = "An object that contains two integer properties.";
sem Arch2.bar = "The first integer property.";
sem Arch2.baz = "The second integer property.";

# Enum (with body).
enum Enum1 {
    Bar,
    Baz,
}
sem Enum1 = "An enumeration that defines two values: Bar and Baz.";
sem Enum1.Bar = "The Bar value of the Enum1 enumeration.";
sem Enum1.Baz = "The Baz value of the Enum1 enumeration.";

# Enum (without body).
enum Enum2;
impl Enum2 {
    Bar,
    Baz,
}
sem Enum2 = "An enumeration that defines two values: Bar and Baz.";
sem Enum2.Bar = "The Bar value of the Enum2 enumeration.";
sem Enum2.Baz = "The Baz value of the Enum2 enumeration.";

