
enum E {
    A = 0,
    B = 1,
}

sem E = "An enum representing some values.";
sem E.A = "The first value of the enum E.";
sem E.B = "The second value of the enum E.";

obj Person {
    has name: str;
    has yob: int;

    def calc_age(year: int) -> int {
        return year - self.yob;
    }
}


obj OuterClass {
    obj InnerClass {
        has inner_value: str;
    }
}



with entry {
    print(E.A);
}
