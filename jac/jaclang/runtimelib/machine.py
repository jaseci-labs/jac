"""Jac Language Features."""

from __future__ import annotations

import fnmatch
import html
import inspect
import os
import sys
import tempfile
import types
from collections import OrderedDict
from concurrent.futures import Future, ThreadPoolExecutor
from dataclasses import MISSING, dataclass, field
from functools import wraps
from inspect import getfile
from logging import getLogger
from typing import (
    Any,
    Callable,
    Coroutine,
    Optional,
    ParamSpec,
    TYPE_CHECKING,
    Type,
    TypeAlias,
    TypeVar,
    Union,
    cast,
)
from uuid import UUID


from jaclang.compiler.constant import Constants as Con, EdgeDir, colors
from jaclang.compiler.program import JacProgram
from jaclang.runtimelib.archetype import (
    DataSpatialDestination,
    DataSpatialFunction,
    DataSpatialPath,
    GenericEdge as _GenericEdge,
    Root as _Root,
)
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
from jaclang.runtimelib.memory import Memory, Shelf, ShelfStorage
from jaclang.runtimelib.utils import (
    all_issubclass,
    traverse_graph,
)
from jaclang.utils import infer_language

import pluggy


plugin_manager = pluggy.PluginManager("jac")
hookspec = pluggy.HookspecMarker("jac")
hookimpl = pluggy.HookimplMarker("jac")
logger = getLogger(__name__)

T = TypeVar("T")
P = ParamSpec("P")


class ExecutionContext:
    """Execution Context."""

    def __init__(
        self,
        session: Optional[str] = None,
        root: Optional[str] = None,
    ) -> None:
        """Initialize JacMachine."""
        self.mem: Memory = ShelfStorage(session)
        self.reports: list[Any] = []
        self.custom: Any = MISSING
        if not isinstance(
            system_root := self.mem.find_by_id(UUID(Con.SUPER_ROOT_UUID)), NodeAnchor
        ):
            system_root = cast(NodeAnchor, Root().__jac__)  # type: ignore[attr-defined]
            system_root.id = UUID(Con.SUPER_ROOT_UUID)
            self.mem.set(system_root.id, system_root)

        self.system_root = system_root

        self.entry_node = self.root_state = self.init_anchor(root, self.system_root)

    def init_anchor(
        self,
        anchor_id: str | None,
        default: NodeAnchor,
    ) -> NodeAnchor:
        """Load initial anchors."""
        if anchor_id:
            if isinstance(anchor := self.mem.find_by_id(UUID(anchor_id)), NodeAnchor):
                return anchor
            raise ValueError(f"Invalid anchor id {anchor_id} !")
        return default

    def set_entry_node(self, entry_node: str | None) -> None:
        """Override entry."""
        self.entry_node = self.init_anchor(entry_node, self.root_state)

    def close(self) -> None:
        """Close current ExecutionContext."""
        self.mem.close()
        JacMachine.reset_machine()

    def get_root(self) -> Root:
        """Get current root."""
        return cast(Root, self.root_state.archetype)

    def global_system_root(self) -> NodeAnchor:
        """Get global system root."""
        return self.system_root


class JacAccessValidation:
    """Jac Access Validation Specs."""

    @staticmethod
    def elevate_root() -> None:
        """Elevate context root to system_root."""
        jctx = JacMachineInterface.get_context()
        jctx.root_state = jctx.system_root

    @staticmethod
    def allow_root(
        archetype: Archetype,
        root_id: UUID,
        level: AccessLevel | int | str = AccessLevel.READ,
    ) -> None:
        """Allow all access from target root graph to current Archetype."""
        level = AccessLevel.cast(level)
        access = archetype.__jac__.access.roots

        _root_id = str(root_id)
        if level != access.anchors.get(_root_id, AccessLevel.NO_ACCESS):
            access.anchors[_root_id] = level

    @staticmethod
    def disallow_root(
        archetype: Archetype,
        root_id: UUID,
        level: AccessLevel | int | str = AccessLevel.READ,
    ) -> None:
        """Disallow all access from target root graph to current Archetype."""
        level = AccessLevel.cast(level)
        access = archetype.__jac__.access.roots

        access.anchors.pop(str(root_id), None)

    @staticmethod
    def perm_grant(
        archetype: Archetype, level: AccessLevel | int | str = AccessLevel.READ
    ) -> None:
        """Allow everyone to access current Archetype."""
        anchor = archetype.__jac__
        level = AccessLevel.cast(level)
        if level != anchor.access.all:
            anchor.access.all = level

    @staticmethod
    def perm_revoke(archetype: Archetype) -> None:
        """Disallow others to access current Archetype."""
        anchor = archetype.__jac__
        if anchor.access.all > AccessLevel.NO_ACCESS:
            anchor.access.all = AccessLevel.NO_ACCESS

    @staticmethod
    def check_read_access(to: Anchor) -> bool:
        """Read Access Validation."""
        if not (
            access_level := JacMachineInterface.check_access_level(to)
            > AccessLevel.NO_ACCESS
        ):
            logger.info(
                "Current root doesn't have read access to "
                f"{to.__class__.__name__} {to.archetype.__class__.__name__}[{to.id}]"
            )
        return access_level

    @staticmethod
    def check_connect_access(to: Anchor) -> bool:
        """Write Access Validation."""
        if not (
            access_level := JacMachineInterface.check_access_level(to)
            > AccessLevel.READ
        ):
            logger.info(
                "Current root doesn't have connect access to "
                f"{to.__class__.__name__} {to.archetype.__class__.__name__}[{to.id}]"
            )
        return access_level

    @staticmethod
    def check_write_access(to: Anchor) -> bool:
        """Write Access Validation."""
        if not (
            access_level := JacMachineInterface.check_access_level(to)
            > AccessLevel.CONNECT
        ):
            logger.info(
                "Current root doesn't have write access to "
                f"{to.__class__.__name__} {to.archetype.__class__.__name__}[{to.id}]"
            )
        return access_level

    @staticmethod
    def check_access_level(to: Anchor, no_custom: bool = False) -> AccessLevel:
        """Access validation."""
        if not to.persistent or to.hash == 0:
            return AccessLevel.WRITE

        jctx = JacMachineInterface.get_context()

        jroot = jctx.root_state

        # if current root is system_root
        # if current root id is equal to target anchor's root id
        # if current root is the target anchor
        if jroot == jctx.system_root or jroot.id == to.root or jroot == to:
            return AccessLevel.WRITE

        if (
            not no_custom
            and (custom_level := to.archetype.__jac_access__()) is not None
        ):
            return AccessLevel.cast(custom_level)

        access_level = AccessLevel.NO_ACCESS

        # if target anchor have set access.all
        if (to_access := to.access).all > AccessLevel.NO_ACCESS:
            access_level = to_access.all

        # if target anchor's root have set allowed roots
        # if current root is allowed to the whole graph of target anchor's root
        if to.root and isinstance(to_root := jctx.mem.find_one(to.root), Anchor):
            if to_root.access.all > access_level:
                access_level = to_root.access.all

            if (level := to_root.access.roots.check(str(jroot.id))) is not None:
                access_level = level

        # if target anchor have set allowed roots
        # if current root is allowed to target anchor
        if (level := to_access.roots.check(str(jroot.id))) is not None:
            access_level = level

        return access_level


