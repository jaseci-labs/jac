import collections.abc
from typing import TypeAlias

_ClassInfo: TypeAlias = type | tuple[object, ...]
Sized = collections.abc.Sized


def isinstance(obj: object, class_or_tuple: _ClassInfo, /) -> bool: ...
def len(obj: Sized, astt: object, /, z: int, j: str, a: int = 90) -> int: ...
