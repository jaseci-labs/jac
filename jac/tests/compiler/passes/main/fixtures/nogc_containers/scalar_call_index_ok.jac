"""Must stay clean: indexing a container with a scalar-returning call. The call
result is owned but scalar (an `int` index), so it is not a heap element and
must not trip the container fence."""
def pick -> int {
    return 1;
}

def run -> int {
    xs = [10, 20, 30];
    return xs[pick()];
}

with entry {
    print(run());
}
