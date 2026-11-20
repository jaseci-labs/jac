"""A cpython space, as jac's Python backend made it: its code
objects, which the runtime loads and runs, its main module as `__main__`."""

import os
import sys

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)

import _jac

_jac.install(here, True)
