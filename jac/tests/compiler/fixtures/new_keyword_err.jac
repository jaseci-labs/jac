obj car{
    has model: string;
    has year: int;
}

def foo() -> int{
    return 42;
}

with entry{
    mycar = new car("honda civic", 2018);
    f = new foo();
}
