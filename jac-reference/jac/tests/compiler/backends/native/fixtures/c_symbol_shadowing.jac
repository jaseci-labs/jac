"""User definitions named after C symbols the native program links against.

`import math` binds libm's `floor`, `sqrt` and `pow` through the bundled
`_math_native` module, the backend declares `strlen` and `puts` for itself,
and a native binary defines `main`. Every definition below reuses one of
those names, so each must be emitted under a Jac-owned symbol instead of
colliding with the C one or taking over its callers.
"""
import math;

glob pow: int = 3;

def floor -> int {
    return 7;
}

def sqrt(x: float) -> float {
    return x + 100.0;
}

def strlen(s: str) -> int {
    return 99;
}

def puts(s: str) -> int {
    return 5;
}

def main -> int {
    return 11;
}

def user_floor_probe -> int {
    return floor();
}

def math_floor_probe -> int {
    return math.floor(2.5);
}

def user_sqrt_probe -> float {
    return sqrt(4.0);
}

def math_sqrt_probe -> float {
    return math.sqrt(16.0);
}

def glob_pow_probe -> int {
    return pow;
}

def math_pow_probe -> float {
    return math.pow(2.0, 3.0);
}

def strlen_probe -> int {
    word = "hello" + " world";
    return len(word) * 1000 + strlen(word);
}

def entry_names_probe -> int {
    return main() * 100 + puts("x");
}

with entry {
    print(floor(), math.floor(2.5), sqrt(4.0), math.sqrt(16.0));
    print(pow, math.pow(2.0, 3.0), strlen("abc"), len("abc"));
    print(main(), puts("hello"));
}
