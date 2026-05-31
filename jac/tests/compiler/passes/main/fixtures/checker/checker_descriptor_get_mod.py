# Fixture modeling a generic descriptor; loose annotations are intentional.
# ruff: noqa: ANN401, N801
from collections.abc import Callable
from typing import Any, Generic, TypeVar, overload

_T_co = TypeVar("_T_co", covariant=True)


class memoized_property(Generic[_T_co]):
    fget: Callable[..., _T_co]

    def __init__(self, fget: Callable[..., _T_co]) -> None: ...
    @overload
    def __get__(self, obj: None, cls: Any) -> "memoized_property[_T_co]": ...
    @overload
    def __get__(self, obj: object, cls: Any) -> _T_co: ...
    def __get__(self, obj, cls): ...


class Result:
    rowcount: memoized_property[int]