class JacNode:
    """Jac Node Operations."""

    @staticmethod
    def get_edges(
        origin: list[NodeArchetype], destination: DataSpatialDestination
    ) -> list[EdgeArchetype]:
        """Get edges connected to this node."""
        edges: OrderedDict[EdgeAnchor, EdgeArchetype] = OrderedDict()
        for node in origin:
            nanch = node.__jac__
            for anchor in nanch.edges:
                if (
                    (source := anchor.source)
                    and (target := anchor.target)
                    and destination.edge_filter(anchor.archetype)
                    and source.archetype
                    and target.archetype
                ):
                    if (
                        destination.direction in [EdgeDir.OUT, EdgeDir.ANY]
                        and nanch == source
                        and destination.node_filter(target.archetype)
                        and JacMachineInterface.check_read_access(target)
                    ):
                        edges[anchor] = anchor.archetype
                    if (
                        destination.direction in [EdgeDir.IN, EdgeDir.ANY]
                        and nanch == target
                        and destination.node_filter(source.archetype)
                        and JacMachineInterface.check_read_access(source)
                    ):
                        edges[anchor] = anchor.archetype
        return list(edges.values())

    @staticmethod
    def get_edges_with_node(
        origin: list[NodeArchetype],
        destination: DataSpatialDestination,
        from_visit: bool = False,
    ) -> list[EdgeArchetype | NodeArchetype]:
        """Get edges connected to this node and the node."""
        loc: OrderedDict[
            Union[NodeAnchor, EdgeAnchor], Union[NodeArchetype, EdgeArchetype]
        ] = OrderedDict()
        for node in origin:
            nanch = node.__jac__
            for anchor in nanch.edges:
                if (
                    (source := anchor.source)
                    and (target := anchor.target)
                    and destination.edge_filter(anchor.archetype)
                    and source.archetype
                    and target.archetype
                ):
                    if (
                        destination.direction in [EdgeDir.OUT, EdgeDir.ANY]
                        and nanch == source
                        and destination.node_filter(target.archetype)
                        and JacMachineInterface.check_read_access(target)
                    ):
                        loc[anchor] = anchor.archetype
                        loc[target] = target.archetype
                    if (
                        destination.direction in [EdgeDir.IN, EdgeDir.ANY]
                        and nanch == target
                        and destination.node_filter(source.archetype)
                        and JacMachineInterface.check_read_access(source)
                    ):
                        loc[anchor] = anchor.archetype
                        loc[source] = source.archetype
        return list(loc.values())

    @staticmethod
    def edges_to_nodes(
        origin: list[NodeArchetype], destination: DataSpatialDestination
    ) -> list[NodeArchetype]:
        """Get set of nodes connected to this node."""
        nodes: OrderedDict[NodeAnchor, NodeArchetype] = OrderedDict()
        for node in origin:
            nanch = node.__jac__
            for anchor in nanch.edges:
                if (
                    (source := anchor.source)
                    and (target := anchor.target)
                    and destination.edge_filter(anchor.archetype)
                    and source.archetype
                    and target.archetype
                ):
                    if (
                        destination.direction in [EdgeDir.OUT, EdgeDir.ANY]
                        and nanch == source
                        and destination.node_filter(target.archetype)
                        and JacMachineInterface.check_read_access(target)
                    ):
                        nodes[target] = target.archetype
                    if (
                        destination.direction in [EdgeDir.IN, EdgeDir.ANY]
                        and nanch == target
                        and destination.node_filter(source.archetype)
                        and JacMachineInterface.check_read_access(source)
                    ):
                        nodes[source] = source.archetype
        return list(nodes.values())

    @staticmethod
    def remove_edge(node: NodeAnchor, edge: EdgeAnchor) -> None:
        """Remove reference without checking sync status."""
        for idx, ed in enumerate(node.edges):
            if ed.id == edge.id:
                node.edges.pop(idx)
                break


class JacEdge:
    """Jac Edge Operations."""

    @staticmethod
    def detach(edge: EdgeAnchor) -> None:
        """Detach edge from nodes."""
        JacMachineInterface.remove_edge(node=edge.source, edge=edge)
        JacMachineInterface.remove_edge(node=edge.target, edge=edge)


