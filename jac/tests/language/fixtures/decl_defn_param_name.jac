obj SomeClass {
    def method1(some_long_paramenter_name: int) -> None;
    def method2(param1: int, param2: str) -> None;
}

impl SomeClass.method1(short_name: int) -> None {
    print("short_name =", short_name);
}

impl SomeClass.method2(p1: int, p2: str) -> None {
    print("p1 =", p1, ", p2 =", p2);
}

with entry {
    sc = SomeClass();
    sc.method1(42);
    sc.method2(64, "foobar");
}
