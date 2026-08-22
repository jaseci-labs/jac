"""A base-class expression is resolved at compile time, so it is not a use.

The only mention of `abc` here is the base of `Marked`. A base is never read
at run time by a native unit -- `LayoutPass` resolves it by name while
building the hierarchy -- so the module import gate must not read it as a
run-time use of the Python module.
"""

import abc;


obj Marked(abc.ABC) {
    has n: int = 3;
}


def run -> int {
    return Marked(n=7).n;
}
