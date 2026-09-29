"""A `:pub` definition named after a libm function beside `import math`."""
import math;

def:pub floor -> int {
    return 7;
}

def:pub pub_floor_probe -> int {
    return floor();
}

def:pub math_floor_probe -> int {
    return math.floor(2.5);
}
