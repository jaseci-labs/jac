"""Test unbound method call type checking.

This tests the fix for the "Parameter already matched" error that occurred when
calling unbound methods like ParentClass.init(self, ...) on obj types.
"""

# Test case 1: obj type with implicit self - unbound method call
obj Animal {
    def init(name: str) -> None {
        self.name = name;
    }
}

obj Dog(Animal) {
    def init(name: str) -> None {
        Animal.init(self, name=name);  # <-- Should not error
    }

    def bark() -> str {
        return self.name + " says Woof!";
    }
}

# Test case 2: Multiple inheritance levels
obj UniNode {
    def init(kid: list) -> None {
        self.kid = kid;
    }
}

obj ExprAsItem(UniNode) {
    def init(kid1: list) -> None {
        UniNode.init(self, kid=kid1);  # <-- Should not error
    }
}

obj RaiseStmt(UniNode) {
    def init(kid1: list) -> None {
        UniNode.init(self, kid=kid1);  # <-- Should not error
    }
}

# Test case 3: Regular class with explicit self - should also work
class MyClass {
    def some_method(self: MyClass, x: int) -> int {
        return x * 2;
    }
}

class ChildClass(MyClass) {
    def some_method(self: ChildClass, x: int) -> int {
        MyClass.some_method(self, x=x);  # <-- Should not error
        return x * 3;
    }
}

# Test case 4: Error cases - wrong type should still error
obj Cat(Animal) {
    def init(name: str) -> None {
        Animal.init(self, name=123);  # <-- Should error: int instead of str
    }
}

# Test case 5: Error case - missing required param
obj Bird(Animal) {
    def init() -> None {
        Animal.init(self);  # <-- Should error: missing 'name'
    }
}

with entry {
    dog = Dog(name="Buddy");
    print(dog.bark());
}
