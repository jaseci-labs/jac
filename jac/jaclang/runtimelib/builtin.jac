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

enum ScheduleTrigger(StrEnum) { STATIC = 'static', DYNAMIC = 'dynamic' }

def _get_jac -> type[JacRuntimeInterface];

def _get_access_level -> type[AccessLevel];

def _get_jid -> Callable[..., any];

def _get_jobj -> Callable[..., any];

def jref(id_or_obj: any) -> any;

def _get_jref -> Callable[..., any];

def _get_grant -> Callable[..., any];

def _get_revoke -> Callable[..., any];

def _get_allroots -> Callable[..., any];

def _get_save -> Callable[..., any];

def _get_commit -> Callable[..., any];

def _get_on_commit -> Callable[..., any];

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

def new(cls: any, *args: any) -> any;

def unsafe_html(html: any) -> dict;

def managed(x: any) -> any;

glob __all__ = [
         'printgraph',
         'jid',
         'jobj',
         'jref',
         'grant',
         'revoke',
         'allroots',
         'save',
         'commit',
         'on_commit',
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
         'unsafe_html',
         'managed'
     ];
