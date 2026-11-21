"""Jac compiler tools."""

import sys

# Recursive compiler algorithms need this budget when hosted by Python.
# Keep interpreter setup out of the native-capable compiler session model.
if sys.getrecursionlimit() < 12000:
    sys.setrecursionlimit(12000)
