"""Bug #33: For loop does not check iterability of the target expression.

The type checker does not verify that the expression in `for x in expr`
is actually iterable. A non-iterable value can be used without error.

Expected: `for x in 42` should error because int is not iterable.
"""

with entry {
    # Iterating over a non-iterable should be an error
    for x in 42 {  # <-- Should be Error (int is not iterable)
        print(x);
    }

    for y in True {  # <-- Should be Error (bool is not iterable)
        print(y);
    }

    # Valid iteration should be fine
    for z in [1, 2, 3] {
        print(z);
    }
}
