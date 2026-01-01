obj car{
    def __init__(model: str, year: int) -> str{
        self.model = model;
        self.year = year;
    }
}

def foo() -> int{
    return 42;
}

with entry{

    mycar = new car("honda civic", 2018);
    f = new foo();
}
