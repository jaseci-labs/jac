"""Jac specific builtins."""

from __future__ import annotations

import json
from abc import abstractmethod
from typing import ClassVar, Optional, override

from jaclang.runtimelib.archetype import AccessLevel
from jaclang.runtimelib.constructs import Archetype, NodeArchetype, Root
from jaclang.runtimelib.machine import JacMachineInterface as Jac


def printgraph(
    node: Optional[NodeArchetype] = None,
    depth: int = -1,
    traverse: bool = False,
    edge_type: Optional[list[str]] = None,
    bfs: bool = True,
    edge_limit: int = 512,
    node_limit: int = 512,
    file: Optional[str] = None,
    format: str = "dot",
) -> str:
    """Print the graph in different formats."""
    from jaclang.runtimelib.machine import JacMachineInterface as Jac

    fmt = format.lower()
    if fmt == "json":
        return _jac_graph_json(file)

    return Jac.printgraph(
        edge_type=edge_type,
        node=node or Jac.root(),
        depth=depth,
        traverse=traverse,
        bfs=bfs,
        edge_limit=edge_limit,
        node_limit=node_limit,
        file=file,
        format=fmt,
    )


def jid(obj: Archetype) -> str:
    """Get the id of the object."""
    return Jac.object_ref(obj)


def jobj(id: str) -> Archetype | None:
    """Get the object from the id."""
    return Jac.get_object(id)


def grant(obj: Archetype, level: AccessLevel) -> None:
    """Grant permission for the object."""
    Jac.perm_grant(obj, level=level)


def revoke(obj: Archetype) -> None:
    """Revoke permission for the object."""
    Jac.perm_revoke(obj)


def _jac_graph_json(file: Optional[str] = None) -> str:
    """Get the graph in json string."""
    processed: list[Root | NodeArchetype] = []
    nodes: list[dict] = []
    edges: list[dict] = []
    working_set: list[tuple] = []

    root = Jac.root()
    nodes.append({"id": id(root), "label": "root"})

    processed.append(root)
    working_set = [(root, ref) for ref in Jac.refs(root)]

    while working_set:
        start, end = working_set.pop(0)
        edges.append({"from": id(start), "to": id(end)})
        nodes.append({"id": id(end), "label": repr(end)})
        processed.append(end)
        for ref in Jac.refs(end):
            if ref not in processed:
                working_set.append((end, ref))
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
]
