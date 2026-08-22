obj Animal {
    has legs: int = 4;

    def speak() -> int {
        return 0;
    }

    def get_legs() -> int {
        return self.legs;
    }
}

obj Dog(Animal) {
    def speak() -> int {
        return 1;
    }
}

obj Cat(Animal) {
    def speak() -> int {
        return 2;
    }
}

def test_dog_speak() -> int {
    d: Animal = Dog(legs=4);
    return d.speak();
}

def test_cat_speak() -> int {
    c: Animal = Cat(legs=4);
    return c.speak();
}

def test_inherited_method() -> int {
    d: Animal = Dog(legs=4);
    return d.get_legs();
}

def test_polymorphic(flag: int) -> int {
    a: Animal = Dog(legs=4);
    if flag == 0 {
        a = Cat(legs=4);
    }
    return a.speak();
}
