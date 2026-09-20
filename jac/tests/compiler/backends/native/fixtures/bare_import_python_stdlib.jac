"""Bare Python stdlib imports initialize before native function entry."""

import keyword;


def run -> int {
    return 1 if keyword.iskeyword("class") else 0;
}
