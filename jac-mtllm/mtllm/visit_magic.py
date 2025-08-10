from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _
from jaclang.runtimelib.constructs import (
    AccessLevel,
    Anchor,
    Archetype,
    EdgeAnchor,
    EdgeArchetype,
    GenericEdge,
    JacTestCheck,
    NodeAnchor,
    NodeArchetype,
    Root,
    WalkerAnchor,
    WalkerArchetype,
)


def get_where_to_visit_next(
    walker: WalkerArchetype, current_node: NodeArchetype, connected_nodes: dict
) -> list[int]:
    """
    This function goes through the available nodes and decides which next nodes to visit based on their semantics using an llm.
    Walker is a transitioning agent while the nodes are agents that can be visited.

    It returns the list of indexes  of the next nodes to visit in order to complete the task of the walker.
    If no suitable node is found, it returns [].
    """
    return _.call_llm(
        model=llm(),
        caller=get_where_to_visit_next,
        args={
            "walker": walker,
            "current_node": current_node,
            "connected_nodes": connected_nodes,
        },
    )


def __by__(
    model: Model, walker: WalkerArchetype, node: NodeArchetype
) -> (
    list[NodeArchetype | EdgeArchetype]
    | list[NodeArchetype]
    | list[EdgeArchetype]
    | NodeArchetype
    | EdgeArchetype
):
    """
    This function goes through the available nodes and decides which next nodes to visit based on their semantics using an llm
    """
    if not isinstance(model, Model):
        raise TypeError("Invalid llm object")
    connected_nodes = _.refs(_.Path(_.root())._out())
    if not connected_nodes:
        raise ValueError("No connected agents found for the walker")
    next_node_indexes = get_where_to_visit_next(walker, node, connected_nodes)
    ordered_list = []
    for index in next_node_indexes:
        if index < len(connected_nodes) and index >= 0:
            ordered_list.append(connected_nodes[index])
        else:
            raise IndexError("Index out of range for connected nodes")
    return ordered_list


from mtllm import Model

llm = Model(model_name="gemini/gemini-2.5-flash")