class JacWalker:
    """Jac Edge Operations."""

    @staticmethod
    def visit(
        walker: WalkerArchetype,
        expr: (
            list[NodeArchetype | EdgeArchetype]
            | list[NodeArchetype]
            | list[EdgeArchetype]
            | NodeArchetype
            | EdgeArchetype
        ),
        insert_loc: int = -1,
    ) -> bool:  # noqa: ANN401
        """Jac's visit stmt feature."""
        if isinstance(walker, WalkerArchetype):
            """Walker visits node."""
            wanch = walker.__jac__
            before_len = len(wanch.next)
            next = []
            for anchor in (
                (i.__jac__ for i in expr) if isinstance(expr, list) else [expr.__jac__]
            ):
                if anchor not in wanch.ignores:
                    if isinstance(anchor, (NodeAnchor, EdgeAnchor)):
                        next.append(anchor)
                    else:
                        raise ValueError("Anchor should be NodeAnchor or EdgeAnchor.")
            if insert_loc < -len(wanch.next):  # for out of index selection
                insert_loc = 0
            elif insert_loc < 0:
                insert_loc += len(wanch.next) + 1
            wanch.next = wanch.next[:insert_loc] + next + wanch.next[insert_loc:]
            return len(wanch.next) > before_len
        else:
            raise TypeError("Invalid walker object")

    @staticmethod
    def ignore(
        walker: WalkerArchetype,
        expr: (
            list[NodeArchetype | EdgeArchetype]
            | list[NodeArchetype]
            | list[EdgeArchetype]
            | NodeArchetype
            | EdgeArchetype
        ),
    ) -> bool:  # noqa: ANN401
        """Jac's ignore stmt feature."""
        if isinstance(walker, WalkerArchetype):
            wanch = walker.__jac__
            before_len = len(wanch.ignores)
            for anchor in (
                (i.__jac__ for i in expr) if isinstance(expr, list) else [expr.__jac__]
            ):
                if anchor not in wanch.ignores:
                    if isinstance(anchor, NodeAnchor):
                        wanch.ignores.append(anchor)
                    elif isinstance(anchor, EdgeAnchor):
                        if target := anchor.target:
                            wanch.ignores.append(target)
                        else:
                            raise ValueError("Edge has no target.")
            return len(wanch.ignores) > before_len
        else:
            raise TypeError("Invalid walker object")

    @staticmethod
    def spawn_call(
        walker: WalkerAnchor,
        node: NodeAnchor | EdgeAnchor,
    ) -> WalkerArchetype:
        """Jac's spawn operator feature."""
        warch = walker.archetype
        walker.path = []
        current_loc = node.archetype

        # walker ability on any entry
        for i in warch._jac_entry_funcs_:
            if not i.trigger:
                i.func(warch, current_loc)
            if walker.disengaged:
                return warch

        while len(walker.next):
            if current_loc := walker.next.pop(0).archetype:
                # walker ability with loc entry
                for i in warch._jac_entry_funcs_:
                    if (
                        i.trigger
                        and (
                            all_issubclass(i.trigger, NodeArchetype)
                            or all_issubclass(i.trigger, EdgeArchetype)
                        )
                        and isinstance(current_loc, i.trigger)
                    ):
                        i.func(warch, current_loc)
                    if walker.disengaged:
                        return warch

                # loc ability with any entry
                for i in current_loc._jac_entry_funcs_:
                    if not i.trigger:
                        i.func(current_loc, warch)
                    if walker.disengaged:
                        return warch

                # loc ability with walker entry
                for i in current_loc._jac_entry_funcs_:
                    if (
                        i.trigger
                        and all_issubclass(i.trigger, WalkerArchetype)
                        and isinstance(warch, i.trigger)
                    ):
                        i.func(current_loc, warch)
                    if walker.disengaged:
                        return warch

                # loc ability with walker exit
                for i in current_loc._jac_exit_funcs_:
                    if (
                        i.trigger
                        and all_issubclass(i.trigger, WalkerArchetype)
                        and isinstance(warch, i.trigger)
                    ):
                        i.func(current_loc, warch)
                    if walker.disengaged:
                        return warch

                # loc ability with any exit
                for i in current_loc._jac_exit_funcs_:
                    if not i.trigger:
                        i.func(current_loc, warch)
                    if walker.disengaged:
                        return warch

                # walker ability with loc exit
                for i in warch._jac_exit_funcs_:
                    if (
                        i.trigger
                        and (
                            all_issubclass(i.trigger, NodeArchetype)
                            or all_issubclass(i.trigger, EdgeArchetype)
                        )
                        and isinstance(current_loc, i.trigger)
                    ):
                        i.func(warch, current_loc)
                    if walker.disengaged:
                        return warch
        # walker ability with any exit
        for i in warch._jac_exit_funcs_:
            if not i.trigger:
                i.func(warch, current_loc)
            if walker.disengaged:
                return warch

        walker.ignores = []
        return warch

    @staticmethod
    async def async_spawn_call(
        walker: WalkerAnchor,
        node: NodeAnchor | EdgeAnchor,
    ) -> WalkerArchetype:
        """Jac's spawn operator feature."""
        warch = walker.archetype
        walker.path = []
        current_loc = node.archetype

        # walker ability on any entry
        for i in warch._jac_entry_funcs_:
            if not i.trigger:
                result = i.func(warch, current_loc)
                if isinstance(result, Coroutine):
                    await result
            if walker.disengaged:
                return warch

        while len(walker.next):
            if current_loc := walker.next.pop(0).archetype:
                # walker ability with loc entry
                for i in warch._jac_entry_funcs_:
                    if (
                        i.trigger
                        and (
                            all_issubclass(i.trigger, NodeArchetype)
                            or all_issubclass(i.trigger, EdgeArchetype)
                        )
                        and isinstance(current_loc, i.trigger)
                    ):
                        result = i.func(warch, current_loc)
                        if isinstance(result, Coroutine):
                            await result
                    if walker.disengaged:
                        return warch

                # loc ability with any entry
                for i in current_loc._jac_entry_funcs_:
                    if not i.trigger:
                        result = i.func(current_loc, warch)
                        if isinstance(result, Coroutine):
                            await result
                    if walker.disengaged:
                        return warch

                # loc ability with walker entry
                for i in current_loc._jac_entry_funcs_:
                    if (
                        i.trigger
                        and all_issubclass(i.trigger, WalkerArchetype)
                        and isinstance(warch, i.trigger)
                    ):
                        result = i.func(current_loc, warch)
                        if isinstance(result, Coroutine):
                            await result
                    if walker.disengaged:
                        return warch

                # loc ability with walker exit
                for i in current_loc._jac_exit_funcs_:
                    if (
                        i.trigger
                        and all_issubclass(i.trigger, WalkerArchetype)
                        and isinstance(warch, i.trigger)
                    ):
                        result = i.func(current_loc, warch)
                        if isinstance(result, Coroutine):
                            await result
                    if walker.disengaged:
                        return warch

                # loc ability with any exit
                for i in current_loc._jac_exit_funcs_:
                    if not i.trigger:
                        result = i.func(current_loc, warch)
                        if isinstance(result, Coroutine):
                            await result
                    if walker.disengaged:
                        return warch

                # walker ability with loc exit
                for i in warch._jac_exit_funcs_:
                    if (
                        i.trigger
                        and (
                            all_issubclass(i.trigger, NodeArchetype)
                            or all_issubclass(i.trigger, EdgeArchetype)
                        )
                        and isinstance(current_loc, i.trigger)
                    ):
                        result = i.func(warch, current_loc)
                        if isinstance(result, Coroutine):
                            await result
                    if walker.disengaged:
                        return warch
        # walker ability with any exit
        for i in warch._jac_exit_funcs_:
            if not i.trigger:
                result = i.func(warch, current_loc)
                if isinstance(result, Coroutine):
                    await result
            if walker.disengaged:
                return warch

        walker.ignores = []
        return warch

    @staticmethod
    def spawn(
        op1: Archetype | list[Archetype], op2: Archetype | list[Archetype]
    ) -> Union[WalkerArchetype, Coroutine]:
        """Jac's spawn operator feature."""

        def collect_targets(
            walker: WalkerAnchor, items: list[Archetype]
        ) -> NodeAnchor | EdgeAnchor:
            for i in items:
                a = i.__jac__
                (
                    walker.next.append(a)
                    if isinstance(a, (NodeAnchor, EdgeAnchor))
                    else None
                )
                if isinstance(a, EdgeAnchor) and a.target:
                    walker.next.append(a.target)
            return walker.next[0]

        def assign(
            walker: WalkerAnchor, t: Archetype | list[Archetype]
        ) -> NodeAnchor | EdgeAnchor:
            if isinstance(t, NodeArchetype):
                node = t.__jac__
                walker.next = [node]
                return node
            elif isinstance(t, EdgeArchetype):
                edge = t.__jac__
                walker.next = [edge, edge.target]
                return edge
            elif isinstance(t, list) and all(
                isinstance(i, (NodeArchetype, EdgeArchetype)) for i in t
            ):
                return collect_targets(walker, t)
            else:
                raise TypeError("Invalid target object")

        if isinstance(op1, WalkerArchetype):
            warch, targ = op1, op2
        elif isinstance(op2, WalkerArchetype):
            warch, targ = op2, op1
        else:
            raise TypeError("Invalid walker object")

        walker: WalkerAnchor = warch.__jac__
        loc: NodeAnchor | EdgeAnchor = assign(walker, targ)

        if warch.__jac_async__:
            return JacMachineInterface.async_spawn_call(walker=walker, node=loc)
        return JacMachineInterface.spawn_call(walker=walker, node=loc)

    @staticmethod
    def disengage(walker: WalkerArchetype) -> bool:
        """Jac's disengage stmt feature."""
        walker.__jac__.disengaged = True
        return True


