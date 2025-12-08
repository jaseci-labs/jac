"""Jac specific builtins."""

from __future__ import annotations

import json
from abc import abstractmethod
from collections.abc import Callable
from typing import TYPE_CHECKING, Any, ClassVar, override

if TYPE_CHECKING:
    from enum import IntEnum

    from jaclang.runtimelib.constructs import AccessLevel, NodeArchetype
    from jaclang.runtimelib.runtime import JacRuntimeInterface

    # Exported via __getattr__
    jid: Callable[..., Any]
    jobj: Callable[..., Any]
    grant: Callable[..., Any]
    revoke: Callable[..., Any]
    allroots: Callable[..., Any]
    save: Callable[..., Any]
    commit: Callable[..., Any]
    NoPerm: IntEnum
    ReadPerm: IntEnum
    ConnectPerm: IntEnum
    WritePerm: IntEnum


def _get_jac() -> type[JacRuntimeInterface]:
    """Lazily get JacRuntimeInterface."""
    from jaclang.runtimelib.runtime import JacRuntimeInterface

    return JacRuntimeInterface


def _get_access_level() -> type[AccessLevel]:
    """Lazily get AccessLevel enum."""
    from jaclang.runtimelib.constructs import AccessLevel

    return AccessLevel


def _get_jid() -> Callable[..., Any]:
    """Get jid lazily."""
    return _get_jac().object_ref


def _get_jobj() -> Callable[..., Any]:
    """Get jobj lazily."""
    return _get_jac().get_object


def _get_grant() -> Callable[..., Any]:
    """Get grant lazily."""
    return _get_jac().perm_grant


def _get_revoke() -> Callable[..., Any]:
    """Get revoke lazily."""
    return _get_jac().perm_revoke


def _get_allroots() -> Callable[..., Any]:
    """Get allroots lazily."""
    return _get_jac().get_all_root


def _get_save() -> Callable[..., Any]:
    """Get save lazily."""
    return _get_jac().save


def _get_commit() -> Callable[..., Any]:
    """Get commit lazily."""
    return _get_jac().commit


# Create module level constants for easier access using __getattr__
def __getattr__(name: str) -> object:
    """Lazily resolve module-level attributes."""
    if name == "NoPerm":
        return _get_access_level().NO_ACCESS
    elif name == "ReadPerm":
        return _get_access_level().READ
    elif name == "ConnectPerm":
        return _get_access_level().CONNECT
    elif name == "WritePerm":
        return _get_access_level().WRITE
    elif name == "jid":
        return _get_jid()
    elif name == "jobj":
        return _get_jobj()
    elif name == "grant":
        return _get_grant()
    elif name == "revoke":
        return _get_revoke()
    elif name == "allroots":
        return _get_allroots()
    elif name == "save":
        return _get_save()
    elif name == "commit":
        return _get_commit()
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")


def printgraph(
    node: NodeArchetype | None = None,
    depth: int = -1,
    traverse: bool = False,
    edge_type: list[str] | None = None,
    bfs: bool = True,
    edge_limit: int = 512,
    node_limit: int = 512,
    file: str | None = None,
    format: str = "dot",
) -> str:
    """Print the graph in different formats."""
    jac = _get_jac()

    fmt = format.lower()
    if fmt == "json":
        return _jac_graph_json(file)

    return jac.printgraph(
        edge_type=edge_type,
        node=node or jac.root(),
        depth=depth,
        traverse=traverse,
        bfs=bfs,
        edge_limit=edge_limit,
        node_limit=node_limit,
        file=file,
        format=fmt,
    )


def _jac_graph_json(file: str | None = None) -> str:
    """Get the graph in json string."""
    from jaclang.runtimelib.utils import collect_node_connections

    jac = _get_jac()
    visited_nodes: set = set()
    connections: set = set()
    edge_ids: set = set()
    nodes: list[dict] = []
    edges: list[dict] = []
    root = jac.root()

    collect_node_connections(root, visited_nodes, connections, edge_ids)

    # Create nodes list from visited nodes
    nodes.append({"id": id(root), "label": "root"})
    for node_arch in visited_nodes:
        if node_arch != root:
            nodes.append({"id": id(node_arch), "label": repr(node_arch)})

    # Create edges list with labels from connections
    for _, source_node, target_node, edge_arch in connections:
        edge_data = {"from": str(id(source_node)), "to": str(id(target_node))}
        if repr(edge_arch) != "GenericEdge()":
            edge_data["label"] = repr(edge_arch)
        edges.append(edge_data)

    output = json.dumps(
        {
            "version": "1.0",
            "nodes": nodes,
            "edges": edges,
        }
    )
    if file:
        with open(file, "w") as f:
            f.write(output)
    return output


__all__ = [
    "abstractmethod",
    "ClassVar",
    "override",
    "printgraph",
    "jid",
    "jobj",
    "grant",
    "revoke",
    "allroots",
    "save",
    "commit",
    "NoPerm",
    "ReadPerm",
    "ConnectPerm",
    "WritePerm",
]
