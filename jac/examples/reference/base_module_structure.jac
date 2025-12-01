"""Base module structure: Module and element docstrings, entry points.

This is the module-level docstring.
It describes the purpose of the entire module.
"""

# 1. Import statement
import math;

# 2. Global variable (using let as requested)
let global_value: int = 42;

# 3. Archetype (object)
obj MyObject {
    has value: int = 0;
}

# 4. Implementation
impl MyObject{
    def get_value -> int {
        return self.value;
    }
}

# 5. Semstring
sem MyObject. value= "A value stored in MyObject";

# 6. Ability (function)
def add(a: int, b: int) -> int {
    return a + b;
}

# 7. Free code (default entry point)
with entry {
    print("Default entry:", add(5, 8));
}

# 8. Free code (named entry point)
with entry:__main__ {
    print("Named entry:", add(1, 2));
}

# 9. Inline Python
::py::
def python_multiply(x, y):
    return x * y
::py::


# 10. Test
test basic_test {
    result = add(2, 3);
    assert result == 5;
}
