import os;
import logging;
import from uuid { UUID }
import from collections.abc { Callable }

import from jaclang.jac0core.archetype {
    Archetype,
    NodeAnchor,
    NodeArchetype,
    ObjectSpatialDestination,
    ObjectSpatialPath
}
import from jaclang.runtimelib.memory { Memory }
import from jaclang.runtimelib.query_plan { QueryPlan }
import from jaclang.runtimelib.topology_index { TopologyIndex }

glob logger = logging.getLogger(__name__),
     __all__ = ['ChainHop', 'resolve_hop', 'resolve_path_anchors'];


obj ChainHop {
    has dest: ObjectSpatialDestination,
        edge_type: (str | None) = None,
        node_type: (str | None) = None,
        direction: int = 2;
}


def resolve_hop(
    mem: Memory,
    current_ids: set[UUID],
    hop: ChainHop,
    idx: (TopologyIndex | None),
    hop_idx: int,
    slc: (slice | None) = None
) -> (set[UUID] | list[UUID]);


def resolve_path_anchors(
    mem: Memory, path: ObjectSpatialPath, slc: (slice | None) = None
) -> list[NodeAnchor];
