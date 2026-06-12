"""Jac specific builtins."""
import json;
import from abc { abstractmethod }
import from collections.abc { Callable }
import from enum { StrEnum }
import from typing { ClassVar, override }
import type from enum { IntEnum }
import type from jaclang.jac0core.constructs { AccessLevel, NodeArchetype }
import type from jaclang.jac0core.runtime { LLMModel }
import type from jaclang { JacRuntimeInterface }

enum APIProtocol(StrEnum) {
    HTTP = 'http',
    WEBHOOK = 'webhook',
    WEBSOCKET = 'websocket'
}

"""Trigger mode for a scheduled task."""
enum ScheduleTrigger(StrEnum) {
    STATIC = 'static',
    DYNAMIC = 'dynamic'
}

def _get_jac -> type[JacRuntimeInterface];

def _get_access_level -> type[AccessLevel];

def _get_jid -> Callable[..., any];

def _get_jobj -> Callable[..., any];

def _get_grant -> Callable[..., any];

def _get_revoke -> Callable[..., any];

def _get_allroots -> Callable[..., any];

def _get_save -> Callable[..., any];

def _get_commit -> Callable[..., any];

def _get_store -> Callable[..., any];

def _get_llm -> LLMModel;

def _get_archetype_alias -> Callable[..., any];

def _get_schema_builder(name: str) -> Callable[..., any];

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

def restspec(**specs: any) -> Callable;

def schedule(**kwargs: any) -> Callable;

"""Portable constructor: returns ``cls(*args)``.

On the server this is just a thin alias for direct instantiation, so the
same source code can be written once and used in any codespace. In a
``cl { ... }`` block this same call lowers to
``Reflect.construct(cls, [args])`` (the JS spelling for ``new cls(...)``),
since JavaScript classes require ``new``.
"""
def new(cls: any, *args: any) -> any;

"""Mark a string as raw HTML for insertion into JSX children.

Returns a sentinel ``dict`` (``{"__jacUnsafeHtml": <html>}``) that the
client runtime recognises and renders via ``dangerouslySetInnerHTML``
(jac-client / React) or ``element.innerHTML`` (bare-serve). On the server
this is an identity wrapper -- the marker survives JSON serialisation so a
walker can return pre-rendered HTML to a client view. Named ``unsafe_html``
because the caller takes responsibility for trust: the wrapped string is
emitted verbatim with no escaping. Anything that came from user input or
an LLM must be sanitised first.
"""
def unsafe_html(html: any) -> dict;

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
         'archetype_alias',
         'schema_was',
         'schema_alias',
         'schema_drop',
         'schema_upgrade',
         'unsafe_html'
     ];
