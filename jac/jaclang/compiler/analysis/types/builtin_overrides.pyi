"""Jac-specific refinements over typeshed builtins.

Names listed in __all__ are merged into the global builtins scope,
unconditionally replacing the typeshed declaration. Use this for builtins
whose typeshed stubs rely on generic protocols the evaluator cannot yet
infer to concrete return types (e.g. divmod's SupportsDivMod overloads
leave _T_co unbound, so subscripting divmod(int, int) fails), and for the
implicit module globals whose only typeshed declaration describes a
different thing: ModuleType.__file__ is str | None because a module object
may have no file, but the __file__ a module sees in its own scope is always
the path it was loaded from.
"""

from _typeshed import SupportsDivMod, SupportsRDivMod
from typing import TypeVar, overload

__all__ = ["divmod", "__file__"]

__file__: str

_T_contra = TypeVar("_T_contra", contravariant=True)
_T_co = TypeVar("_T_co", covariant=True)

@overload
def divmod(x: int, y: int, /) -> tuple[int, int]: ...
@overload
def divmod(x: float, y: float, /) -> tuple[float, float]: ...
@overload
def divmod(x: SupportsDivMod[_T_contra, _T_co], y: _T_contra, /) -> _T_co: ...
@overload
def divmod(x: _T_contra, y: SupportsRDivMod[_T_contra, _T_co], /) -> _T_co: ...
