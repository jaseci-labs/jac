"""Test unbound method call type checking (ParentClass.init(self, ...))."""

# Valid: obj type with implicit self
obj Animal {
    def init(name: str) {
        self.name = name;
    }
}

obj Dog(Animal) {
    def init(name: str) {
        Animal.init(self, name=name);
    }
}

# Valid: multiple inheritance
obj BaseNode {
    def init(kid: list) {
        self.kid = kid;
    }
}

obj ChildNode(BaseNode) {
    def init(items: list) {
        BaseNode.init(self, kid=items);
    }
}

# Valid: class with explicit self
class Parent {
    def method(self: Parent, x: int) -> int {
        return x * 2;
    }
}

class Child(Parent) {
    def method(self: Child, x: int) -> int {
        Parent.method(self, x=x);
        return x;
    }
}

# Error: wrong type (int instead of str)
obj Cat(Animal) {
    def init(name: str) {
        Animal.init(self, name=123);
    }  # <-- Error

}

# Error: missing required param
obj Bird(Animal) {
    def init {
        Animal.init(self);
    }  # <-- Error

}

# Valid: static method should NOT be treated as unbound method call
obj Factory {
    static def create(data: str) -> Factory;

    @property
    def runtime -> Factory {
        return Factory.create("test");  # Valid: static method call
    }
}

# Valid: static method with self passed as regular argument (not unbound call)
obj Container {
    has value: str;

    static def from_container(c: Container) -> str {
        return c.value;
    }

    def get_value -> str {
        return Container.from_container(self);  # Valid: self is just an argument
    }
}

with entry {
    print(Dog(name="Buddy").name);
}
