# Jac ambient builtins — single source of truth for the type checker.
#
# Only names listed in __all__ become ambient (visible without import);
# anything else stays private to this file. The TypeEvaluator merges these
# into builtins_module.names_in_scope, so they sit in the scope chain above
# every user module.
#
# Only USER-FACING names belong in __all__. Internal codegen helpers (connect,
# visit, refs, build_edge, etc.) are injected by the codegen emitter and
# should NOT be declared here — they would conflict with the type checker's
# own handling of the syntax they desugar from (++>, -->, visit [], etc.).
#
# Codegen (JcirGenPass) independently controls which `import` lines
# appear in the generated Python — it reads jaclib.__all__ and
# builtin.__all__ for that purpose. This file is NOT used by codegen.

from collections.abc import Callable
from typing import Any, ClassVar, NoReturn, Protocol, TypeVar

_NewT = TypeVar("_NewT")

__all__ = [
    # Module dunders
    "__name__",
    "__file__",
    "__doc__",
    "__package__",
    "__spec__",
    # Typing special forms
    "Final",
    # Archetype types and helpers
    "Node",
    "Edge",
    "Walker",
    "Obj",
    "Root",
    "GenericEdge",
    "JsxElement",
    "JsxPage",
    "JsxLayout",
    "OPath",
    "DSFunc",
    "EdgeDir",
    "LLMModel",
    "Region",
    "region_of",
    # Fixed-width numeric types
    "i8",
    "u8",
    "i16",
    "u16",
    "i32",
    "u32",
    "i64",
    "u64",
    "f32",
    "f64",
    "wrapping_add",
    "wrapping_sub",
    "wrapping_mul",
    "wrapping_shl",
    "wrapping_neg",
    # User-facing builtin functions
    "jid",
    "jobj",
    "grant",
    "revoke",
    "allroots",
    "save",
    "commit",
    "on_commit",
    "store",
    "archetype_alias",
    "destroy",
    "new",
    "jref",
    "printgraph",
    "restspec",
    "schedule",
    "unsafe_html",
    "managed",
    "take",
    "swap",
    "JacListView",
    # Schema evolution rule builders
    "schema_was",
    "schema_alias",
    "schema_drop",
    "schema_upgrade",
    # Test builtins (usable inside any `test` block, no import)
    "testskip",
    "testfail",
    "testraises",
    "RaisesContext",
    # Ambient values and constants
    "llm",
    # Builtin enums
    "AccessLevel",
    "ScheduleTrigger",
    "APIProtocol",
]

# ── Module dunders ──────────────────────────────────────────────────
# Injected by Python's import system; declared here for the Jac checker.
__name__: str  # type: ignore[no-redef]
__file__: str | None  # type: ignore[no-redef]
__doc__: str | None  # type: ignore[no-redef]
__package__: str | None  # type: ignore[no-redef]
__spec__: object  # type: ignore[no-redef]

# ── Typing special forms ───────────────────────────────────────────
class Final: ...

# ── Core archetype types ──────────────────────────────────────────
# `__jac__` is the runtime anchor behind every archetype instance. Its
# static type is runtimelib's Anchor, which this ambient stub cannot
# name, so the property stays gradually typed.
class Node:
    @property
    def __jac__(self) -> Any: ...

class Edge:
    @property
    def __jac__(self) -> Any: ...

class Walker:
    reports: list[Any]
    @property
    def __jac__(self) -> Any: ...

class Obj:
    @property
    def __jac__(self) -> Any: ...

class Root(Node):
    # The deployment's shared root: the root every unauthenticated
    # request runs on. Normal permission checks still apply to its graph.
    @property
    def shared(self) -> Root: ...

class GenericEdge(Edge): ...

# Route marker types for the client file-based router. A `pages/` module whose
# public export returns `JsxPage` is a route; one returning `JsxLayout` is a
# layout. `JsxElement` is assignable to both, so a component body returning JSX
# satisfies a `-> JsxPage` / `-> JsxLayout` signature; the distinct annotation is
# what marks the export as a route/layout (the name of the export is free).
class JsxPage:
    tag: object
    props: dict[str, object]
    children: list[object]

class JsxLayout:
    tag: object
    props: dict[str, object]
    children: list[object]

class JsxElement(JsxPage, JsxLayout):
    tag: object
    props: dict[str, object]
    children: list[object]

class OPath: ...
class DSFunc: ...

# First-class region handle: an ownable, sendable, escape-checked allocation
# extent opened by `in <handle> { ... }`. On managed backends the handle is a
# no-op; native codegen gives it arena semantics.
class Region:
    @overload
    def partition(self) -> Region: ...
    @overload
    def partition(self, n: int) -> tuple[Region, ...]: ...

# The region a value was allocated in (the growth anchor of a traversal),
# or None for a managed value.
def region_of(__x: object) -> Region | None: ...

