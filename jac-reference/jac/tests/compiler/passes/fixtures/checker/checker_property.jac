"""Test property and cached_property type checking."""

import from functools { cached_property }

obj Foo {
    @property
    def bar -> int {
        return 1;
    }

    @property
    def name -> str {
        return "foo";
    }

    @cached_property
    def cached_val -> str {
        return "cached";
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

    @cached_property
    def cached_num -> int {
        return 999;
    }
}

with entry {
    # Property access should return the return type, not FunctionType
    foo = Foo();
    bar: int = foo.bar;  # <-- OK (should work)
    wrong: str = foo.bar;  # <-- Error (int assigned to str)

    name: str = foo.name;  # <-- OK (should work)
    wrong_name: int = foo.name;  # <-- Error (str assigned to int)

    # cached_property should also return the return type
    cached: str = foo.cached_val;  # <-- OK (should work)
    wrong_cached: int = foo.cached_val;  # <-- Error (str assigned to int)

    # Regular methods should still return FunctionType (not callable without ())
    method: int = foo.regular_method;  # <-- Error (FunctionType assigned to int)

    # Test with another class
    bar_obj = Bar();
    val: int = bar_obj.value;  # <-- OK (should work)
    wrong_val: str = bar_obj.value;  # <-- Error (int assigned to str)

    # cached_property in Bar
    cached_num: int = bar_obj.cached_num;  # <-- OK (should work)
    wrong_cached_num: str = bar_obj.cached_num;  # <-- Error (int assigned to str)
}
