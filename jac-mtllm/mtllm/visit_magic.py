"""This module contains functions for visiting and describing nodes in a graph-like structure."""

from __future__ import annotations

import inspect
from dataclasses import fields, is_dataclass

# from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _
from jaclang.runtimelib.constructs import (
    EdgeArchetype,
    NodeArchetype,
    WalkerArchetype,
)

from mtllm import Model

llm = Model(model_name="gemini/gemini-2.5-flash")


def describe_node_for_llm(obj: NodeArchetype | EdgeArchetype) -> str:
    """Return a string describing the attributes and methods of a node or edge object."""
    cls = obj.__class__
    lines = [f"Class: {cls.__name__}"]

    # Attributes
    lines.append("Attributes:")
    if is_dataclass(obj):
        for f in fields(cls):
            val = getattr(obj, f.name)
            type_name = (
                getattr(f.type, "__name__", str(f.type)) if f.type else "unknown"
            )
            lines.append(f"- {f.name}: {type_name} = {val!r}")
    else:
        for name, val in vars(obj).items():
            lines.append(f"- {name}: {type(val).__name__} = {val!r}")

    # Methods
    lines.append("Methods:")
    for name, func in inspect.getmembers(cls, predicate=inspect.isfunction):
        if not name.startswith("__"):
            sig = str(inspect.signature(func))
            lines.append(f"- {name}{sig}")

    return "\n".join(lines)


def describe_object_list_for_llm(objects: list[NodeArchetype | EdgeArchetype]) -> str:
    """Combine descriptions of a list of objects into a single string."""
    return "\n\n".join(describe_node_for_llm(obj) for obj in objects)


def get_where_to_visit_next(
    walker: WalkerArchetype,
    current_node: NodeArchetype,
    connected_nodes: list[NodeArchetype | EdgeArchetype],
    description: str = "",
) -> list[int]:
    """Determine the next nodes to visit by analyzing semantics using an LLM.

    Walker is a transitioning agent while the nodes are agents that can be visited.
    It returns the list of indexes of the next nodes to visit in order to complete the task of the walker.
    If no suitable node is found, it returns [].
    """
    return _.call_llm(
        model=llm(),
        caller=get_where_to_visit_next,
        args={
            "walker": walker,
            "current_node": current_node,
            "connected_nodes": connected_nodes,
            "description": description,
        },
    )


def visit_by(
    model: Model,
    walker: WalkerArchetype,
    node: NodeArchetype,
    connected_nodes: list[NodeArchetype],
) -> (
    list[NodeArchetype | EdgeArchetype]
    | list[NodeArchetype]
    | list[EdgeArchetype]
    | NodeArchetype
    | EdgeArchetype
):
    """Go through the available nodes and decide which next nodes to visit based on their semantics using an llm."""
    if not isinstance(model, Model):
        raise TypeError("Invalid llm object")
    if not connected_nodes:
        raise ValueError("No connected agents found for the walker")
    next_node_indexes = get_where_to_visit_next(
        walker,
        node,
        connected_nodes,
        description=describe_object_list_for_llm(connected_nodes),
    )
    ordered_list = []
    for index in next_node_indexes:
        if index < len(connected_nodes) and index >= 0:
            ordered_list.append(connected_nodes[index])
        else:
            raise IndexError("Index out of range for connected nodes")
    return ordered_list
