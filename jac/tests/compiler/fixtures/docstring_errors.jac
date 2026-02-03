"""Test docstring placement errors."""

obj Person {
    has name: str;

    def greet() -> str {
        """This docstring is inside the function body - should error"""
        return f"Hello, {self.name}!";
    }

    def farewell() -> str {
        '''Another docstring inside function body'''
        return f"Goodbye, {self.name}!";
    }
}

def standalone_func() -> None {
    """Docstring inside standalone function"""
    print("test");
}
