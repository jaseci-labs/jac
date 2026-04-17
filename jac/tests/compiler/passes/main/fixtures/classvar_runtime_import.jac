"""Regression fixture: ClassVar must be importable at runtime.

dataclass reads cls.__module__ at __init_subclass__ time and looks up
'ClassVar' by name to recognize class-level variables (which must not be
treated as instance fields). If the compiler demotes `from typing import
ClassVar` into `if typing.TYPE_CHECKING:`, dataclass can't find it,
treats `paths` as a regular field with a mutable default, and crashes
with "mutable default <class 'dict'> for field paths".
"""
import from typing { ClassVar }

obj Registry {
    with entry {
        paths: ClassVar[dict[str, int]] = {};
    }

    static def register(name: str, weight: int) -> None;
}

impl Registry.register(name: str, weight: int) -> None {
    Registry.paths[name] = weight;
}
