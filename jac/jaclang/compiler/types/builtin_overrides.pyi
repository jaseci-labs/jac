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

from _typeshed import SupportsDivMod, SupportsRDivMod, SupportsRichComparison, SupportsRichComparisonT
from collections.abc import Callable, Iterable
from typing import TypeVar, overload

__all__ = ["divmod", "max", "min", "__file__"]

__file__: str

_T_contra = TypeVar("_T_contra", contravariant=True)
_T_co = TypeVar("_T_co", covariant=True)
_T = TypeVar("_T")
_T1 = TypeVar("_T1")
_T2 = TypeVar("_T2")

@overload
def divmod(x: int, y: int, /) -> tuple[int, int]: ...
@overload
def divmod(x: float, y: float, /) -> tuple[float, float]: ...
@overload
def divmod(x: SupportsDivMod[_T_contra, _T_co], y: _T_contra, /) -> _T_co: ...
@overload
def divmod(x: _T_contra, y: SupportsRDivMod[_T_contra, _T_co], /) -> _T_co: ...

# max and min of numbers: ints give an int, and a mix of ints and floats a float,
# as the values compare. typeshed's one type variable would bind to the first
# argument and refuse the second. The other forms are typeshed's own.
@overload
def max(arg1: int, arg2: int, /, *_args: int, key: None = None) -> int: ...
@overload
def max(arg1: float, arg2: float, /, *_args: float, key: None = None) -> float: ...
@overload
def max(
    arg1: SupportsRichComparisonT, arg2: SupportsRichComparisonT, /, *_args: SupportsRichComparisonT, key: None = None
) -> SupportsRichComparisonT: ...
@overload
def max(arg1: _T, arg2: _T, /, *_args: _T, key: Callable[[_T], SupportsRichComparison]) -> _T: ...
@overload
def max(iterable: Iterable[SupportsRichComparisonT], /, *, key: None = None) -> SupportsRichComparisonT: ...
@overload
def max(iterable: Iterable[_T], /, *, key: Callable[[_T], SupportsRichComparison]) -> _T: ...
@overload
def max(iterable: Iterable[SupportsRichComparisonT], /, *, key: None = None, default: _T) -> SupportsRichComparisonT | _T: ...
@overload
def max(iterable: Iterable[_T1], /, *, key: Callable[[_T1], SupportsRichComparison], default: _T2) -> _T1 | _T2: ...
@overload
def min(arg1: int, arg2: int, /, *_args: int, key: None = None) -> int: ...
@overload
def min(arg1: float, arg2: float, /, *_args: float, key: None = None) -> float: ...
@overload
def min(
    arg1: SupportsRichComparisonT, arg2: SupportsRichComparisonT, /, *_args: SupportsRichComparisonT, key: None = None
) -> SupportsRichComparisonT: ...
@overload
def min(arg1: _T, arg2: _T, /, *_args: _T, key: Callable[[_T], SupportsRichComparison]) -> _T: ...
@overload
def min(iterable: Iterable[SupportsRichComparisonT], /, *, key: None = None) -> SupportsRichComparisonT: ...
@overload
def min(iterable: Iterable[_T], /, *, key: Callable[[_T], SupportsRichComparison]) -> _T: ...
@overload
def min(iterable: Iterable[SupportsRichComparisonT], /, *, key: None = None, default: _T) -> SupportsRichComparisonT | _T: ...
@overload
def min(iterable: Iterable[_T1], /, *, key: Callable[[_T1], SupportsRichComparison], default: _T2) -> _T1 | _T2: ...