class JacClassReferences:
    """Default Classes References."""

    TYPE_CHECKING: bool = TYPE_CHECKING
    EdgeDir: TypeAlias = EdgeDir
    DSFunc: TypeAlias = DataSpatialFunction

    Obj: TypeAlias = Archetype
    Node: TypeAlias = NodeArchetype
    Edge: TypeAlias = EdgeArchetype
    Walker: TypeAlias = WalkerArchetype

    Root: TypeAlias = _Root
    GenericEdge: TypeAlias = _GenericEdge

    Path: TypeAlias = DataSpatialPath


class JacBuiltin:
    """Jac Builtins."""

    @staticmethod
    def printgraph(
        node: NodeArchetype,
        depth: int,
        traverse: bool,
        edge_type: Optional[list[str]],
        bfs: bool,
        edge_limit: int,
        node_limit: int,
        file: Optional[str],
        format: str,
    ) -> str:
        """Generate graph for visualizing nodes and edges."""
        edge_type = edge_type if edge_type else []
        visited_nodes: list[NodeArchetype] = []
        node_depths: dict[NodeArchetype, int] = {node: 0}
        queue: list = [[node, 0]]
        connections: list[tuple[NodeArchetype, NodeArchetype, EdgeArchetype]] = []

        def dfs(node: NodeArchetype, cur_depth: int) -> None:
            """Depth first search."""
            if node not in visited_nodes:
                visited_nodes.append(node)
                traverse_graph(
                    node,
                    cur_depth,
                    depth,
                    edge_type,
                    traverse,
                    connections,
                    node_depths,
                    visited_nodes,
                    queue,
                    bfs,
                    dfs,
                    node_limit,
                    edge_limit,
                )

        if bfs:
            cur_depth = 0
            while queue:
                current_node, cur_depth = queue.pop(0)
                if current_node not in visited_nodes:
                    visited_nodes.append(current_node)
                    traverse_graph(
                        current_node,
                        cur_depth,
                        depth,
                        edge_type,
                        traverse,
                        connections,
                        node_depths,
                        visited_nodes,
                        queue,
                        bfs,
                        dfs,
                        node_limit,
                        edge_limit,
                    )
        else:
            dfs(node, cur_depth=0)
        dot_content = (
            'digraph {\nnode [style="filled", shape="ellipse", '
            'fillcolor="invis", fontcolor="black"];\n'
        )
        mermaid_content = "flowchart LR\n"
        for source, target, edge in connections:
            edge_label = html.escape(str(edge.__jac__.archetype))
            dot_content += (
                f"{visited_nodes.index(source)} -> {visited_nodes.index(target)} "
                f' [label="{edge_label if "GenericEdge" not in edge_label else ""}"];\n'
            )
            if "GenericEdge" in edge_label or not edge_label.strip():
                mermaid_content += (
                    f"{visited_nodes.index(source)} -->"
                    f"{visited_nodes.index(target)}\n"
                )
            else:
                mermaid_content += (
                    f"{visited_nodes.index(source)} -->"
                    f'|"{edge_label}"| {visited_nodes.index(target)}\n'
                )
        for node_ in visited_nodes:
            color = (
                colors[node_depths[node_]] if node_depths[node_] < 25 else colors[24]
            )
            label = html.escape(str(node_.__jac__.archetype))
            dot_content += (
                f'{visited_nodes.index(node_)} [label="{label}"'
                f'fillcolor="{color}"];\n'
            )
            mermaid_content += f'{visited_nodes.index(node_)}["{label}"]\n'
        output = dot_content + "}" if format == "dot" else mermaid_content
        if file:
            with open(file, "w") as f:
                f.write(output)
        return output


class JacCmd:
    """Jac CLI command."""

    @staticmethod
    def create_cmd() -> None:
        """Create Jac CLI cmds."""


