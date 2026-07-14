import from typing { overload }

@overload
def make(url: str, *, strict: bool) -> int { }

@overload
def make(url: str) -> int { }
