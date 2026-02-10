# Trailing comma in dict, set, and spread dict literals
with entry {
    d = {"a": 1, "b": 2,};
    s = {1, 2, 3,};
    base = {"x": 10};
    merged = {**base, "y": 20,};
}
