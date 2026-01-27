"""Jac specific builtins."""
import json;
import from abc { abstractmethod }
import from collections.abc { Callable }
import from typing { TYPE_CHECKING, Any, ClassVar, override }

with entry {
    if TYPE_CHECKING {
        import from enum { IntEnum }
        import from jaclang.pycore.constructs { AccessLevel, NodeArchetype }
        import from jaclang { JacRuntimeInterface }
        jid: Callable[(..., Any)];
        jobj: Callable[(..., Any)];
        grant: Callable[(..., Any)];
        revoke: Callable[(..., Any)];
        allroots: Callable[(..., Any)];
        save: Callable[(..., Any)];
        commit: Callable[(..., Any)];
        NoPerm: IntEnum;
        ReadPerm: IntEnum;
        ConnectPerm: IntEnum;
        WritePerm: IntEnum;
    }
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

def __getattr__(name: str) -> object;

def printgraph(
    <>node: (NodeArchetype | None) = None,
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

glob __all__ = [
         'printgraph',
         'jid',
         'jobj',
         'grant',
         'revoke',
         'allroots',
         'save',
         'commit',
         'NoPerm',
         'ReadPerm',
         'ConnectPerm',
         'WritePerm',
         'restspec'
     ];
