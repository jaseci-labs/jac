"""A chained comparison assigned at the end of a block continues past the block."""
import from builtins { compile as pycompile, exec as pyexec }

glob SOURCE: str = '''
def after_if(value, low, high):
    if low < high:
        inside = low <= value < high
    return ("in" if inside else "out", value)

def after_else(value, low, high):
    if low < high:
        inside = low <= value < high
    else:
        inside = not (high <= value < low)
    return ("in" if inside else "out", value)

def after_loop(values, low, high):
    count = 0
    for value in values:
        inside = low <= value < high
    while count < 2:
        count += 1
        last = low <= count < high
    return (inside, last, count)

def after_with(manager, value, low, high):
    with manager:
        inside = low <= value < high
    return (inside, value)

def at_function_end(box, value, low, high):
    box["inside"] = low <= value < high
''';

class Manager {
    def __enter__(self: Manager) -> Manager {
        return self;
    }

    def __exit__(self: Manager, *details: object) -> bool {
        return False;
    }
}

test "a chained comparison assigned last in a block does not end the function" {
    namespace: dict[str, any] = {};
    pyexec(pycompile(SOURCE, "block_tail_compare.py", "exec"), namespace);
    assert namespace["after_if"](15, 10, 20) == ("in", 15);
    assert namespace["after_if"](25, 10, 20) == ("out", 25);
    assert namespace["after_else"](15, 10, 20) == ("in", 15);
    assert namespace["after_else"](15, 20, 10) == ("out", 15);
    assert namespace["after_else"](5, 20, 10) == ("in", 5);
    assert namespace["after_loop"]([1, 30, 12], 10, 20) == (True, False, 2);
    assert namespace["after_with"](Manager(), 15, 10, 20) == (True, 15);
    assert namespace["after_with"](Manager(), 5, 10, 20) == (False, 5);
    box: dict[str, bool] = {};
    assert namespace["at_function_end"](box, 15, 10, 20) is None;
    assert box == {"inside": True};
}
