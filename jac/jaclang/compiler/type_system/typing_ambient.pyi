"""Curated typing constructs available without explicit import.

The TypeEvaluator merges the names listed in __all__ into
builtins_module.names_in_scope so user code can write
`def foo(cb: Callable[[], None])` without `import from typing { Callable }`.
PyastGenPass reads the same __all__ to auto-emit
`from typing import <names>` in the generated Python whenever an ambient
name is referenced — preserving runtime resolvability for libraries that
introspect annotations (typing.get_type_hints, pydantic, FastAPI, ...).

Editing this file is the *only* place to grow or shrink the ambient set.

Skipped on purpose:
  * Any            — Jac uses the lowercase `any` BuiltinType keyword.
  * Optional/Union — write `X | None` / `X | Y` (PEP 604).
  * Dict/List/Set/FrozenSet/Tuple/Type/DefaultDict/OrderedDict/Counter/Deque
                   — use the lowercase built-ins (PEP 585): dict, list, set,
                    frozenset, tuple, type, ...
  * Final         — currently provided as a local stub by jac_builtins.pyi
                    (the `existing not imported` guard preserves it). When
                    that stub is removed, add Final here to gain real
                    typing.Final semantics.
  * cast / overload / runtime_checkable / TYPE_CHECKING / get_type_hints
    / get_args / get_origin / no_type_check
                   — these are *runtime* values, not annotation-only forms.
                    Importing them explicitly keeps runtime intent obvious.
"""

from collections.abc import (
    AsyncIterable,
    AsyncIterator,
    Awaitable,
    Callable,
    Coroutine,
    Iterable,
    Iterator,
    Mapping,
    MutableMapping,
    MutableSequence,
    Sequence,
)
from typing import (
    Annotated,
    ClassVar,
    Generic,
    Literal,
    Protocol,
    TypeVar,
)

__all__ = [
    "Annotated",
    "AsyncIterable",
    "AsyncIterator",
    "Awaitable",
    "Callable",
    "ClassVar",
    "Coroutine",
    "Generic",
    "Iterable",
    "Iterator",
    "Literal",
    "Mapping",
    "MutableMapping",
    "MutableSequence",
    "Protocol",
    "Sequence",
    "TypeVar",
]