class EdgeDir:
    OUT: int
    IN: int
    ANY: int

class LLMModel(Protocol):
    call_params: dict[str, object]
    def __call__(self, **kwargs: object) -> LLMModel: ...

# ── Fixed-width numeric types ───────────────────────────────────────
# Real types with one semantic contract (see `jac guide jac-types`): widening
# along the value-preserving lattice is implicit and everything else is the
# checked cast `T(x)`, which raises OverflowError out of range. Arithmetic on
# a sized int traps on overflow; `T.wrap(x)` and the `wrapping_*` builtins
# are the modular (two's-complement) family. The checker types `T op T`,
# literal adoption and the casts itself; these stubs carry the type-level
# surface (`MIN`, `MAX`, `wrap`, the constructor) and the unary dunders.

class i8(int):  # noqa: N801
    MIN: ClassVar[i8]
    MAX: ClassVar[i8]
    def __new__(cls, x: int | float | bool = 0) -> i8: ...
    @classmethod
    def wrap(cls, x: int | float | bool) -> i8: ...
    def __neg__(self) -> i8: ...
    def __pos__(self) -> i8: ...
    def __abs__(self) -> i8: ...
    def __invert__(self) -> i8: ...

class u8(int):  # noqa: N801
    MIN: ClassVar[u8]
    MAX: ClassVar[u8]
    def __new__(cls, x: int | float | bool = 0) -> u8: ...
    @classmethod
    def wrap(cls, x: int | float | bool) -> u8: ...
    def __neg__(self) -> u8: ...
    def __pos__(self) -> u8: ...
    def __abs__(self) -> u8: ...
    def __invert__(self) -> u8: ...

class i16(int):  # noqa: N801
    MIN: ClassVar[i16]
    MAX: ClassVar[i16]
    def __new__(cls, x: int | float | bool = 0) -> i16: ...
    @classmethod
    def wrap(cls, x: int | float | bool) -> i16: ...
    def __neg__(self) -> i16: ...
    def __pos__(self) -> i16: ...
    def __abs__(self) -> i16: ...
    def __invert__(self) -> i16: ...

class u16(int):  # noqa: N801
    MIN: ClassVar[u16]
    MAX: ClassVar[u16]
    def __new__(cls, x: int | float | bool = 0) -> u16: ...
    @classmethod
    def wrap(cls, x: int | float | bool) -> u16: ...
    def __neg__(self) -> u16: ...
    def __pos__(self) -> u16: ...
    def __abs__(self) -> u16: ...
    def __invert__(self) -> u16: ...

class i32(int):  # noqa: N801
    MIN: ClassVar[i32]
    MAX: ClassVar[i32]
    def __new__(cls, x: int | float | bool = 0) -> i32: ...
    @classmethod
    def wrap(cls, x: int | float | bool) -> i32: ...
    def __neg__(self) -> i32: ...
    def __pos__(self) -> i32: ...
    def __abs__(self) -> i32: ...
    def __invert__(self) -> i32: ...

class u32(int):  # noqa: N801
    MIN: ClassVar[u32]
    MAX: ClassVar[u32]
    def __new__(cls, x: int | float | bool = 0) -> u32: ...
    @classmethod
    def wrap(cls, x: int | float | bool) -> u32: ...
    def __neg__(self) -> u32: ...
    def __pos__(self) -> u32: ...
    def __abs__(self) -> u32: ...
    def __invert__(self) -> u32: ...

class i64(int):  # noqa: N801
    MIN: ClassVar[i64]
    MAX: ClassVar[i64]
    def __new__(cls, x: int | float | bool = 0) -> i64: ...
    @classmethod
    def wrap(cls, x: int | float | bool) -> i64: ...
    def __neg__(self) -> i64: ...
    def __pos__(self) -> i64: ...
    def __abs__(self) -> i64: ...
    def __invert__(self) -> i64: ...

class u64(int):  # noqa: N801
    MIN: ClassVar[u64]
    MAX: ClassVar[u64]
    def __new__(cls, x: int | float | bool = 0) -> u64: ...
    @classmethod
    def wrap(cls, x: int | float | bool) -> u64: ...
    def __neg__(self) -> u64: ...
    def __pos__(self) -> u64: ...
    def __abs__(self) -> u64: ...
    def __invert__(self) -> u64: ...

class f32(float):  # noqa: N801
    def __new__(cls, x: int | float | bool = 0.0) -> f32: ...
    def __neg__(self) -> f32: ...
    def __pos__(self) -> f32: ...
    def __abs__(self) -> f32: ...

class f64(float):  # noqa: N801
    def __new__(cls, x: int | float | bool = 0.0) -> f64: ...
    def __neg__(self) -> f64: ...
    def __pos__(self) -> f64: ...
    def __abs__(self) -> f64: ...

