# Test builtin constructors: set(), list(), dict()
# These should all work without errors

with entry {
    # Test empty constructors (should work)
    x = set();
    y = list();
    z = dict();

    # Test constructors with arguments (should work)
    x2 = set([1, 2, 3]);
    y2 = list([1, 2, 3]);
    z2 = dict({"a": 1});

    # Test tuple constructor (if it exists)
    t = tuple([1, 2, 3]);
}
