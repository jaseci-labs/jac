"""Tests that ParamSpec and TypeVarTuple produce no false E1071 errors.

Callable[P, T] (where P is a ParamSpec) is valid Python 3.10+ syntax.
Callable[([Callable[(P, T)]], Callable[(P, T)])] is the Jac form of the
decorator pattern Callable[[Callable[P, T]], Callable[P, T]].
"""

import from typing { Callable, ParamSpec, TypeVar, TypeVarTuple }

glob P = ParamSpec('P'),
     T = TypeVar('T'),
     Ts = TypeVarTuple('Ts');

# Basic Callable[P, T] — must not trigger E1071
def wrap(func: Callable[(P, T)]) -> Callable[(P, T)] {
    return func;
}

# Decorator returning Callable[[Callable[P, T]], Callable[P, T]] — the
# pattern used in runtime.jac's impl_patch_filename.
def make_decorator(tag: str) -> Callable[([Callable[(P, T)]], Callable[(P, T)])] {
    def decorator(func: Callable[(P, T)]) -> Callable[(P, T)] {
        return func;
    }
    return decorator;
}
