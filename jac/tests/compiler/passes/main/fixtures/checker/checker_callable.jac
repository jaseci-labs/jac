"""Test fixture for Callable type checking."""
import from typing { Callable }

# Basic functions for Callable tests
def int_to_str(x: int) -> str { return str(x); }
def str_to_str(x: str) -> str { return x; }
def add_two(a: int, b: int) -> int { return a + b; }
def wrong_order(a: str, b: int) -> int { return b; }

# Extra params with/without defaults
def with_default(a: int, b: int, c: int = 10) -> int { return a + b + c; }
def without_default(a: int, b: int, c: int) -> int { return a + b + c; }

# Contravariance hierarchy
class Animal {}
class Dog(Animal) {}

def handle_animal(a: Animal) -> str { return "animal"; }
def handle_dog(d: Dog) -> str { return "dog"; }

# Class for method/classmethod tests
class Calculator {
    def double(x: int) -> int { return x * 2; }
    @classmethod
    def class_double(cls: type, x: int) -> int { return x * 2; }
}

# Higher-order functions
def takes_callback(cb: Callable[[int], str]) -> str { return cb(42); }
def apply_int_op(op: Callable[[int], int], x: int) -> int { return op(x); }

with entry {
    # --- Valid cases ---

    # Basic Callable assignment
    f1: Callable[[int], str] = int_to_str;  # Ok

    # Gradual callable (accepts any function with matching return)
    f2: Callable[..., str] = int_to_str;  # Ok
    f3: Callable[..., int] = add_two;     # Ok (multi-param)

    # Multi-parameter Callable
    m1: Callable[[int, int], int] = add_two;  # Ok

    # Higher-order function with Callable param
    r1: str = takes_callback(int_to_str);  # Ok

    # Method as Callable (self filtered)
    calc = Calculator();
    c1: Callable[[int], int] = calc.double;  # Ok
    c2: int = apply_int_op(calc.double, 5);  # Ok

    # Classmethod as Callable (cls filtered)
    c3: Callable[[int], int] = Calculator.class_double;  # Ok

    # Extra params with defaults
    d1: Callable[[int, int], int] = with_default;  # Ok (c has default)

    # Contravariance: wider param type assignable to narrower expected
    v1: Callable[[Dog], str] = handle_animal;  # Ok (Animal accepts Dog)

    # --- Bare Callable (no type parameters) ---
    # Bare Callable is equivalent to Callable[..., Any] - accepts any function
    b1: Callable = int_to_str;       # Ok (any function assignable to bare Callable)
    b2: Callable = add_two;          # Ok (multi-param function)
    b3: Callable = handle_animal;    # Ok
    b4: Callable = calc.double;      # Ok (method)
    b5: Callable = Calculator.class_double;  # Ok (classmethod)

    # Higher-order function returning bare Callable
    def make_decorator(desc: str) -> Callable {
        def decorator(fn: Callable) -> Callable {
            def wrapper -> None {}
            return wrapper;
        }
        return decorator;
    }
    dec: Callable = make_decorator("test");  # Ok

    # --- Type errors ---

    # Wrong parameter type
    e1: Callable[[int], str] = str_to_str;  # Error: expects int, got str

    # Wrong return type
    e2: int = takes_callback(int_to_str);  # Error: returns str, not int

    # Wrong parameter order
    e3: Callable[[int, int], int] = wrong_order;  # Error: [str,int] vs [int,int]

    # Wrong return type for multi-param
    e4: Callable[[int, int], str] = add_two;  # Error: returns int, not str

    # Method wrong return type
    e5: Callable[[int], str] = calc.double;  # Error: returns int, not str

    # Classmethod wrong param type
    e6: Callable[[str], int] = Calculator.class_double;  # Error: expects int

    # Contravariance violation: narrower param type not assignable
    e7: Callable[[Animal], str] = handle_dog;  # Error: Dog doesn't accept Cat

    # Extra params without defaults
    e8: Callable[[int, int], int] = without_default;  # Error: c has no default
}