class JacBasics:
    """Jac Feature."""

    @staticmethod
    def setup() -> None:
        """Set Class References."""

    @staticmethod
    def get_context() -> ExecutionContext:
        """Get current execution context."""
        return JacMachine.exec_ctx

    @staticmethod
    def commit(anchor: Anchor | Archetype | None = None) -> None:
        """Commit all data from memory to datasource."""
        if isinstance(anchor, Archetype):
            anchor = anchor.__jac__

        mem = JacMachineInterface.get_context().mem
        mem.commit(anchor)

    @staticmethod
    def reset_graph(root: Optional[Root] = None) -> int:
        """Purge current or target graph."""
        ctx = JacMachineInterface.get_context()
        mem = cast(ShelfStorage, ctx.mem)
        ranchor = root.__jac__ if root else ctx.root_state

        deleted_count = 0
        for anchor in (
            anchors.values()
            if isinstance(anchors := mem.__shelf__, Shelf)
            else mem.__mem__.values()
        ):
            if anchor == ranchor or anchor.root != ranchor.id:
                continue

            if loaded_anchor := mem.find_by_id(anchor.id):
                deleted_count += 1
                JacMachineInterface.destroy([loaded_anchor])

        return deleted_count

    @staticmethod
    def get_object(id: str) -> Archetype | None:
        """Get object given id."""
        if id == "root":
            return JacMachineInterface.get_context().root_state.archetype
        elif obj := JacMachineInterface.get_context().mem.find_by_id(UUID(id)):
            return obj.archetype

        return None

    @staticmethod
    def object_ref(obj: Archetype) -> str:
        """Get object reference id."""
        return obj.__jac__.id.hex

    @staticmethod
    def make_archetype(cls: Type[Archetype]) -> Type[Archetype]:
        """Create a obj archetype."""
        entries: OrderedDict[str, JacMachineInterface.DSFunc] = OrderedDict(
            (fn.name, fn) for fn in cls._jac_entry_funcs_
        )
        exits: OrderedDict[str, JacMachineInterface.DSFunc] = OrderedDict(
            (fn.name, fn) for fn in cls._jac_exit_funcs_
        )
        for func in cls.__dict__.values():
            if callable(func):
                if hasattr(func, "__jac_entry"):
                    entries[func.__name__] = JacMachineInterface.DSFunc(
                        func.__name__, func
                    )
                if hasattr(func, "__jac_exit"):
                    exits[func.__name__] = JacMachineInterface.DSFunc(
                        func.__name__, func
                    )

        cls._jac_entry_funcs_ = [*entries.values()]
        cls._jac_exit_funcs_ = [*exits.values()]

        dataclass(eq=False)(cls)
        return cls

    @staticmethod
    def impl_patch_filename(
        file_loc: str,
    ) -> Callable[[Callable[P, T]], Callable[P, T]]:
        """Update impl file location."""

        def decorator(func: Callable[P, T]) -> Callable[P, T]:
            try:
                code = func.__code__
                new_code = types.CodeType(
                    code.co_argcount,
                    code.co_posonlyargcount,
                    code.co_kwonlyargcount,
                    code.co_nlocals,
                    code.co_stacksize,
                    code.co_flags,
                    code.co_code,
                    code.co_consts,
                    code.co_names,
                    code.co_varnames,
                    file_loc,
                    code.co_name,
                    code.co_qualname,
                    code.co_firstlineno,
                    code.co_linetable,
                    code.co_exceptiontable,
                    code.co_freevars,
                    code.co_cellvars,
                )
                func.__code__ = new_code
            except AttributeError:
                pass
            return func

        return decorator

    @staticmethod
    def jac_import(
        target: str,
        base_path: str,
        absorb: bool = False,
        mdl_alias: Optional[str] = None,
        override_name: Optional[str] = None,
        items: Optional[dict[str, Union[str, Optional[str]]]] = None,
        reload_module: Optional[bool] = False,
        lng: Optional[str] = None,
    ) -> tuple[types.ModuleType, ...]:
        """Core Import Process."""
        from jaclang.runtimelib.importer import (
            ImportPathSpec,
            JacImporter,
            PythonImporter,
        )

        if lng is None:
            lng = infer_language(target, base_path)

        spec = ImportPathSpec(
            target,
            base_path,
            absorb,
            mdl_alias,
            override_name,
            lng,
            items,
        )

        if not JacMachine.program:
            JacMachineInterface.attach_program(JacProgram())

        if lng == "py":
            import_result = PythonImporter().run_import(spec)
        else:
            import_result = JacImporter().run_import(spec, reload_module)

        return (
            (import_result.ret_mod,)
            if absorb or not items
            else tuple(import_result.ret_items)
        )

    @staticmethod
    def jac_test(test_fun: Callable) -> Callable:
        """Create a test."""
        file_path = getfile(test_fun)
        func_name = test_fun.__name__

        def test_deco() -> None:
            test_fun(JacTestCheck())

        test_deco.__name__ = test_fun.__name__
        JacTestCheck.add_test(file_path, func_name, test_deco)

        return test_deco

    @staticmethod
    def run_test(
        filepath: str,
        func_name: Optional[str] = None,
        filter: Optional[str] = None,
        xit: bool = False,
        maxfail: Optional[int] = None,
        directory: Optional[str] = None,
        verbose: bool = False,
    ) -> int:
        """Run the test suite in the specified .jac file."""
        test_file = False
        ret_count = 0
        if filepath:
            if filepath.endswith(".jac"):
                base, mod_name = os.path.split(filepath)
                base = base if base else "./"
                mod_name = mod_name[:-4]
                if mod_name.endswith(".test"):
                    mod_name = mod_name[:-5]
                JacTestCheck.reset()
                JacMachineInterface.jac_import(target=mod_name, base_path=base)
                JacTestCheck.run_test(
                    xit, maxfail, verbose, os.path.abspath(filepath), func_name
                )
                ret_count = JacTestCheck.failcount
            else:
                print("Not a .jac file.")
        else:
            directory = directory if directory else os.getcwd()

        if filter or directory:
            current_dir = directory if directory else os.getcwd()
            for root_dir, _, files in os.walk(current_dir, topdown=True):
                files = (
                    [file for file in files if fnmatch.fnmatch(file, filter)]
                    if filter
                    else files
                )
                files = [
                    file
                    for file in files
                    if not file.endswith((".test.jac", ".impl.jac"))
                ]
                for file in files:
                    if file.endswith(".jac"):
                        test_file = True
                        print(f"\n\n\t\t* Inside {root_dir}" + "/" + f"{file} *")
                        JacTestCheck.reset()
                        JacMachineInterface.jac_import(
                            target=file[:-4], base_path=root_dir
                        )
                        JacTestCheck.run_test(
                            xit, maxfail, verbose, os.path.abspath(file), func_name
                        )

                    if JacTestCheck.breaker and (xit or maxfail):
                        break
                if JacTestCheck.breaker and (xit or maxfail):
                    break
            JacTestCheck.breaker = False
            ret_count += JacTestCheck.failcount
            JacTestCheck.failcount = 0
            print("No test files found.") if not test_file else None

        return ret_count

    @staticmethod
    def field(factory: Callable[[], T] | None = None, init: bool = True) -> T:
        """Jac's field handler."""
        if factory:
            return field(default_factory=factory)
        return field(init=init)

    @staticmethod
    def report(expr: Any, custom: bool = False) -> None:  # noqa: ANN401
        """Jac's report stmt feature."""
        ctx = JacMachineInterface.get_context()
        if custom:
            ctx.custom = expr
        else:
            ctx.reports.append(expr)

    @staticmethod
    def refs(
        path: DataSpatialPath | NodeArchetype | list[NodeArchetype],
    ) -> (
        list[NodeArchetype] | list[EdgeArchetype] | list[NodeArchetype | EdgeArchetype]
    ):
        """Jac's apply_dir stmt feature."""
        if not isinstance(path, DataSpatialPath):
            path = DataSpatialPath(path, [DataSpatialDestination(EdgeDir.OUT)])

        origin = path.origin

        if path.edge_only:
            destinations = path.destinations[:-1]
        else:
            destinations = path.destinations
        while destinations:
            dest = path.destinations.pop(0)
            origin = JacMachineInterface.edges_to_nodes(origin, dest)

        if path.edge_only:
            if path.from_visit:
                return JacMachineInterface.get_edges_with_node(
                    origin, path.destinations[-1]
                )
            return JacMachineInterface.get_edges(origin, path.destinations[-1])
        return origin

    @staticmethod
    def filter(
        items: list[Archetype],
        func: Callable[[Archetype], bool],
    ) -> list[Archetype]:
        """Jac's filter archetype list."""
        return [item for item in items if func(item)]

    @staticmethod
    def connect(
        left: NodeArchetype | list[NodeArchetype],
        right: NodeArchetype | list[NodeArchetype],
        edge: Type[EdgeArchetype] | EdgeArchetype | None = None,
        undir: bool = False,
        conn_assign: tuple[tuple, tuple] | None = None,
        edges_only: bool = False,
    ) -> list[NodeArchetype] | list[EdgeArchetype]:
        """Jac's connect operator feature."""
        left = [left] if isinstance(left, NodeArchetype) else left
        right = [right] if isinstance(right, NodeArchetype) else right
        edges = []

        for i in left:
            _left = i.__jac__
            if JacMachineInterface.check_connect_access(_left):
                for j in right:
                    _right = j.__jac__
                    if JacMachineInterface.check_connect_access(_right):
                        edges.append(
                            JacMachineInterface.build_edge(
                                is_undirected=undir,
                                conn_type=edge,
                                conn_assign=conn_assign,
                            )(_left, _right)
                        )
        return right if not edges_only else edges

    @staticmethod
    def disconnect(
        left: NodeArchetype | list[NodeArchetype],
        right: NodeArchetype | list[NodeArchetype],
        dir: EdgeDir = EdgeDir.OUT,
        filter: Callable[[EdgeArchetype], bool] | None = None,
    ) -> bool:
        """Jac's disconnect operator feature."""
        disconnect_occurred = False
        left = [left] if isinstance(left, NodeArchetype) else left
        right = [right] if isinstance(right, NodeArchetype) else right

        for i in left:
            node = i.__jac__
            for anchor in set(node.edges):
                if (
                    (source := anchor.source)
                    and (target := anchor.target)
                    and (not filter or filter(anchor.archetype))
                    and source.archetype
                    and target.archetype
                ):
                    if (
                        dir in [EdgeDir.OUT, EdgeDir.ANY]
                        and node == source
                        and target.archetype in right
                        and JacMachineInterface.check_connect_access(target)
                    ):
                        (
                            JacMachineInterface.destroy([anchor])
                            if anchor.persistent
                            else JacMachineInterface.detach(anchor)
                        )
                        disconnect_occurred = True
                    if (
                        dir in [EdgeDir.IN, EdgeDir.ANY]
                        and node == target
                        and source.archetype in right
                        and JacMachineInterface.check_connect_access(source)
                    ):
                        (
                            JacMachineInterface.destroy([anchor])
                            if anchor.persistent
                            else JacMachineInterface.detach(anchor)
                        )
                        disconnect_occurred = True

        return disconnect_occurred

    @staticmethod
    def assign(target: list[T], attr_val: tuple[tuple[str], tuple[Any]]) -> list[T]:
        """Jac's assign comprehension feature."""
        for obj in target:
            attrs, values = attr_val
            for attr, value in zip(attrs, values):
                setattr(obj, attr, value)
        return target

    @staticmethod
    def root() -> Root:
        """Jac's root getter."""
        return JacMachine.get_context().get_root()

    @staticmethod
    def get_all_root() -> list[Root]:
        """Get all the roots."""
        jmem = JacMachineInterface.get_context().mem
        return list(jmem.all_root())

    @staticmethod
    def build_edge(
        is_undirected: bool,
        conn_type: Optional[Type[EdgeArchetype] | EdgeArchetype],
        conn_assign: Optional[tuple[tuple, tuple]],
    ) -> Callable[[NodeAnchor, NodeAnchor], EdgeArchetype]:
        """Jac's root getter."""
        ct = conn_type if conn_type else GenericEdge

        def builder(source: NodeAnchor, target: NodeAnchor) -> EdgeArchetype:
            edge = ct() if isinstance(ct, type) else ct

            eanch = edge.__jac__ = EdgeAnchor(
                archetype=edge,
                source=source,
                target=target,
                is_undirected=is_undirected,
            )
            source.edges.append(eanch)
            target.edges.append(eanch)

            if conn_assign:
                for fld, val in zip(conn_assign[0], conn_assign[1]):
                    if hasattr(edge, fld):
                        setattr(edge, fld, val)
                    else:
                        raise ValueError(f"Invalid attribute: {fld}")
            if source.persistent or target.persistent:
                JacMachineInterface.save(eanch)
            return edge

        return builder

    @staticmethod
    def save(
        obj: Archetype | Anchor,
    ) -> None:
        """Destroy object."""
        anchor = obj.__jac__ if isinstance(obj, Archetype) else obj

        jctx = JacMachineInterface.get_context()

        if not anchor.persistent and not anchor.root:
            anchor.persistent = True
            anchor.root = jctx.root_state.id

        jctx.mem.set(anchor.id, anchor)

        match anchor:
            case NodeAnchor():
                for ed in anchor.edges:
                    if ed.is_populated() and not ed.persistent:
                        JacMachineInterface.save(ed)
            case EdgeAnchor():
                if (src := anchor.source) and src.is_populated() and not src.persistent:
                    JacMachineInterface.save(src)
                if (trg := anchor.target) and trg.is_populated() and not trg.persistent:
                    JacMachineInterface.save(trg)
            case _:
                pass

    @staticmethod
    def destroy(objs: Archetype | Anchor | list[Archetype | Anchor]) -> None:
        """Destroy multiple objects passed in a tuple or list."""
        obj_list = objs if isinstance(objs, list) else [objs]
        for obj in obj_list:
            if not isinstance(obj, (Archetype, Anchor)):
                return
            anchor = obj.__jac__ if isinstance(obj, Archetype) else obj

            if JacMachineInterface.check_write_access(anchor):
                match anchor:
                    case NodeAnchor():
                        for edge in anchor.edges[:]:
                            JacMachineInterface.destroy([edge])
                    case EdgeAnchor():
                        JacMachineInterface.detach(anchor)
                    case _:
                        pass

                JacMachineInterface.get_context().mem.remove(anchor.id)

    @staticmethod
    def entry(func: Callable) -> Callable:
        """Mark a method as jac entry with this decorator."""
        setattr(func, "__jac_entry", None)  # noqa:B010
        return func

    @staticmethod
    def exit(func: Callable) -> Callable:
        """Mark a method as jac exit with this decorator."""
        setattr(func, "__jac_exit", None)  # noqa:B010
        return func

    @staticmethod
    def sem(semstr: str, inner_semstr: dict[str, str]) -> Callable:
        """Attach the semstring to the given object."""

        def decorator(obj: object) -> object:
            setattr(obj, "_jac_semstr", semstr)  # noqa:B010
            setattr(obj, "_jac_semstr_inner", inner_semstr)  # noqa:B010
            return obj

        return decorator

    @staticmethod
    def call_llm(model: object, mtir: object) -> Any:  # noqa: ANN401
        """Call the LLM model."""
        raise ImportError(
            "byLLM is not installed. Please install it with `pip install byllm` and run `jac clean`."
        )


