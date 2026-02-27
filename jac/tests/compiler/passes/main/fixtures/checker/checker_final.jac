import from typing { Final }

with entry {
    x: Final[int] = 10; # <-- Ok
    y: int = x; # <-- Ok
    z: str = x; # <-- Error: incompatible types
}
