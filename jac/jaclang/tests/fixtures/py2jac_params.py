from typing import TypeAlias
import collections.abc

_ClassInfo: TypeAlias = type | tuple[object, ...]
Sized = collections.abc.Sized


def isinstance(obj: object, class_or_tuple: _ClassInfo, /) -> bool: ...
def len(obj: Sized, astt, /, z: int, j: str, a=90) -> int: ...
