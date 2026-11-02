"""Imports C-named definitions from a module compiled on its own.

The defining module never imports `math`, so its symbols are fixed without
seeing libm; this module imports both and must bind each name to the right
side of the link.
"""
import math;
import from c_symbol_shadowing_lib { floor, ceil, exp }

def imported_floor_probe -> int {
    return floor();
}

def math_floor_probe -> int {
    return math.floor(3.7);
}

def imported_ceil_probe -> float {
    return ceil(1.5);
}

def math_ceil_probe -> int {
    return math.ceil(1.2);
}

def imported_glob_probe -> int {
    return exp;
}

def math_exp_probe -> float {
    return math.exp(0.0);
}
