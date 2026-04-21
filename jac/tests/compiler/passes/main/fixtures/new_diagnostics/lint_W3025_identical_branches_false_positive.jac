"""Fixture for W3025: mix of branches that *look* alike but differ inside
subscript-target assignments and call-argument kwargs (must NOT warn), plus
one pair that genuinely matches (must warn exactly once)."""

with entry {
    flag = True;
    model_fields: dict = {};
    default_val = 42;
    description = "hi";

    # Subscript-target assignment, tuple value: old key was just "Assignment"
    # for both branches. The tuple contents clearly differ.
    if flag {
        model_fields["x"] = (int, "a", description);
    } else {
        model_fields["x"] = (int, default_val, description);
    }

    # Assignment to same Name, call value with different **kwargs shapes.
    result = 0;
    extra = {"a": 1};
    if flag {
        result = sum({1: 10, **extra}.values());
    } else {
        result = sum(extra.values());
    }

    # Genuine match: subscript-target assignment with identical tuple value
    # in both branches. Shallow key missed this too; canonical unparse catches it.
    if flag {
        model_fields["y"] = (int, default_val, description);
    } else {
        model_fields["y"] = (int, default_val, description);
    }
}
