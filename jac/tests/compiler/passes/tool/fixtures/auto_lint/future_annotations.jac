"""Test fixture for future annotations removal."""

import from __future__ { annotations }
import from os { path }

obj Person {
    has name: str,
        age: int;

    def greet(self: Person) -> str {
        return f"Hello, {self.name}!";
    }
}

def main {
    p = Person(name="Alice", age=30);
    print(p.greet());
}
