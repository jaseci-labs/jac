"""A `from` import of an na_stdlib-shimmed module is a native dependency.

`keyword` ships as Jac source under `runtime/na_stdlib`, so the name the
import binds is supplied by a native unit. Classifying `from`-import items
must not read a shimmed module as Python.
"""

import from keyword { iskeyword }


def run -> int {
    return 1 if iskeyword("class") else 0;
}