class JacUtils:
    """Jac Machine Utilities."""

    @staticmethod
    def attach_program(jac_program: JacProgram) -> None:
        """Attach a JacProgram to the machine."""
        JacMachine.program = jac_program

    @staticmethod
    def load_module(
        module_name: str, module: types.ModuleType, force: bool = False
    ) -> None:
        """Load a module into the machine."""
        if module_name not in JacMachine.loaded_modules or force:
            JacMachine.loaded_modules[module_name] = module
            sys.modules[module_name] = module  # TODO: May want to nuke this one day

    @staticmethod
    def list_modules() -> list[str]:
        """List all loaded modules."""
        return list(JacMachine.loaded_modules.keys())

    @staticmethod
    def list_walkers(module_name: str) -> list[str]:
        """List all walkers in a specific module."""
        module = JacMachine.loaded_modules.get(module_name)
        if module:
            walkers = []
            for name, obj in inspect.getmembers(module):
                if isinstance(obj, type) and issubclass(obj, WalkerArchetype):
                    walkers.append(name)
            return walkers
        return []

    @staticmethod
    def list_nodes(module_name: str) -> list[str]:
        """List all nodes in a specific module."""
        module = JacMachine.loaded_modules.get(module_name)
        if module:
            nodes = []
            for name, obj in inspect.getmembers(module):
                if isinstance(obj, type) and issubclass(obj, NodeArchetype):
                    nodes.append(name)
            return nodes
        return []

    @staticmethod
    def list_edges(module_name: str) -> list[str]:
        """List all edges in a specific module."""
        module = JacMachine.loaded_modules.get(module_name)
        if module:
            nodes = []
            for name, obj in inspect.getmembers(module):
                if isinstance(obj, type) and issubclass(obj, EdgeArchetype):
                    nodes.append(name)
            return nodes
        return []

    @staticmethod
    def create_archetype_from_source(
        source_code: str,
        module_name: Optional[str] = None,
        base_path: Optional[str] = None,
        cachable: bool = False,
        keep_temporary_files: bool = False,
    ) -> Optional[types.ModuleType]:
        """Dynamically creates archetypes (nodes, walkers, etc.) from Jac source code."""
        from jaclang.runtimelib.importer import JacImporter, ImportPathSpec

        if not base_path:
            base_path = JacMachine.base_path_dir or os.getcwd()

        if base_path and not os.path.exists(base_path):
            os.makedirs(base_path)
        if not module_name:
            module_name = f"_dynamic_module_{len(JacMachine.loaded_modules)}"
        with tempfile.NamedTemporaryFile(
            mode="w",
            suffix=".jac",
            prefix=module_name + "_",
            dir=base_path,
            delete=False,
        ) as tmp_file:
            tmp_file_path = tmp_file.name
            tmp_file.write(source_code)

        try:
            importer = JacImporter()
            tmp_file_basename = os.path.basename(tmp_file_path)
            tmp_module_name, _ = os.path.splitext(tmp_file_basename)

            spec = ImportPathSpec(
                target=tmp_module_name,
                base_path=base_path,
                absorb=False,
                mdl_alias=None,
                override_name=module_name,
                lng="jac",
                items=None,
            )

            import_result = importer.run_import(spec, reload=False)
            module = import_result.ret_mod

            JacMachine.loaded_modules[module_name] = module
            return module
        except Exception as e:
            logger.error(f"Error importing dynamic module '{module_name}': {e}")
            return None
        finally:
            if not keep_temporary_files and os.path.exists(tmp_file_path):
                os.remove(tmp_file_path)

    @staticmethod
    def update_walker(
        module_name: str,
        items: Optional[dict[str, Union[str, Optional[str]]]],
    ) -> tuple[types.ModuleType, ...]:
        """Reimport the module."""
        from .importer import JacImporter, ImportPathSpec

        if module_name in JacMachine.loaded_modules:
            try:
                old_module = JacMachine.loaded_modules[module_name]
                importer = JacImporter()
                spec = ImportPathSpec(
                    target=module_name,
                    base_path=JacMachine.base_path_dir,
                    absorb=False,
                    mdl_alias=None,
                    override_name=None,
                    lng="jac",
                    items=items,
                )
                import_result = importer.run_import(spec, reload=True)
                ret_items = []
                if items:
                    for item_name in items:
                        if hasattr(old_module, item_name):
                            new_attr = getattr(import_result.ret_mod, item_name, None)
                            if new_attr:
                                ret_items.append(new_attr)
                                setattr(
                                    old_module,
                                    item_name,
                                    new_attr,
                                )
                return (old_module,) if not items else tuple(ret_items)
            except Exception as e:
                logger.error(f"Failed to update module {module_name}: {e}")
        else:
            logger.warning(f"Module {module_name} not found in loaded modules.")
        return ()

    @staticmethod
    def spawn_node(
        node_name: str,
        attributes: Optional[dict] = None,
        module_name: str = "__main__",
    ) -> NodeArchetype:
        """Spawn a node instance of the given node_name with attributes."""
        node_class = JacMachineInterface.get_archetype(module_name, node_name)
        if isinstance(node_class, type) and issubclass(node_class, NodeArchetype):
            if attributes is None:
                attributes = {}
            node_instance = node_class(**attributes)
            return node_instance
        else:
            raise ValueError(f"Node {node_name} not found.")

    @staticmethod
    def spawn_walker(
        walker_name: str,
        attributes: Optional[dict] = None,
        module_name: str = "__main__",
    ) -> WalkerArchetype:
        """Spawn a walker instance of the given walker_name."""
        walker_class = JacMachineInterface.get_archetype(module_name, walker_name)
        if isinstance(walker_class, type) and issubclass(walker_class, WalkerArchetype):
            if attributes is None:
                attributes = {}
            walker_instance = walker_class(**attributes)
            return walker_instance
        else:
            raise ValueError(f"Walker {walker_name} not found.")

    @staticmethod
    def get_archetype(module_name: str, archetype_name: str) -> Optional[Archetype]:
        """Retrieve an archetype class from a module."""
        module = JacMachine.loaded_modules.get(module_name)
        if module:
            return getattr(module, archetype_name, None)
        return None

    @staticmethod
    def thread_run(func: Callable, *args: object) -> Future:  # noqa: ANN401
        """Run a function in a thread."""
        _executor = JacMachine.pool
        return _executor.submit(func, *args)

    @staticmethod
    def thread_wait(future: Any) -> None:  # noqa: ANN401
        """Wait for a thread to finish."""
        return future.result()


