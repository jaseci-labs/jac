"""Test with entry inside a class body.

The with entry block inside a class is used for instance initialization,
NOT module-level globals. These should NOT be extracted to glob since
glob is a module-level construct that doesn't work inside classes.
"""

class MyClass {
    """A class with entry block for initialization."""
    has instance_var: int = 0;

    has another_var: str = "";
    has list_var: list = [];

    with entry {
        instance_var = 42;
        another_var = "hello";
        list_var = [1, 2, 3];
    }

    def get_value(self: MyClass) -> int {
        return self.instance_var;
    }
}

# Module level with entry - this SHOULD be extracted
with entry {
    module_var = 100;
    cls_obj = MyClass();
}
