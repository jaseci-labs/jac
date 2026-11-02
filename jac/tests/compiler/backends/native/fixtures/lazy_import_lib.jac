"""A module that provides its names lazily through a module `__getattr__`."""

def __getattr__(name: str) -> int {
    return len(name);
}
