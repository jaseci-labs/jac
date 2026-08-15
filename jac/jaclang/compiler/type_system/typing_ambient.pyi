"""Curated typing constructs available without explicit import.

The TypeEvaluator merges the names listed in __all__ into
builtins_module.names_in_scope so user code can write
`def foo(cb: Callable[[], None])` without `import from typing { Callable }`.
PyastGenPass reads the same __all__ to auto-emit
`from typing import <names>` in the generated Python whenever an ambient
name is referenced — preserving runtime resolvability for libraries that
introspect annotations (typing.get_type_hints, pydantic, FastAPI, ...).

Editing this file is the *only* place to grow or shrink the ambient set.

A name listed here is installed by resolving it through the typing module's
symbol table with `lookup_symtab`, which descends into the live branch of a
`if sys.version_info >= (...)` guard the way typeshed writes one. Without
that, every name typeshed declares under a version guard was dropped in
silence: `TypeGuard` sits under `>= (3, 10)` and `TypeIs` under `>= (3, 13)`,
so neither was ever reachable no matter what this file listed.

The interpreter is jac's own -- the `jac` binary bundles CPython 3.14 and
there is no pip-installed jaclang -- so the guard walk resolves against 3.14.
The one standing constraint on a new entry is that PyastGenPass emits a real
`from typing import <name>`: the name has to exist in that bundled runtime,
not merely in typeshed.

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
    TypeGuard,
    TypeIs,
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
    "TypeGuard",
    "TypeIs",
    "TypeVar",
]
