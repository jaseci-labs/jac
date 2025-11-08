obj Divider {
    def divide(x: float, y: float) -> float {
        return (x / y);
    }
}
#this is an abstract class as it has the abstract method

obj Calculator {
    static def:priv multiply(a: float, b: float) -> float {
        return a * b;
    }
    def substract -> float abs;
    def add(number: float, *a: tuple) -> float;
}

obj Substractor(Calculator) {
    def substract(x: float, y: float) -> float {
        return (x - y);
    }
}

impl Calculator.add
(number: float, *a: tuple) -> float {
    return (number * sum(a));
}

with entry {
    div = Divider();
    sub = Substractor();
    print(div.divide(55, 11));
    print(Calculator.multiply(9, -2));
    print(sub.add(5, 20, 34, 56));
    print(sub.substract(9, -2));
}
