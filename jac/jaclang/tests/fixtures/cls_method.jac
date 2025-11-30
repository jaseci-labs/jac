"""Test file for class method."""

class MyClass {
    def simple_method()  -> str {
        return "Hello, World1!";
    }

    @classmethod
    def my_method(cls: Type[MyClass]) -> str {
        x = cls.__name__;
        print(x);
        return "Hello, World2!";
    }
}

with entry {
    a = MyClass.simple_method();
    b = MyClass.my_method();
    print(a, b);
}

class MyClass2 {
    def Ability_1(self: MyClass2) -> str;
    @classmethod
    def Ability_2(cls: Type[MyClass2]) -> str;
}

impl MyClass2.Ability_1(self: MyClass2) -> str {
    return "Hello, World!";
}

impl MyClass2.Ability_2{
    return "Hello, World22!";
}

with entry {
    a = MyClass2().Ability_1();
    b = MyClass2.Ability_2();
    print(a, b);
}