class JacMachineInterface(
    JacClassReferences,
    JacAccessValidation,
    JacNode,
    JacEdge,
    JacWalker,
    JacBuiltin,
    JacCmd,
    JacBasics,
    JacUtils,
):
    """Jac Feature."""


def generate_plugin_helpers(
    plugin_class: Type[Any],
) -> tuple[Type[Any], Type[Any], Type[Any]]:
    """Generate three helper classes based on a plugin class.

    - Spec class: contains @hookspec placeholder methods.
    - Impl class: contains original plugin methods decorated with @hookimpl.
    - Proxy class: contains methods that call plugin_manager.hook.<method>.

    Returns:
        Tuple of (SpecClass, ImplClass, ProxyClass).
    """
    # Markers for spec and impl
    spec_methods = {}
    impl_methods = {}
    proxy_methods = {}

    for name, method in inspect.getmembers(plugin_class, predicate=inspect.isfunction):
        if name.startswith("_"):
            continue

        sig = inspect.signature(method)
        sig_nodef = sig.replace(
            parameters=[
                p.replace(default=inspect.Parameter.empty)
                for p in sig.parameters.values()
            ]
        )
        doc = method.__doc__ or ""

        # --- Spec placeholder ---
        def make_spec(
            name: str, sig_nodef: inspect.Signature, doc: str, method: Callable
        ) -> Callable:
            """Create a placeholder method for the spec class."""

            @wraps(method)
            def placeholder(*args: object, **kwargs: object) -> None:
                pass

            placeholder.__name__ = name
            placeholder.__doc__ = doc
            placeholder.__signature__ = sig_nodef  # type: ignore
            return placeholder

        spec_methods[name] = hookspec(firstresult=True)(
            make_spec(name, sig_nodef, doc, method)
        )

        # --- Impl class: original methods with @hookimpl ---
        wrapped_impl = wraps(method)(method)
        wrapped_impl.__signature__ = sig_nodef  # type: ignore
        impl_methods[name] = hookimpl(wrapped_impl)

        # --- Proxy class: call through plugin_manager.hook ---
        # Gather class variables and annotations from entire MRO (excluding built-ins)
        class_vars: dict[str, Any] = {}
        annotations: dict[str, Any] = {}
        for base in reversed(plugin_class.__mro__):
            if base is object:
                continue
            # collect annotations first so bases are overridden by subclasses
            base_ann = getattr(base, "__annotations__", {})
            annotations.update(base_ann)
            for key, value in base.__dict__.items():
                # skip private/special, methods, and descriptors
                if key.startswith("__"):
                    continue
                if callable(value) and not isinstance(value, type):
                    continue
                class_vars[key] = value

        def make_proxy(name: str, sig: inspect.Signature) -> Callable:
            """Create a proxy method for the proxy class."""

            def proxy(*args: object, **kwargs: object) -> object:
                # bind positionals to parameter names
                bound = sig.bind_partial(*args, **kwargs)  # noqa
                bound.apply_defaults()
                # grab the HookCaller
                hookcaller = getattr(plugin_manager.hook, name)  # noqa
                # call with named args only
                return hookcaller(**bound.arguments)

            proxy.__name__ = name
            proxy.__signature__ = sig  # type: ignore
            return proxy

        proxy_methods[name] = make_proxy(name, sig)

    # Construct classes
    spec_cls = type(f"{plugin_class.__name__}Spec", (object,), spec_methods)
    impl_cls = type(f"{plugin_class.__name__}Impl", (object,), impl_methods)
    proxy_namespace = {}
    proxy_namespace.update(class_vars)
    if annotations:
        proxy_namespace["__annotations__"] = annotations
    proxy_namespace.update(proxy_methods)
    proxy_cls = type(f"{plugin_class.__name__}", (object,), proxy_namespace)

    return spec_cls, impl_cls, proxy_cls


