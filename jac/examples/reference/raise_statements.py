from __future__ import annotations


def raise_exception() -> None:
    raise ValueError("error message")


def raise_with_expression() -> None:
    x = 10
    raise RuntimeError(f"value is {x}")


def raise_from_exception() -> None:
    try:
        x = 5 / 0
    except ZeroDivisionError as e:
        raise RuntimeError("division failed") from e


def bare_raise() -> None:
    try:
        raise ValueError("original")
    except ValueError:
        print("caught, re-raising")
        raise


def conditional_raise(value: int) -> None:
    if value < 0:
        raise ValueError("must be non-negative")
    if value > 100:
        raise ValueError("must be <= 100")


try:
    raise_exception()
except ValueError as e:
    print(f"caught: {e}")
try:
    raise_with_expression()
except RuntimeError as e:
    print(f"caught: {e}")
try:
    raise_from_exception()
except RuntimeError as e:
    print(f"caught: {e}")
try:
    bare_raise()
except ValueError as e:
    print(f"re-raised: {e}")
try:
    conditional_raise(-5)
except ValueError as e:
    print(f"caught: {e}")
try:
    conditional_raise(150)
except ValueError as e:
    print(f"caught: {e}")
try:
    conditional_raise(50)
    print("no error")
except ValueError:
    print("unexpected")
