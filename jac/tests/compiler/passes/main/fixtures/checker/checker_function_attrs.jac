"""Test function type attribute access."""

import types;
import from typing { Callable }

def takes_callable(func: Callable[[int], int]) -> None {
    _code = func.__code__;
    _argcount: int = func.__code__.co_argcount;
}

def test_func_attrs(func: Callable[[int], int]) -> None {
    _name: str = func.__name__;
    _module: str = func.__module__;
}