JacMachineSpec, JacMachineImpl, JacMachineInterface = generate_plugin_helpers(JacMachineInterface)  # type: ignore[misc]
plugin_manager.add_hookspecs(JacMachineSpec)


class JacMachine(JacMachineInterface):
    """Jac Machine State."""

    loaded_modules: dict[str, types.ModuleType] = {}
    base_path_dir: str = os.getcwd()
    program: JacProgram = JacProgram()
    pool: ThreadPoolExecutor = ThreadPoolExecutor()
    exec_ctx: ExecutionContext = ExecutionContext()

    @staticmethod
    def set_base_path(base_path: str) -> None:
        """Set the base path for the machine."""
        JacMachine.reset_machine()
        JacMachine.base_path_dir = (
            base_path if os.path.isdir(base_path) else os.path.dirname(base_path)
        )

    @staticmethod
    def set_context(context: ExecutionContext) -> None:
        """Set the context for the machine."""
        JacMachine.exec_ctx = context

    @staticmethod
    def reset_machine() -> None:
        """Reset the machine."""
        # for i in JacMachine.loaded_modules.values():
        #     sys.modules.pop(i.__name__, None)
        JacMachine.loaded_modules.clear()
        JacMachine.base_path_dir = os.getcwd()
        JacMachine.program = JacProgram()
        JacMachine.pool = ThreadPoolExecutor()
        JacMachine.exec_ctx = ExecutionContext()
