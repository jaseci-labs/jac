"""Native from-import bindings delegate to the Python standard library."""

import from keyword { iskeyword }


def run -> int {
    return 1 if iskeyword("class") else 0;
}
