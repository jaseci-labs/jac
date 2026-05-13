"""Jac specific builtins."""
import json;
import from abc { abstractmethod }
import from collections.abc { Callable }
import from enum { StrEnum }
import from typing { Any, ClassVar, override }
import type from enum { IntEnum }
import type from jaclang.jac0core.constructs { AccessLevel, NodeArchetype }
import type from jaclang.jac0core.runtime { LLMModel }
import type from jaclang { JacRuntimeInterface }

enum APIProtocol ( StrEnum ) {
    HTTP = 'http',
    WEBHOOK = 'webhook',
    WEBSOCKET = 'websocket'
}

"""Trigger mode for a scheduled task."""
enum ScheduleTrigger ( StrEnum ) {
    STATIC = 'static',
    DYNAMIC = 'dynamic'
}

def _get_jac -> type[JacRuntimeInterface];

def _get_access_level -> type[AccessLevel];

def _get_jid -> Callable[..., Any];

def _get_jobj -> Callable[..., Any];

def _get_grant -> Callable[..., Any];

def _get_revoke -> Callable[..., Any];

def _get_allroots -> Callable[..., Any];

def _get_save -> Callable[..., Any];

def _get_commit -> Callable[..., Any];

def _get_store -> Callable[..., Any];

def _get_llm -> LLMModel;

def _get_archetype_alias -> Callable[..., Any];

def __getattr__(name: str) -> object;

def printgraph(
    nd: (NodeArchetype | None) = None,
    depth: int = -1,
    traverse: bool = False,
    edge_type: (list[str] | None) = None,
    bfs: bool = True,
    edge_limit: int = 512,
    node_limit: int = 512,
    file: (str | None) = None,
    format: str = 'dot'
) -> str;

def _jac_graph_json(file: (str | None) = None) -> str;

def restspec(**specs: Any) -> Callable;

def schedule(**kwargs: Any) -> Callable;

"""Portable constructor: returns ``cls(*args)``.

On the server this is just a thin alias for direct instantiation, so the
same source code can be written once and used in any codespace. In a
``cl { ... }`` block this same call lowers to
``Reflect.construct(cls, [args])`` (the JS spelling for ``new cls(...)``),
since JavaScript classes require ``new``.
"""
def new(cls: Any, *args: Any) -> Any;

glob __all__ = [
         'printgraph',
         'jid',
         'jobj',
         'grant',
         'revoke',
         'allroots',
         'save',
         'commit',
         'store',
         'llm',
         'new',
         'NoPerm',
         'ReadPerm',
         'ConnectPerm',
         'WritePerm',
         'restspec',
         'schedule',
         'ScheduleTrigger',
         'APIProtocol',
         'archetype_alias'
     ];
