"""Native fixture exercising nested function definitions.

Covers the non-capturing cases: a nested helper used several times, a
self-recursive nested function, and a nested function that reads a
module global. (Capture of enclosing-function locals is intentionally
not supported yet and is rejected at compile time.)
"""

glob BASE: int = 100;

def use_helper(n: int) -> int {
    def double(x: int) -> int {
        return x * 2;
    }
    return double(n) + double(n + 1);
}

def nested_recursion(n: int) -> int {
    def fact(x: int) -> int {
        if x <= 1 {
            return 1;
        }
        return x * fact(x - 1);
    }
    return fact(n);
}

def uses_global(n: int) -> int {
    def add_base(x: int) -> int {
        return x + BASE;
    }
    return add_base(n);
}