# Modular arithmetic over two same-typed sized ints (an in-range literal
# adopts the other operand's type); the checker refines the `int` here to
# the operand type.
def wrapping_add(a: int, b: int) -> int: ...
def wrapping_sub(a: int, b: int) -> int: ...
def wrapping_mul(a: int, b: int) -> int: ...
def wrapping_shl(a: int, b: int) -> int: ...
def wrapping_neg(a: int) -> int: ...

# ── User-facing builtin functions (from jaclang.runtimelib.builtin) ─
# These are ambient names provided by jaclang.runtimelib.builtin.
# At runtime they are resolved lazily via __getattr__.
# Codegen emits `from jaclang.runtimelib.builtin import <name>`.

def jid(obj: object) -> str: ...
def jobj(id: str) -> object: ...

# Resolves an id string to its object; passes a non-str through unchanged.
def jref(id_or_obj: object) -> object: ...

# Generic over the class so `new(Date, ...).getTime()` keeps the constructed
# type instead of collapsing to `object`. Constructor args stay `object` --
# `new` forwards them verbatim, so they are not validated here.
def new(cls: type[_NewT], *args: object) -> _NewT: ...
def grant(archetype: object, level: object = None) -> None: ...
def revoke(archetype: object) -> None: ...
def allroots() -> list[Root]: ...
def save(obj: object) -> None: ...
def commit(anchor: object = None) -> None: ...
def on_commit(callback: Callable[[], object]) -> None: ...
def store(base_path: str = "./storage", create_dirs: bool = True) -> object: ...
def archetype_alias(old_name: str) -> Callable[[type], type]: ...

llm: LLMModel

def printgraph(
    nd: object = None,
    depth: int = -1,
    traverse: bool = False,
    edge_type: list[str] | None = None,
    bfs: bool = True,
    edge_limit: int = 512,
    node_limit: int = 512,
    file: str | None = None,
    format: str = "dot",
) -> str: ...
def restspec(**specs: object) -> Callable[..., Any]: ...
def schedule(**kwargs: object) -> Callable[..., Any]: ...

_ManagedT = TypeVar("_ManagedT")

def managed(x: _ManagedT) -> _ManagedT: ...

_TakeT = TypeVar("_TakeT")

# Move the value out of an optional owned place (a local or an attribute),
# leaving None behind. The exit from a place, as a call.
def take(place: _TakeT) -> _TakeT: ...

# Exchange the values of two places of one type, in place.
def swap(a: _TakeT, b: _TakeT) -> None: ...

# A window onto a slice of a backing sequence, without copying it.
class JacListView:
    backing: object
    start: int
    stop: int
    def __len__(self) -> int: ...
    def __getitem__(self, i: object) -> Any: ...
    def __setitem__(self, i: object, v: object) -> None: ...
    def __iter__(self) -> Any: ...

# ── Schema evolution rule builders ─────────────────────────────────
# Declared inside an archetype body to describe how a stored graph
# migrates to the current shape.

def schema_was(old_fqn: str) -> None: ...
def schema_alias(new_name: str, stored: str) -> None: ...
def schema_drop(field_name: str, until: str | None = None) -> None: ...
def schema_upgrade(
    fn: Callable[..., object], when: Callable[..., object] | None = None
) -> None: ...

# Returns a sentinel object that the JSX flattener turns into raw HTML
# (`dangerouslySetInnerHTML` on jac-client, `innerHTML` on bare-serve).
# Use only with content you trust -- the name is the security review hint.
def unsafe_html(html: object) -> object: ...

# ── Test builtins ──────────────────────────────────────────────────
# Ambient inside `test` blocks (and anywhere else) so a suite needs no
# import to skip, fail, or assert that a block raises.

class RaisesContext:
    excs: tuple[type[BaseException], ...]
    pattern: str | None
    value: BaseException | None
    def __enter__(self) -> RaisesContext: ...
    def __exit__(self, exc_type: object, exc: object, tb: object) -> bool: ...
    def match(self, regexp: str) -> bool: ...

def testskip(reason: str = "") -> NoReturn: ...
def testfail(reason: str = "") -> NoReturn: ...
def testraises(
    *excs: type[BaseException], match: str | None = None
) -> RaisesContext: ...

# ── User-facing builtin functions (from jaclang.jac0core.jaclib) ────
# These jaclib functions are directly callable by users in Jac code.
# Codegen emits `from jaclang.jac0core.jaclib import <name>`.

def destroy(objs: object) -> None: ...

# ── Builtin enums ──────────────────────────────────────────────────
class AccessLevel:
    NO_ACCESS: AccessLevel
    READ: AccessLevel
    CONNECT: AccessLevel
    WRITE: AccessLevel

class ScheduleTrigger:
    STATIC: str
    DYNAMIC: str

class APIProtocol:
    HTTP: str
    WEBHOOK: str
    WEBSOCKET: str
