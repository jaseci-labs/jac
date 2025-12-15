from jaclang.runtimelib.default import hookimpl
from jaclang.runtimelib.constructs import (  # type: ignore[attr-defined]
    Archetype,
    ObjectSpatialFunction,
    WalkerArchetype,
)

from dataclasses import dataclass
from functools import wraps
from typing import Type
from collections.abc import Callable


class JacRuntime:
    @staticmethod
    @hookimpl
    def make_walker(
        on_entry: list[ObjectSpatialFunction], on_exit: list[ObjectSpatialFunction]
    ) -> Callable[[type], type]:
        """Create a walker archetype."""

        def decorator(cls: type[Archetype]) -> type[Archetype]:
            """Decorate class."""
            cls = dataclass(eq=False)(cls)
            arch_cls = WalkerArchetype
            if not issubclass(cls, arch_cls):
                cls = type(cls.__name__, (cls, arch_cls), {})
            cls._jac_entry_funcs_ = on_entry
            cls._jac_exit_funcs_ = on_exit
            inner_init = cls.__init__

            @wraps(inner_init)
            def new_init(self: WalkerArchetype, *args: object, **kwargs: object) -> None:
                inner_init(self, *args, **kwargs)
                arch_cls.__init__(self)

            cls.__init__ = new_init  # type: ignore
            print("IM IN THE PLUGIN YO!")
            return cls

        print("IM IN THE PLUGIN YO!")
        return decorator
