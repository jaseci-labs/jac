"""Test property type checking."""

obj Foo {
    @property
    def bar -> int {
        return 1;
    }

    @property
    def name -> str {
        return "foo";
    }

    def regular_method -> int {
        return 42;
    }
}

obj Bar {
    @property
    def value -> int {
        return 100;
    }
}

with entry {
    # Property access should return the return type, not FunctionType
    foo = Foo();
    bar: int = foo.bar;  # <-- OK (should work)
    wrong: str = foo.bar;  # <-- Error (int assigned to str)

    name: str = foo.name;  # <-- OK (should work)
    wrong_name: int = foo.name;  # <-- Error (str assigned to int)

    # Regular methods should still return FunctionType (not callable without ())
    method: int = foo.regular_method;  # <-- Error (FunctionType assigned to int)

    # Test with another class
    bar_obj = Bar();
    val: int = bar_obj.value;  # <-- OK (should work)
    wrong_val: str = bar_obj.value;  # <-- Error (int assigned to str)
}
