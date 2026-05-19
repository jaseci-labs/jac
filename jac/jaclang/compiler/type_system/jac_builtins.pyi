# Jac ambient builtins — single source of truth for the type checker.
#
# Only names listed in __all__ become ambient (visible without import);
# anything else stays private to this file. The TypeEvaluator merges these
# into builtins_module.names_in_scope, so they sit in the scope chain above
# every user module.
#
# Only USER-FACING names belong in __all__. Internal codegen helpers (connect,
# visit, refs, build_edge, etc.) are injected by PyastGenPass and should
# NOT be declared here — they would conflict with the type checker's own
# handling of the syntax they desugar from (++>, -->, visit [], etc.).
#
# Codegen (PyastGenPass) independently controls which `import` lines
# appear in the generated Python — it reads jaclib.__all__ and
# builtin.__all__ for that purpose. This file is NOT used by codegen.

from collections.abc import Callable
from typing import Any, Protocol

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
    "OPath",
    "DSFunc",
    "EdgeDir",
    "LLMModel",
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
    "store",
    "archetype_alias",
    "destroy",
    "new",
    "printgraph",
    "restspec",
    "schedule",
    # Ambient values and constants
    "llm",
    "NoPerm",
    "ReadPerm",
    "ConnectPerm",
    "WritePerm",
    # Builtin enums
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
class Root(Node): ...
class GenericEdge(Edge): ...

class JsxElement:
    tag: object
    props: dict[str, object]
    children: list[object]

class OPath: ...
class DSFunc: ...

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
def new(cls: type, *args: object) -> object: ...
def grant(archetype: object, level: object = None) -> None: ...
def revoke(archetype: object) -> None: ...
def allroots() -> list[Root]: ...
def save(obj: object) -> None: ...
def commit(anchor: object = None) -> None: ...
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

# ── User-facing builtin functions (from jaclang.jac0core.jaclib) ────
# These jaclib functions are directly callable by users in Jac code.
# Codegen emits `from jaclang.jac0core.jaclib import <name>`.

def destroy(objs: object) -> None: ...

# ── Permission constants ───────────────────────────────────────────
NoPerm: int
ReadPerm: int
ConnectPerm: int
WritePerm: int

# ── Builtin enums ──────────────────────────────────────────────────
class ScheduleTrigger:
    STATIC: str
    DYNAMIC: str

class APIProtocol:
    HTTP: str
    WEBHOOK: str
    WEBSOCKET: str
