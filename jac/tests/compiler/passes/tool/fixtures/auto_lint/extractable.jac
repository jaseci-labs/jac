"""Test cases where all assignments should be extracted from with entry blocks.

This fixture combines multiple extraction scenarios:
- Simple literal assignments
- Various pure expression types (collections, binary/unary ops)
- Extraction with imports present (globs should be inserted after imports)
"""

import from os { path }

with entry {
    # Simple literals
    x = 5;
    y = "hello";
    z = [1, 2, 3];

    # Various pure expression types
    int_val = 42;
    float_val = 3.14;
    str_val = "world";
    bool_val = True;
    null_val = None;

    # Collections
    list_val = [1, 2, 3];
    dict_val = {"a": 1, "b": 2};
    tuple_val = (1, 2, 3);
    set_val = {1,2,3};

    # Binary operations on literals
    sum_val = 1 + 2;
    product = 3 * 4;

    # Unary operations
    neg_val = -5;
    not_val = not False;
}

def main() {
    print(x + int_val);
}
