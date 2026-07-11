"""Test fixture: shorter callable assignable to longer (TS-style param drop).

Mirrors TypeScript's rule that a function with fewer parameters is assignable
to a callable type expecting more, since the extras can be dropped at the call
site. This is the canonical pattern for React/JSX event handlers — a handler
written `def click() { ... }` should satisfy `Callable[[MouseEvent], None]`.
"""
import from typing { Callable }


class MouseEvent {
    button: int = 0;
}


def no_args() -> None {}
def one_int(x: int) -> None {}
def two_ints(x: int, y: int) -> None {}


def takes_mouse_handler(cb: Callable[[MouseEvent], None]) -> None {
    cb(MouseEvent());
}


class Widget {
    label: str = "";

    def click {}

    def click_one(x: int) {}
}


with entry {
    # --- Valid: shorter source assignable to longer destination (extras dropped) ---

    # Zero-arg function -> one-arg Callable
    f1: Callable[[MouseEvent], None] = no_args;  # Ok

    # Zero-arg function -> two-arg Callable
    f2: Callable[[int, int], None] = no_args;  # Ok

    # One-arg function -> two-arg Callable (drops trailing param)
    f3: Callable[[int, int], None] = one_int;  # Ok

    # Zero-arg lambda -> Callable expecting an event
    f4: Callable[[MouseEvent], None] = lambda { };  # Ok

    # Pass shorter callable through a higher-order call site
    takes_mouse_handler(no_args);  # Ok

    # Bound zero-arg method -> one-arg Callable. Exercises both the param-count
    # relaxation and the implicit-None return type recorded by methods.
    w = Widget();
    f5: Callable[[MouseEvent], None] = w.click;  # Ok

    # Bound one-arg method -> two-arg Callable.
    f6: Callable[[int, int], None] = w.click_one;  # Ok

    # --- Invalid: longer source NOT assignable to shorter destination ---

    # Two-arg function -> zero-arg Callable (extra src param without default)
    bad: Callable[[], None] = two_ints;  # Error: extra src params have no defaults
}
