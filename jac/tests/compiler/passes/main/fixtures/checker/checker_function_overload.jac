import from typing { overload }

@overload
def cast(value: int) -> str {}

@overload
def cast(value: list[int]) -> str {}

with entry {
    x: str = cast(10);  # <-- Ok
    y: str = cast([1, 2, 3]);  # <-- Ok
    z: str = cast("hello");  # <-- Error
}
