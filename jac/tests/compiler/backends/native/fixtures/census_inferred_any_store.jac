"""An any value stored into a container whose element type was inferred
from a literal is refused instead of stored into a slot of the wrong type."""
def foo(param: int, **kwargs: int) -> tuple[any, ...] {
    return (param + kwargs['bar'], 'from_foo');
}

glob mydict = {'new_val': 1, 'where': 0};

with entry {
    (mydict['new_val'], mydict['where']) = foo(1, bar=2);
    print(mydict);
}
