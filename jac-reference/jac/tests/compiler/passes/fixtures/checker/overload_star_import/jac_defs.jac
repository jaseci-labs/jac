import from typing { overload }

@overload
def pick(x: int) -> int {}

@overload
def pick(x: object) -> str {}
