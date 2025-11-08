"""A Docstring can be added the head of any module.

Any element in the module can also have a docstring.
If there is only one docstring before the first element,
it is assumed to be a module docstring.
"""

"""A docstring for add function"""
def add(a: int, b: int) -> int {
    return a + b;
}
# No docstring for subtract function

def subtract(a: int, b: int) -> int {
    return a - b;
}

with entry:__main__ {
    print(add(1, subtract(3, 1)));
}
