from typing import TypeAlias, TypeAlias as Alias, overload

Text: TypeAlias = str
Binary: Alias = bytes

@overload
def normalize(value: Binary) -> bytes: ...
@overload
def normalize(value: Text) -> str: ...
