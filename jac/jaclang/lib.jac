"""Jac Library - User-friendly interface for library mode."""

import jaclang.jac0core.jaclib as _jaclib;
include jaclang.jac0core.jaclib;

glob __all__ = _jaclib.__all__;

def __getattr__(name: str) -> object {
    return _jaclib.__getattr__(name);
}

def __dir__ -> list[str] {
    return _jaclib.__dir__();
}
