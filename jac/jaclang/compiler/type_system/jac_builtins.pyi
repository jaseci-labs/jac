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
from typing import Any, NoReturn, Protocol, TypeVar

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
class Node: ...
class Edge: ...

class Walker:
    reports: list[Any]

class Obj: ...

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

class EdgeDir:
    OUT: int
    IN: int
    ANY: int

class LLMModel(Protocol):
    call_params: dict[str, object]
    def __call__(self, **kwargs: object) -> LLMModel: ...

# ── Fixed-width integer types ──────────────────────────────────────
class i8(int): ...  # noqa: N801
class u8(int): ...  # noqa: N801
class i16(int): ...  # noqa: N801
class u16(int): ...  # noqa: N801
class i32(int): ...  # noqa: N801
class u32(int): ...  # noqa: N801
class i64(int): ...  # noqa: N801
class u64(int): ...  # noqa: N801

# ── Fixed-width float types ────────────────────────────────────────
class f32(float): ...  # noqa: N801
class f64(float): ...  # noqa: N801

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
