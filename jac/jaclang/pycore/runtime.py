"""Jac Language Features."""

from __future__ import annotations

import fnmatch
import html
import inspect
import json
import os
import sys
import types
from collections import OrderedDict
from collections.abc import Callable, Coroutine, Iterator, Mapping, Sequence

# Direct imports from runtimelib (no longer lazy - these are now pure Python)
from concurrent.futures import Future, ThreadPoolExecutor
from contextlib import contextmanager, suppress
from dataclasses import dataclass, field
from functools import wraps
from http.server import HTTPServer
from inspect import getfile
from logging import getLogger
from pathlib import Path
from typing import (
    TYPE_CHECKING,
    Any,
    Literal,
    ParamSpec,
    TypeAlias,
    TypeVar,
    cast,
    get_type_hints,
)
from uuid import UUID

from jaclang.pycore.archetype import (
    GenericEdge,
    ObjectSpatialDestination,
    ObjectSpatialFunction,
    ObjectSpatialPath,
    Root,
)
from jaclang.pycore.constant import EdgeDir, colors
from jaclang.pycore.constructs import (
    AccessLevel,
    Anchor,
    Archetype,
    EdgeAnchor,
    EdgeArchetype,
    NodeAnchor,
    NodeArchetype,
    WalkerAnchor,
    WalkerArchetype,
)
from jaclang.pycore.modresolver import infer_language
from jaclang.pycore.mtp import MTIR, MTRuntime
from jaclang.vendor import pluggy

if TYPE_CHECKING:
    from http.server import BaseHTTPRequestHandler

    from jaclang.cli.console import JacConsole as ConsoleImpl
    from jaclang.pycore.compiler import JacCompiler
    from jaclang.pycore.program import JacProgram
    from jaclang.runtimelib.client_bundle import ClientBundle, ClientBundleBuilder
    from jaclang.runtimelib.context import ExecutionContext
    from jaclang.runtimelib.server import JacAPIServer as JacServer
    from jaclang.runtimelib.server import ModuleIntrospector, UserManager

plugin_manager = pluggy.PluginManager("jac")
hookspec = pluggy.HookspecMarker("jac")
hookimpl = pluggy.HookimplMarker("jac")
logger = getLogger(__name__)

T = TypeVar("T")
P = ParamSpec("P")
JsonValue: TypeAlias = (
    None | str | int | float | bool | list["JsonValue"] | dict[str, "JsonValue"]
)
StatusCode: TypeAlias = Literal[200, 201, 400, 401, 404, 500, 503]


class JacAccessValidation:
    """Jac Access Validation Specs."""

    @staticmethod
    def allow_root(
        archetype: Archetype,
        root_id: UUID,
        level: AccessLevel | int | str | None = None,
    ) -> None:
        """Allow all access from target root graph to current Archetype."""
        if level is None:
            level = AccessLevel.READ
        level = AccessLevel.cast(level)

        # Get the anchor and ensure we're modifying the one in memory
        anchor = archetype.__jac__
        jctx = JacRuntimeInterface.get_context()

        # If there's already an anchor in memory for this ID, use that one
        # This ensures we don't have stale anchor objects with different access
        mem_anchor = jctx.mem.get(anchor.id)
        if mem_anchor and mem_anchor is not anchor:
            # Use the memory anchor's access, but update it
            anchor = mem_anchor

        access = anchor.access.roots
        _root_id = str(root_id)
        if level != access.anchors.get(_root_id, AccessLevel.NO_ACCESS):
            access.anchors[_root_id] = level
            # Ensure the modified anchor is in memory so it gets synced
            jctx.mem.put(anchor)

    @staticmethod
    def disallow_root(
        archetype: Archetype,
        root_id: UUID,
        level: AccessLevel | int | str | None = None,
    ) -> None:
        """Disallow all access from target root graph to current Archetype."""
        if level is None:
            level = AccessLevel.READ
        level = AccessLevel.cast(level)

        # Get the anchor and ensure we're modifying the one in memory
        anchor = archetype.__jac__
        jctx = JacRuntimeInterface.get_context()

        # If there's already an anchor in memory for this ID, use that one
        mem_anchor = jctx.mem.get(anchor.id)
        if mem_anchor and mem_anchor is not anchor:
            anchor = mem_anchor

        access = anchor.access.roots
        access.anchors.pop(str(root_id), None)
        # Ensure the modified anchor is in memory so it gets synced
        jctx.mem.put(anchor)

    @staticmethod
    def perm_grant(
        archetype: Archetype, level: AccessLevel | int | str | None = None
    ) -> None:
        """Allow everyone to access current Archetype."""
        if level is None:
            level = AccessLevel.READ
        level = AccessLevel.cast(level)

        # Get the anchor and ensure we're modifying the one in memory
        anchor = archetype.__jac__
        jctx = JacRuntimeInterface.get_context()

        # If there's already an anchor in memory for this ID, use that one
        # This ensures we don't have stale anchor objects with different access
        mem_anchor = jctx.mem.get(anchor.id)
        if mem_anchor and mem_anchor is not anchor:
            anchor = mem_anchor

        if level != anchor.access.all:
            anchor.access.all = level
            # Ensure the modified anchor is in memory so it gets synced
            jctx.mem.put(anchor)

    @staticmethod
    def perm_revoke(archetype: Archetype) -> None:
        """Disallow others to access current Archetype."""
        # Get the anchor and ensure we're modifying the one in memory
        anchor = archetype.__jac__
        jctx = JacRuntimeInterface.get_context()

        # If there's already an anchor in memory for this ID, use that one
        # This ensures we don't have stale anchor objects with different access
        mem_anchor = jctx.mem.get(anchor.id)
        if mem_anchor and mem_anchor is not anchor:
            anchor = mem_anchor

        if anchor.access.all > AccessLevel.NO_ACCESS:
            anchor.access.all = AccessLevel.NO_ACCESS
            # Ensure the modified anchor is in memory so it gets synced
            jctx.mem.put(anchor)

    @staticmethod
    def check_read_access(to: Anchor) -> bool:
        """Read Access Validation."""
        raw_level = JacRuntimeInterface.check_access_level(to)
        access_level = raw_level > AccessLevel.NO_ACCESS
        if not access_level:
            logger.info(
                "Current root doesn't have read access to "
                f"{to.__class__.__name__} {to.archetype.__class__.__name__}[{to.id}]"
            )
        return access_level

    @staticmethod
    def check_connect_access(to: Anchor) -> bool:
        """Write Access Validation."""
        if not (
            access_level := JacRuntimeInterface.check_access_level(to)
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
            access_level := JacRuntimeInterface.check_access_level(to)
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

        jctx = JacRuntimeInterface.get_context()

        jroot = jctx.user_root

        # if current root is system_root (superuser)
        # if current root id is equal to target anchor's root id (ownership)
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
        # Use get() instead of find_one() to check persistence for root lookup
        if to.root and isinstance(to_root := jctx.mem.get(to.root), Anchor):
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
        origin: list[NodeArchetype], destination: ObjectSpatialDestination
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
                        and JacRuntimeInterface.check_read_access(target)
                    ):
                        edges[anchor] = anchor.archetype
                    if (
                        destination.direction in [EdgeDir.IN, EdgeDir.ANY]
                        and nanch == target
                        and destination.node_filter(source.archetype)
                        and JacRuntimeInterface.check_read_access(source)
                    ):
                        edges[anchor] = anchor.archetype
        return list(edges.values())

    @staticmethod
    def get_edges_with_node(
        origin: list[NodeArchetype],
        destination: ObjectSpatialDestination,
        from_visit: bool = False,
    ) -> list[EdgeArchetype | NodeArchetype]:
        """Get edges connected to this node and the node."""
        loc: OrderedDict[NodeAnchor | EdgeAnchor, NodeArchetype | EdgeArchetype] = (
            OrderedDict()
        )
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
                        and JacRuntimeInterface.check_read_access(target)
                    ):
                        loc[anchor] = anchor.archetype
                        loc[target] = target.archetype
                    if (
                        destination.direction in [EdgeDir.IN, EdgeDir.ANY]
                        and nanch == target
                        and destination.node_filter(source.archetype)
                        and JacRuntimeInterface.check_read_access(source)
                    ):
                        loc[anchor] = anchor.archetype
                        loc[source] = source.archetype
        return list(loc.values())

    @staticmethod
    def edges_to_nodes(
        origin: list[NodeArchetype], destination: ObjectSpatialDestination
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
                        and JacRuntimeInterface.check_read_access(target)
                    ):
                        nodes[target] = target.archetype
                    if (
                        destination.direction in [EdgeDir.IN, EdgeDir.ANY]
                        and nanch == target
                        and destination.node_filter(source.archetype)
                        and JacRuntimeInterface.check_read_access(source)
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
        JacRuntimeInterface.remove_edge(node=edge.source, edge=edge)
        JacRuntimeInterface.remove_edge(node=edge.target, edge=edge)


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
            | ObjectSpatialPath
        ),
        insert_loc: int = -1,
    ) -> bool:  # noqa: ANN401
        """Jac's visit stmt feature."""
        # Resolve ObjectSpatialPath to list of nodes/edges
        if isinstance(expr, ObjectSpatialPath):
            expr.from_visit = True
            expr = JacRuntimeInterface.refs(expr)

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
    def _execute_entries(
        warch: WalkerArchetype,
        walker: WalkerAnchor,
        current_loc: NodeArchetype | EdgeArchetype,
    ) -> bool:
        """Execute all entry abilities for current location.

        Returns True if walker should continue, False if disengaged.
        """
        from jaclang.runtimelib.utils import all_issubclass

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
                return False

        # loc ability with any entry
        for i in current_loc._jac_entry_funcs_:
            if not i.trigger:
                i.func(current_loc, warch)
            if walker.disengaged:
                return False

        # loc ability with walker entry
        for i in current_loc._jac_entry_funcs_:
            if (
                i.trigger
                and all_issubclass(i.trigger, WalkerArchetype)
                and isinstance(warch, i.trigger)
            ):
                i.func(current_loc, warch)
            if walker.disengaged:
                return False

        return True

    @staticmethod
    def _execute_exits(
        warch: WalkerArchetype,
        walker: WalkerAnchor,
        current_loc: NodeArchetype | EdgeArchetype,
    ) -> bool:
        """Execute all exit abilities for current location.

        Returns True if walker should continue, False if disengaged.
        """
        from jaclang.runtimelib.utils import all_issubclass

        # loc ability with walker exit
        for i in current_loc._jac_exit_funcs_:
            if (
                i.trigger
                and all_issubclass(i.trigger, WalkerArchetype)
                and isinstance(warch, i.trigger)
            ):
                i.func(current_loc, warch)
            if walker.disengaged:
                return False

        # loc ability with any exit
        for i in current_loc._jac_exit_funcs_:
            if not i.trigger:
                i.func(current_loc, warch)
            if walker.disengaged:
                return False

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
                return False

        return True

    @staticmethod
    def _visit_node_recursive(
        warch: WalkerArchetype,
        walker: WalkerAnchor,
        anchor: NodeAnchor | EdgeAnchor,
    ) -> bool:
        """Recursively visit a node with DFS semantics.

        1. Execute entries for this node
        2. Recursively visit all children added during entry
        3. Execute exits for this node (post-order)

        Returns True if walker should continue, False if disengaged.
        """
        current_loc = anchor.archetype
        if not current_loc:
            return True

        # Track in path for debugging/introspection
        walker.path.append(anchor)

        # Phase 1: Execute entry abilities
        if not JacWalker._execute_entries(warch, walker, current_loc):
            return False

        # Phase 2: Process children (nodes added to walker.next during entries)
        # We drain the queue here - children added during entry are processed recursively
        while walker.next:
            child_anchor = walker.next.pop(0)
            if (
                child_anchor not in walker.ignores
                and not JacWalker._visit_node_recursive(warch, walker, child_anchor)
            ):
                return False

        # Phase 3: Execute exit abilities (post-order - after all descendants)
        return JacWalker._execute_exits(warch, walker, current_loc)

    @staticmethod
    def spawn_call(
        walker: WalkerAnchor,
        node: NodeAnchor | EdgeAnchor,
    ) -> WalkerArchetype:
        """Jac's spawn operator feature with recursive DFS semantics.

        Entry abilities execute when entering a node, exit abilities execute
        after all descendants are visited (post-order/LIFO).
        """
        warch = walker.archetype
        walker.path = []
        current_loc = node.archetype

        # Capture reports starting index to track reports from this spawn
        ctx = JacRuntimeInterface.get_context()
        call_state = ctx.call_state.get()

        # Walker ability on any entry (runs once at spawn, before traversal)
        for i in warch._jac_entry_funcs_:
            if not i.trigger:
                i.func(warch, current_loc)
            if walker.disengaged:
                walker.ignores = []
                # Capture reports generated during this spawn
                warch.reports = call_state.reports
                call_state.reports.put_nowait(call_state._sentinel)
                return warch

        # Traverse recursively (walker.next is already set by spawn())
        while walker.next:
            next_anchor = walker.next.pop(0)
            if (
                next_anchor not in walker.ignores
                and not JacWalker._visit_node_recursive(warch, walker, next_anchor)
            ):
                break

        # Walker ability with any exit (runs once after traversal completes)
        if walker.path:
            current_loc = walker.path[-1].archetype
        for i in warch._jac_exit_funcs_:
            if not i.trigger:
                i.func(warch, current_loc)
            if walker.disengaged:
                break

        walker.ignores = []
        # Capture reports generated during this spawn
        warch.reports = call_state.reports
        call_state.reports.put_nowait(call_state._sentinel)
        return warch

    @staticmethod
    async def _async_execute_entries(
        warch: WalkerArchetype,
        walker: WalkerAnchor,
        current_loc: NodeArchetype | EdgeArchetype,
    ) -> bool:
        """Async version: Execute all entry abilities for current location.

        Returns True if walker should continue, False if disengaged.
        """
        from jaclang.runtimelib.utils import all_issubclass

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
                return False

        # loc ability with any entry
        for i in current_loc._jac_entry_funcs_:
            if not i.trigger:
                result = i.func(current_loc, warch)
                if isinstance(result, Coroutine):
                    await result
            if walker.disengaged:
                return False

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
                return False

        return True

    @staticmethod
    async def _async_execute_exits(
        warch: WalkerArchetype,
        walker: WalkerAnchor,
        current_loc: NodeArchetype | EdgeArchetype,
    ) -> bool:
        """Async version: Execute all exit abilities for current location.

        Returns True if walker should continue, False if disengaged.
        """
        from jaclang.runtimelib.utils import all_issubclass

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
                return False

        # loc ability with any exit
        for i in current_loc._jac_exit_funcs_:
            if not i.trigger:
                result = i.func(current_loc, warch)
                if isinstance(result, Coroutine):
                    await result
            if walker.disengaged:
                return False

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
                return False

        return True

    @staticmethod
    async def _async_visit_node_recursive(
        warch: WalkerArchetype,
        walker: WalkerAnchor,
        anchor: NodeAnchor | EdgeAnchor,
    ) -> bool:
        """Async version: Recursively visit a node with DFS semantics.

        1. Execute entries for this node
        2. Recursively visit all children added during entry
        3. Execute exits for this node (post-order)

        Returns True if walker should continue, False if disengaged.
        """
        current_loc = anchor.archetype
        if not current_loc:
            return True

        # Track in path for debugging/introspection
        walker.path.append(anchor)

        # Phase 1: Execute entry abilities
        if not await JacWalker._async_execute_entries(warch, walker, current_loc):
            return False

        # Phase 2: Process children (nodes added to walker.next during entries)
        while walker.next:
            child_anchor = walker.next.pop(0)
            if (
                child_anchor not in walker.ignores
                and not await JacWalker._async_visit_node_recursive(
                    warch, walker, child_anchor
                )
            ):
                return False

        # Phase 3: Execute exit abilities (post-order - after all descendants)
        return await JacWalker._async_execute_exits(warch, walker, current_loc)

    @staticmethod
    async def async_spawn_call(
        walker: WalkerAnchor,
        node: NodeAnchor | EdgeAnchor,
    ) -> WalkerArchetype:
        """Jac's async spawn operator feature with recursive DFS semantics.

        Entry abilities execute when entering a node, exit abilities execute
        after all descendants are visited (post-order/LIFO).
        """
        warch = walker.archetype
        walker.path = []
        current_loc = node.archetype

        # Capture reports starting index to track reports from this spawn
        ctx = JacRuntimeInterface.get_context()
        call_state = ctx.call_state.get()

        # Walker ability on any entry (runs once at spawn, before traversal)
        for i in warch._jac_entry_funcs_:
            if not i.trigger:
                result = i.func(warch, current_loc)
                if isinstance(result, Coroutine):
                    await result
            if walker.disengaged:
                walker.ignores = []
                # Capture reports generated during this spawn
                warch.reports = call_state.reports
                call_state.reports.put_nowait(call_state._sentinel)
                return warch

        # Traverse recursively (walker.next is already set by spawn())
        while walker.next:
            next_anchor = walker.next.pop(0)
            if (
                next_anchor not in walker.ignores
                and not await JacWalker._async_visit_node_recursive(
                    warch, walker, next_anchor
                )
            ):
                break

        # Walker ability with any exit (runs once after traversal completes)
        if walker.path:
            current_loc = walker.path[-1].archetype
        for i in warch._jac_exit_funcs_:
            if not i.trigger:
                result = i.func(warch, current_loc)
                if isinstance(result, Coroutine):
                    await result
            if walker.disengaged:
                break

        walker.ignores = []
        # Capture reports generated during this spawn
        warch.reports = call_state.reports
        call_state.reports.put_nowait(call_state._sentinel)
        return warch

    @staticmethod
    def spawn(
        op1: Archetype | list[Archetype], op2: Archetype | list[Archetype]
    ) -> WalkerArchetype | Coroutine:
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
            return JacRuntimeInterface.async_spawn_call(walker=walker, node=loc)
        return JacRuntimeInterface.spawn_call(walker=walker, node=loc)

    @staticmethod
    def disengage(walker: WalkerArchetype) -> bool:
        """Jac's disengage stmt feature."""
        walker.__jac__.disengaged = True
        return True


class JacClassReferences:
    """Default Classes References - direct class attributes (no lazy loading)."""

    TYPE_CHECKING: bool = TYPE_CHECKING
    DSFunc = ObjectSpatialFunction
    OPath = ObjectSpatialPath
    Root = Root
    GenericEdge = GenericEdge
    Obj = Archetype
    Node = NodeArchetype
    Edge = EdgeArchetype
    Walker = WalkerArchetype


class JacBuiltin:
    """Jac Builtins."""

    @staticmethod
    def printgraph(
        node: NodeArchetype,
        depth: int,
        traverse: bool,
        edge_type: list[str] | None,
        bfs: bool,
        edge_limit: int,
        node_limit: int,
        file: str | None,
        format: str,
    ) -> str:
        """Generate graph for visualizing nodes and edges."""
        from jaclang.runtimelib.utils import traverse_graph

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
        dot_content = 'digraph {\nnode [style="filled", shape="ellipse", fillcolor="invis", fontcolor="black"];\n'
        mermaid_content = "flowchart LR\n"
        for source, target, edge in connections:
            edge_label = html.escape(str(edge.__jac__.archetype))
            dot_content += (
                f"{visited_nodes.index(source)} -> {visited_nodes.index(target)} "
                f' [label="{edge_label if "GenericEdge" not in edge_label else ""}"];\n'
            )
            if "GenericEdge" in edge_label or not edge_label.strip():
                mermaid_content += (
                    f"{visited_nodes.index(source)} -->{visited_nodes.index(target)}\n"
                )
            else:
                mermaid_content += f'{visited_nodes.index(source)} -->|"{edge_label}"| {visited_nodes.index(target)}\n'
        for node_ in visited_nodes:
            color = (
                colors[node_depths[node_]] if node_depths[node_] < 25 else colors[24]
            )
            label = html.escape(str(node_.__jac__.archetype))
            dot_content += (
                f'{visited_nodes.index(node_)} [label="{label}"fillcolor="{color}"];\n'
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
        if JacRuntime.exec_ctx is None:
            JacRuntime.exec_ctx = JacRuntimeInterface.create_j_context(user_root=None)
        return JacRuntime.exec_ctx

    @staticmethod
    def commit(anchor: Anchor | Archetype | None = None) -> None:
        """Commit all data from memory to datasource."""
        if isinstance(anchor, Archetype):
            anchor = anchor.__jac__

        ctx = JacRuntimeInterface.get_context()
        # Orchestrator handles commit to all storage backends
        ctx.mem.commit(anchor)

    @staticmethod
    def reset_graph(root: Root | None = None) -> int:
        """Purge current or target graph."""
        import pickle
        import sqlite3

        ctx = JacRuntimeInterface.get_context()
        mem = ctx.mem
        ranchor = root.__jac__ if root else ctx.user_root

        deleted_count = 0
        deleted_ids: set[UUID] = set()
        # Get anchors from persistence if available, otherwise from memory
        # Convert to list to avoid modifying during iteration
        persistence = mem.l3
        conn = getattr(persistence, "__conn__", None) if persistence else None
        if conn and isinstance(conn, sqlite3.Connection):
            cursor = conn.execute("SELECT data FROM anchors")
            anchors = [pickle.loads(row[0]) for row in cursor.fetchall()]
        else:
            anchors = list(mem.get_mem().values())

        # Direct bulk deletion - skip destroy/detach logic since we're purging everything
        for anchor in anchors:
            if anchor == ranchor or anchor.root != ranchor.id:
                continue
            deleted_ids.add(anchor.id)
            mem.delete(anchor.id)
            deleted_count += 1

        # Clean up root anchor's edges that reference deleted edge anchors
        ranchor.edges = [e for e in ranchor.edges if e.id not in deleted_ids]

        # Persist root anchor changes so next session sees cleaned up edges
        mem.commit(ranchor)

        return deleted_count

    @staticmethod
    def get_object(id: str) -> Archetype | None:
        """Get object given id."""
        if id == "root":
            return JacRuntimeInterface.get_context().user_root.archetype
        elif obj := JacRuntimeInterface.get_context().mem.get(UUID(id)):
            return obj.archetype

        return None

    @staticmethod
    def object_ref(obj: Archetype) -> str:
        """Get object reference id."""
        return obj.__jac__.id.hex

    @staticmethod
    def make_archetype(cls: type[Archetype]) -> type[Archetype]:
        """Create a obj archetype."""
        entries: OrderedDict[str, ObjectSpatialFunction] = OrderedDict(
            (fn.name, fn) for fn in cls._jac_entry_funcs_
        )
        exits: OrderedDict[str, ObjectSpatialFunction] = OrderedDict(
            (fn.name, fn) for fn in cls._jac_exit_funcs_
        )
        for func in cls.__dict__.values():
            if callable(func):
                if hasattr(func, "__jac_entry"):
                    entries[func.__name__] = JacRuntimeInterface.DSFunc(
                        func.__name__, func
                    )
                if hasattr(func, "__jac_exit"):
                    exits[func.__name__] = JacRuntimeInterface.DSFunc(
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
        override_name: str | None = None,
        items: dict[str, str | str | None] | None = None,
        reload_module: bool | None = False,
        lng: str | None = None,
    ) -> tuple[types.ModuleType, ...]:
        """Import a Jac or Python module using Python's standard import machinery.

        This function bridges Jac's import semantics with Python's import system,
        leveraging importlib.import_module() which automatically invokes our
        JacMetaImporter (registered in sys.meta_path).

        Args:
            target: Module name to import (e.g., "foo.bar" or ".relative")
            base_path: Base directory for resolving the module
            absorb: If True with items, return module instead of items
            override_name: Special handling for "__main__" execution context
            items: Specific items to import from module (like "from X import Y")
            reload_module: Force reload even if already in sys.modules
            lng: Language hint ("jac", "py", etc.) - auto-detected if None

        Returns:
            Tuple of imported module(s) or item(s)

        Examples:
            # Import entire module
            (mod,) = jac_import("mymod", "/path/to/base")

            # Import specific items
            (func, cls) = jac_import("mymod", "/path", items={"myfunc": None, "MyClass": None})

            # Run as __main__
            jac_import("mymod", "/path", override_name="__main__")
        """
        import importlib
        import importlib.util

        if lng is None:
            lng = infer_language(target, base_path)

        # Ensure the program exists before we use it
        _ = JacRuntime.get_program()

        # Compute the module name
        # Convert relative imports (e.g., ".foo") to absolute
        if target.startswith("."):
            # Relative import - need to resolve against base_path
            caller_dir = (
                base_path if os.path.isdir(base_path) else os.path.dirname(base_path)
            )
            chomp_target = target
            while chomp_target.startswith("."):
                if len(chomp_target) > 1 and chomp_target[1] == ".":
                    caller_dir = os.path.dirname(caller_dir)
                    chomp_target = chomp_target[1:]
                else:
                    chomp_target = chomp_target[1:]
                    break
            module_name = chomp_target
        else:
            module_name = target

        # Add base_path to sys.path for import resolution
        # The meta importer uses this for finding modules
        caller_dir = (
            base_path if os.path.isdir(base_path) else os.path.dirname(base_path)
        )
        original_path = None

        # Only modify sys.path if the directory isn't already there
        if caller_dir and caller_dir not in sys.path:
            original_path = sys.path.copy()
            sys.path.insert(0, caller_dir)

        try:
            # Handle special case: override_name="__main__" means run as script
            if override_name == "__main__":
                # For __main__ execution, we use spec_from_file_location
                from jaclang.meta_importer import JacMetaImporter

                finder = JacMetaImporter()
                # Pass None as path for top-level imports (e.g., "micro.simple_walk")
                # This ensures the meta importer searches sys.path correctly
                spec = finder.find_spec(module_name, None)
                if (
                    spec
                    and spec.origin
                    and spec.origin.endswith(".jac")
                    and lng == "py"
                ):
                    spec = None

                if (not spec or not spec.origin) and lng == "py":
                    file_path = os.path.join(caller_dir, f"{module_name}.py")
                    if os.path.isfile(file_path):
                        spec_name = (
                            "__main__" if override_name == "__main__" else module_name
                        )
                        spec = importlib.util.spec_from_file_location(
                            spec_name, file_path
                        )

                if not spec or not spec.origin:
                    raise ImportError(f"Cannot find module {module_name}")

                # Create or get __main__ module
                if "__main__" in sys.modules and not reload_module:
                    module = sys.modules["__main__"]
                    # Clear the module's dict except for special attributes
                    to_keep = {
                        k: v for k, v in module.__dict__.items() if k.startswith("__")
                    }
                    # module.__dict__.clear()
                    module.__dict__.update(to_keep)
                else:
                    module = types.ModuleType("__main__")
                    sys.modules["__main__"] = module

                # Set module attributes
                module.__file__ = spec.origin
                module.__name__ = "__main__"
                module.__spec__ = spec
                if spec.submodule_search_locations:
                    module.__path__ = spec.submodule_search_locations

                # Register in JacRuntime
                JacRuntimeInterface.load_module("__main__", module)

                # Execute the module
                if spec.loader:
                    spec.loader.exec_module(module)
            elif reload_module and module_name in sys.modules:
                # Handle reload case
                module = importlib.reload(sys.modules[module_name])
                # Update loaded_modules with the new module object
                JacRuntimeInterface.load_module(module_name, module, force=True)
            else:
                # Use Python's standard import machinery
                # This will invoke JacMetaImporter.find_spec() and exec_module()
                module = importlib.import_module(module_name)
                # If reload was requested but module wasn't in sys.modules (e.g., HMR cleared it),
                # still force update loaded_modules with the newly imported module
                if reload_module:
                    JacRuntimeInterface.load_module(module_name, module, force=True)

            # Handle selective item imports
            if items:
                imported_items = []
                for item_name, _ in items.items():
                    if hasattr(module, item_name):
                        item = getattr(module, item_name)
                        imported_items.append(item)
                    else:
                        raise ImportError(
                            f"Cannot import name '{item_name}' from '{module_name}'"
                        )
                return tuple(imported_items) if not absorb else (module,)

            return (module,)

        finally:
            # Restore original sys.path if we modified it
            if original_path is not None:
                sys.path[:] = original_path

    @staticmethod
    def jac_test(test_fun: Callable) -> Callable:
        """Create a test."""
        from jaclang.runtimelib.test import JacTestCheck

        file_path = getfile(test_fun)
        func_name = test_fun.__name__

        def test_deco() -> None:
            test_fun(JacTestCheck())

        test_deco.__name__ = test_fun.__name__
        JacTestCheck.add_test(file_path, func_name, test_deco)

        return test_deco

    @staticmethod
    def jsx(
        tag: object,
        attributes: Mapping[str, object] | None = None,
        children: Sequence[object] | None = None,
    ) -> dict[str, object]:
        """JSX interface for creating elements.

        Args:
            tag: Element tag (string for HTML elements, callable for components)
            attributes: Element attributes/props
            children: Child elements

        Returns:
            JSX element representation (implementation-defined)
        """
        props: dict[str, object] = dict(attributes) if attributes else {}
        child_list = list(children) if children else []
        return {
            "tag": tag,
            "props": props,
            "children": child_list,
        }

    @staticmethod
    def run_test(
        filepath: str,
        func_name: str | None = None,
        filter: str | None = None,
        xit: bool = False,
        maxfail: int | None = None,
        directory: str | None = None,
        verbose: bool = False,
    ) -> int:
        """Run the test suite in the specified .jac file."""
        from jaclang.runtimelib.test import JacTestCheck

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
                JacRuntimeInterface.jac_import(target=mod_name, base_path=base)
                JacTestCheck.run_test(
                    xit, maxfail, verbose, os.path.abspath(filepath), func_name
                )
                ret_count = JacTestCheck.failcount
            else:
                JacConsole.get_console().error("Not a .jac file.")
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
                        JacConsole.get_console().info(
                            f"\n\n\t\t* Inside {root_dir}/{file} *"
                        )
                        JacTestCheck.reset()
                        JacRuntimeInterface.jac_import(
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
            if not test_file:
                JacConsole.get_console().warning("No test files found.")

        return ret_count

    @staticmethod
    def field(factory: Callable[[], T] | None = None, init: bool = True) -> T:
        """Jac's field handler."""
        if factory:
            return field(default_factory=factory)
        return field(init=init)

    @staticmethod
    def log_report(expr: Any, custom: bool = False) -> None:  # noqa: ANN401
        """Jac's report stmt feature."""
        ctx = JacRuntimeInterface.get_context()
        if custom:
            ctx.custom = expr
        else:
            JacConsole.get_console().print(expr)
            ctx.call_state.get().reports.put_nowait(expr)

    @staticmethod
    def refs(
        path: ObjectSpatialPath | NodeArchetype | list[NodeArchetype],
    ) -> (
        list[NodeArchetype] | list[EdgeArchetype] | list[NodeArchetype | EdgeArchetype]
    ):
        """Jac's apply_dir stmt feature."""
        if not isinstance(path, ObjectSpatialPath):
            path = ObjectSpatialPath(path, [ObjectSpatialDestination(EdgeDir.OUT)])

        origin = path.origin

        destinations = path.destinations[:-1] if path.edge_only else path.destinations
        while destinations:
            dest = path.destinations.pop(0)
            origin = JacRuntimeInterface.edges_to_nodes(origin, dest)

        if path.edge_only:
            if path.from_visit:
                return JacRuntimeInterface.get_edges_with_node(
                    origin, path.destinations[-1]
                )
            return JacRuntimeInterface.get_edges(origin, path.destinations[-1])
        return origin

    @staticmethod
    async def arefs(
        path: ObjectSpatialPath | NodeArchetype | list[NodeArchetype],
    ) -> None:
        """Jac's apply_dir stmt feature."""
        pass

    @staticmethod
    def filter_on(
        items: list[Archetype],
        func: Callable[[Archetype], bool],
    ) -> list[Archetype]:
        """Jac's filter archetype list."""
        return [item for item in items if func(item)]

    @staticmethod
    def connect(
        left: NodeArchetype | list[NodeArchetype],
        right: NodeArchetype | list[NodeArchetype],
        edge: type[EdgeArchetype] | EdgeArchetype | None = None,
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
            if JacRuntimeInterface.check_connect_access(_left):
                for j in right:
                    _right = j.__jac__
                    if JacRuntimeInterface.check_connect_access(_right):
                        edges.append(
                            JacRuntimeInterface.build_edge(
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
                        and JacRuntimeInterface.check_connect_access(target)
                    ):
                        (
                            JacRuntimeInterface.destroy([anchor])
                            if anchor.persistent
                            else JacRuntimeInterface.detach(anchor)
                        )
                        disconnect_occurred = True
                    if (
                        dir in [EdgeDir.IN, EdgeDir.ANY]
                        and node == target
                        and source.archetype in right
                        and JacRuntimeInterface.check_connect_access(source)
                    ):
                        (
                            JacRuntimeInterface.destroy([anchor])
                            if anchor.persistent
                            else JacRuntimeInterface.detach(anchor)
                        )
                        disconnect_occurred = True

        return disconnect_occurred

    @staticmethod
    def assign_all(target: list[T], attr_val: tuple[tuple[str], tuple[Any]]) -> list[T]:
        """Jac's assign comprehension feature."""
        for obj in target:
            attrs, values = attr_val
            for attr, value in zip(attrs, values, strict=False):
                setattr(obj, attr, value)
        return target

    @staticmethod
    def safe_subscript(obj: Any, key: Any) -> Any:  # noqa: ANN401
        """Jac's safe subscript feature."""
        try:
            return obj[key]
        except (KeyError, IndexError, TypeError):
            return None

    @staticmethod
    def root() -> Root:
        """Jac's root getter."""
        return JacRuntime.get_context().get_root()

    @staticmethod
    def get_all_root() -> list[Root]:
        """Get all the roots."""
        jmem = JacRuntimeInterface.get_context().mem
        return list(jmem.get_roots())

    @staticmethod
    def build_edge(
        is_undirected: bool,
        conn_type: type[EdgeArchetype] | EdgeArchetype | None,
        conn_assign: tuple[tuple, tuple] | None,
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
                for fld, val in zip(conn_assign[0], conn_assign[1], strict=False):
                    if hasattr(edge, fld):
                        setattr(edge, fld, val)
                    else:
                        raise ValueError(f"Invalid attribute: {fld}")
            if source.persistent or target.persistent:
                JacRuntimeInterface.save(eanch)
            return edge

        return builder

    @staticmethod
    def save(
        obj: Archetype | Anchor,
    ) -> None:
        """Destroy object."""
        anchor = obj.__jac__ if isinstance(obj, Archetype) else obj

        jctx = JacRuntimeInterface.get_context()

        if not anchor.persistent and not anchor.root:
            anchor.persistent = True
            anchor.root = jctx.user_root.id

        jctx.mem.put(anchor)

        match anchor:
            case NodeAnchor():
                for ed in anchor.edges:
                    if ed.is_populated() and not ed.persistent:
                        JacRuntimeInterface.save(ed)
            case EdgeAnchor():
                if (src := anchor.source) and src.is_populated() and not src.persistent:
                    JacRuntimeInterface.save(src)
                if (trg := anchor.target) and trg.is_populated() and not trg.persistent:
                    JacRuntimeInterface.save(trg)
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

            if JacRuntimeInterface.check_write_access(anchor):
                match anchor:
                    case NodeAnchor():
                        for edge in anchor.edges[:]:
                            JacRuntimeInterface.destroy([edge])
                    case EdgeAnchor():
                        JacRuntimeInterface.detach(anchor)
                    case _:
                        pass

                JacRuntimeInterface.get_context().mem.delete(anchor.id)

    @staticmethod
    def on_entry(func: Callable) -> Callable:
        """Mark a method as jac entry with this decorator."""
        setattr(func, "__jac_entry", None)  # noqa:B010
        return func

    @staticmethod
    def on_exit(func: Callable) -> Callable:
        """Mark a method as jac exit with this decorator."""
        setattr(func, "__jac_exit", None)  # noqa:B010
        return func


class JacClientBundle:
    """Jac Client Bundle Operations - Generic interface for client bundling."""

    @staticmethod
    def get_client_bundle_builder() -> ClientBundleBuilder:
        """Get the client bundle builder instance."""
        from jaclang.runtimelib.client_bundle import ClientBundleBuilder

        return ClientBundleBuilder()

    @staticmethod
    def build_client_bundle(
        module: types.ModuleType,
        force: bool = False,
    ) -> ClientBundle:
        """Build a client bundle for the supplied module."""
        builder = JacRuntimeInterface.get_client_bundle_builder()
        return builder.build(module, force=force)


class JacConsole:
    """Jac Console Operations - Generic interface for console output."""

    @staticmethod
    def get_console() -> ConsoleImpl:
        """Get the console instance to use for CLI output.

        Plugins can override this hook to provide their own console implementation.
        The returned instance should be compatible with the JacConsole interface.
        """
        from jaclang.cli.console import JacConsole

        return JacConsole()


class JacAPIServer:
    """Jac API Server Operations - Generic interface for API server."""

    @staticmethod
    def get_api_server_class() -> type:
        """Get the JacAPIServer class to use for serve command.

        Plugins can override this hook to provide their own server class.
        The returned class should be compatible with the JacAPIServer interface.
        """
        from jaclang.runtimelib.server import JacAPIServer

        return JacAPIServer

    @staticmethod
    def create_server(
        jac_server: JacServer,
        host: str,
        port: int,
    ) -> HTTPServer:
        """Create the API server instance."""
        handler_class = jac_server.create_handler()
        return HTTPServer((host, port), handler_class)

    @staticmethod
    def render_page(
        introspector: ModuleIntrospector,
        function_name: str,
        args: dict[(str, Any)],
        username: str,
    ) -> dict[str, Any]:
        """Render HTML page for client function."""
        from jaclang.runtimelib.server import JacSerializer

        introspector.load()
        available_exports = set(
            introspector._client_manifest.get("exports", [])
        ) or set(introspector.get_client_functions().keys())
        if function_name not in available_exports:
            raise ValueError(f"Client function '{function_name}' not found")
        bundle_hash = introspector.ensure_bundle()
        arg_order = list(
            introspector._client_manifest.get("params", {}).get(function_name, [])
        )
        globals_payload = {
            name: JacSerializer.serialize(value)
            for name, value in introspector._collect_client_globals().items()
        }
        initial_state = {
            "module": introspector._module.__name__
            if introspector._module
            else introspector.module_name,
            "function": function_name,
            "args": {
                key: JacSerializer.serialize(value) for key, value in args.items()
            },
            "globals": globals_payload,
            "argOrder": arg_order,
        }
        safe_initial_json = json.dumps(initial_state).replace("</", "<\\/")
        page = f'<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"/><title>{html.escape(function_name)}</title></head><body><div id="__jac_root"></div><script id="__jac_init__" type="application/json">{safe_initial_json}</script><script src="/static/client.js?hash={bundle_hash}" defer></script></body></html>'
        return {
            "html": page,
            "bundle_hash": bundle_hash,
            "bundle_code": introspector._bundle.code,
        }


class JacResponseBuilder:
    """Jac Response Builder."""

    @staticmethod
    def send_json(
        handler: BaseHTTPRequestHandler, status: StatusCode, data: dict[str, JsonValue]
    ) -> None:
        """Send JSON response."""
        from jaclang.runtimelib.server import ResponseBuilder

        ResponseBuilder.send_json(handler, status, data)

    @staticmethod
    def send_html(
        handler: BaseHTTPRequestHandler, status: StatusCode, body: str
    ) -> None:
        """Send HTML response with CORS headers."""
        from jaclang.runtimelib.server import ResponseBuilder

        ResponseBuilder.send_html(handler, status, body)

    @staticmethod
    def send_javascript(handler: BaseHTTPRequestHandler, code: str) -> None:
        """Send JavaScript response."""
        from jaclang.runtimelib.server import ResponseBuilder

        ResponseBuilder.send_javascript(handler, code)

    @staticmethod
    def send_css(handler: BaseHTTPRequestHandler, css_code: str) -> None:
        """Send CSS response."""
        from jaclang.runtimelib.server import ResponseBuilder

        ResponseBuilder.send_css(handler, css_code)

    @staticmethod
    def send_static_file(
        handler: BaseHTTPRequestHandler,
        file_path: Path,
        content_type: str | None = None,
    ) -> None:
        """Send static file response (images, fonts, etc.)."""
        # Raise not implemented error
        raise NotImplementedError("send_static_file method is not implemented")


class JacByLLM:
    """Jac byLLM integration."""

    @staticmethod
    def get_mtir(
        caller: Callable, args: dict[int | str, object], call_params: dict[str, object]
    ) -> MTRuntime:
        """Get byLLM library."""
        return MTIR(caller=caller, args=args, call_params=call_params).runtime

    @staticmethod
    def sem(semstr: str, inner_semstr: dict[str, str]) -> Callable:
        """Attach the semstring to the given object."""

        def decorator(obj: object) -> object:
            setattr(obj, "_jac_semstr", semstr)  # noqa:B010
            setattr(obj, "_jac_semstr_inner", inner_semstr)  # noqa:B010
            return obj

        return decorator

    @staticmethod
    def call_llm(model: object, mtir: MTRuntime) -> Any:  # noqa: ANN401
        """Call the LLM model.

        This is the fallback implementation when no LLM plugin (like byllm) is installed.
        It uses NonGPT to generate random values matching the return type.
        """
        from jaclang.utils import NonGPT  # type: ignore[attr-defined]

        try:
            random_value_for_type = cast(
                Callable[[Any], Any],
                NonGPT.random_value_for_type,  # type: ignore[attr-defined]
            )
        except AttributeError:

            def random_value_for_type(_t: object) -> object:
                return None

        try:
            type_hints = get_type_hints(
                mtir.caller,
                globalns=getattr(mtir.caller, "__globals__", {}),
                localns=None,
                include_extras=True,
            )
        except Exception:
            type_hints = getattr(mtir.caller, "__annotations__", {})
        return_type = type_hints.get("return", Any)

        # Generate and return a random value matching the return type
        return random_value_for_type(return_type)

    @staticmethod
    def by(model: object) -> Callable:
        """Python library mode decorator for Jac's by llm() syntax."""

        def _decorator(caller: Callable) -> Callable:
            def _wrapped_caller(*args: object, **kwargs: object) -> object:
                invoke_args: dict[int | str, object] = {}
                for i, arg in enumerate(args):
                    invoke_args[i] = arg
                for key, value in kwargs.items():
                    invoke_args[key] = value
                mtir = JacRuntime.get_mtir(
                    caller=caller,
                    args=invoke_args,
                    call_params=(
                        model.call_params if hasattr(model, "call_params") else {}
                    ),
                )
                return JacRuntime.call_llm(model, mtir)

            return _wrapped_caller

        return _decorator

    @staticmethod
    def filter_visitable_by(
        connected_nodes: list[NodeArchetype], model: object, descriptions: str = ""
    ) -> list[NodeArchetype]:
        from .helpers import _describe_nodes_list

        visitable_list: list = []

        @JacByLLM.by(model=model)
        def _filter_visitable_by(
            connected_nodes: list[NodeArchetype], descriptions: str = ""
        ) -> list[int]:
            """
            Determine which connected nodes are visitable using an LLM.

            The input represents structurally reachable nodes. This function applies
            semantic reasoning to decide which of those nodes a walker is allowed
            or intended to visit, returning their indexes in priority order.

            Returns an empty list if no nodes are deemed visitable.
            """
            return []

        descriptions = _describe_nodes_list(connected_nodes)
        indexes = _filter_visitable_by(connected_nodes, descriptions)
        for idx in indexes:
            visitable_list.append(connected_nodes[idx])

        return visitable_list

    @staticmethod
    def by_operator(lhs: Any, rhs: Any) -> Any:  # noqa: ANN401
        """by operator feature for expression composition.

        Currently not implemented - raises NotImplementedError.
        Plugins like byllm can override this via the plugin hook system.
        """
        raise NotImplementedError(
            "The 'by' operator is not yet implemented. "
            "This feature is reserved for future use."
        )


class JacUtils:
    """Jac Machine Utilities."""

    @staticmethod
    def create_j_context(user_root: str | None) -> ExecutionContext:
        """Create a new execution context.

        Args:
            user_root: User root ID for permission boundary. Required parameter.
                       Pass None for CLI/system contexts (uses system_root).
                       Pass user's root ID for authenticated server requests.

        Storage backend is configured via plugins/environment, not per-context.
        For file backend: auto-generates path from JacRuntime.base_path_dir.
        For database backends (jac-scale): configured via environment variables.
        """
        from jaclang.runtimelib.context import ExecutionContext

        ctx = ExecutionContext()
        if user_root is not None:
            ctx.set_user_root(user_root)
        return ctx

    @staticmethod
    def attach_program(jac_program: JacProgram) -> None:
        """Attach a JacProgram to the machine."""
        JacRuntime.program = jac_program

    @staticmethod
    def attach_compiler(jac_compiler: JacCompiler) -> None:
        """Attach a JacCompiler to the machine."""
        JacRuntime.compiler = jac_compiler

    @staticmethod
    def load_module(
        module_name: str, module: types.ModuleType, force: bool = False
    ) -> None:
        """Load a module into the machine."""
        if module_name not in JacRuntime.loaded_modules or force:
            JacRuntime.loaded_modules[module_name] = module
            sys.modules[module_name] = module  # TODO: May want to nuke this one day

    @staticmethod
    def list_modules() -> list[str]:
        """List all loaded modules."""
        return list(JacRuntime.loaded_modules.keys())

    @staticmethod
    def list_walkers(module_name: str) -> list[str]:
        """List all walkers in a specific module."""
        module = JacRuntime.loaded_modules.get(module_name)
        if module:
            walkers = []
            for name, obj in inspect.getmembers(module):
                if (
                    isinstance(obj, type)
                    and issubclass(obj, WalkerArchetype)
                    and obj.__module__ == module_name
                ):
                    walkers.append(name)
            return walkers
        return []

    @staticmethod
    def list_nodes(module_name: str) -> list[str]:
        """List all nodes in a specific module."""
        module = JacRuntime.loaded_modules.get(module_name)
        if module:
            nodes = []
            for name, obj in inspect.getmembers(module):
                if (
                    isinstance(obj, type)
                    and issubclass(obj, NodeArchetype)
                    and obj.__module__ == module_name
                ):
                    nodes.append(name)
            return nodes
        return []

    @staticmethod
    def list_edges(module_name: str) -> list[str]:
        """List all edges in a specific module."""
        module = JacRuntime.loaded_modules.get(module_name)
        if module:
            edges = []
            for name, obj in inspect.getmembers(module):
                if (
                    isinstance(obj, type)
                    and issubclass(obj, EdgeArchetype)
                    and obj.__module__ == module_name
                ):
                    edges.append(name)
            return edges
        return []

    @staticmethod
    def create_archetype_from_source(
        source_code: str,
        module_name: str | None = None,
        base_path: str | None = None,
        cachable: bool = False,
        keep_temporary_files: bool = False,
    ) -> types.ModuleType | None:
        """Dynamically creates archetypes (nodes, walkers, etc.) from Jac source code.

        This leverages Python's standard import machinery via jac_import(),
        which will automatically invoke JacMetaImporter.
        """
        if not base_path:
            base_path = JacRuntime.base_path_dir or os.getcwd()

        if base_path and not os.path.exists(base_path):
            os.makedirs(base_path)
        if not module_name:
            module_name = f"_dynamic_module_{len(JacRuntime.loaded_modules)}"

        import tempfile

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
            tmp_file_basename = os.path.basename(tmp_file_path)
            tmp_module_name, _ = os.path.splitext(tmp_file_basename)

            # Use simplified jac_import which delegates to importlib
            result = JacRuntimeInterface.jac_import(
                target=tmp_module_name,
                base_path=base_path,
                override_name=module_name,
                lng="jac",
            )
            module = result[0] if result else None

            if module:
                JacRuntime.loaded_modules[module_name] = module
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
        items: dict[str, str | str | None] | None,
    ) -> tuple[types.ModuleType, ...]:
        """Reimport the module using Python's reload mechanism."""
        if module_name in JacRuntime.loaded_modules:
            try:
                old_module = JacRuntime.loaded_modules[module_name]

                # Use jac_import with reload flag
                result = JacRuntimeInterface.jac_import(
                    target=module_name,
                    base_path=JacRuntime.base_path_dir or os.getcwd(),
                    items=items,
                    reload_module=True,
                    lng="jac",
                )

                # Update the old module's attributes if specific items were requested
                if items:
                    ret_items = []
                    for idx, item_name in enumerate(items.keys()):
                        if hasattr(old_module, item_name) and idx < len(result):
                            new_attr = result[idx]
                            ret_items.append(new_attr)
                            setattr(old_module, item_name, new_attr)
                    return tuple(ret_items)

                return (old_module,)
            except Exception as e:
                logger.error(f"Failed to update module {module_name}: {e}")
        else:
            logger.warning(f"Module {module_name} not found in loaded modules.")
        return ()

    @staticmethod
    def spawn_node(
        node_name: str,
        attributes: dict | None = None,
        module_name: str = "__main__",
    ) -> NodeArchetype:
        """Spawn a node instance of the given node_name with attributes."""
        node_class = JacRuntimeInterface.get_archetype(module_name, node_name)
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
        attributes: dict | None = None,
        module_name: str = "__main__",
    ) -> WalkerArchetype:
        """Spawn a walker instance of the given walker_name."""
        walker_class = JacRuntimeInterface.get_archetype(module_name, walker_name)
        if isinstance(walker_class, type) and issubclass(walker_class, WalkerArchetype):
            if attributes is None:
                attributes = {}
            walker_instance = walker_class(**attributes)
            return walker_instance
        else:
            raise ValueError(f"Walker {walker_name} not found.")

    @staticmethod
    def get_archetype(module_name: str, archetype_name: str) -> Archetype | None:
        """Retrieve an archetype class from a module."""
        module = JacRuntime.loaded_modules.get(module_name)
        if module:
            return getattr(module, archetype_name, None)
        return None

    @staticmethod
    def thread_run(func: Callable, *args: object) -> Future:  # noqa: ANN401
        """Run a function in a thread."""
        _executor = JacRuntime.pool
        return _executor.submit(func, *args)

    @staticmethod
    def thread_wait(future: Any) -> None:  # noqa: ANN401
        """Wait for a thread to finish."""
        return future.result()


class JacPluginConfig:
    """Plugin configuration hooks for jac.toml integration.

    Plugins can implement these hooks to register their configuration schemas
    and receive configuration values from jac.toml.
    """

    @staticmethod
    def get_plugin_metadata() -> dict[str, Any] | None:
        """Return plugin metadata.

        Returns:
            dict with keys:
                - name: Plugin name (used in [plugins.<name>])
                - version: Plugin version
                - description: Brief description
        """
        return None

    @staticmethod
    def get_config_schema() -> dict[str, Any] | None:
        """Return the plugin's configuration schema.

        Returns:
            dict with keys:
                - section: Section name in jac.toml (e.g., 'byllm' for [plugins.byllm])
                - options: dict mapping option names to their specs:
                    {
                        'option_name': {
                            'type': 'str' | 'int' | 'float' | 'bool' | 'list' | 'dict',
                            'default': <default_value>,
                            'description': 'Description of the option',
                            'env_var': 'OPTIONAL_ENV_VAR_OVERRIDE',
                            'required': False,
                        }
                    }
        """
        return None

    @staticmethod
    def on_config_loaded(config: dict[str, Any]) -> None:
        """Called when plugin configuration is loaded from jac.toml.

        Args:
            config: The plugin's configuration values from [plugins.<name>]
        """
        pass

    @staticmethod
    def validate_config(config: dict[str, Any]) -> list[str]:
        """Validate plugin configuration.

        Args:
            config: The plugin's configuration values

        Returns:
            List of error messages (empty if valid)
        """
        return []

    @staticmethod
    def register_dependency_type() -> dict[str, Any] | None:
        """Register a custom dependency type.

        Allows plugins to extend [dependencies.*] sections in jac.toml.

        Returns:
            dict with keys:
                - name: Dependency type name (e.g., 'npm' for [dependencies.npm])
                - dev_name: Dev dependency section (e.g., 'npm.dev')
                - cli_flag: CLI flag for 'jac add' (e.g., '--cl')
                - install_dir: Directory for installed deps (e.g., 'client')
                - install_handler: Callable to install packages
                - remove_handler: Callable to remove packages
        """
        return None

    @staticmethod
    def register_project_template() -> dict[str, Any] | None:
        """Register a project template for jac create.

        Allows plugins to provide custom project templates that can be
        selected via `jac create --use <name>`.

        Returns:
            dict with keys:
                - name: Template name (e.g., 'client')
                - description: Human-readable description
                - config: dict for jac.toml content (with {{name}} placeholders)
                - files: dict[path, content] with {{name}} placeholders
                - directories: list of directories to create
                - gitignore_entries: list of .gitignore entries
                - post_create: optional callable(project_path, project_name)
        """
        return None


class JacRuntimeInterface(
    JacClassReferences,
    JacAccessValidation,
    JacNode,
    JacEdge,
    JacWalker,
    JacBuiltin,
    JacCmd,
    JacBasics,
    JacClientBundle,
    JacConsole,
    JacAPIServer,
    JacByLLM,
    JacResponseBuilder,
    JacUtils,
    JacPluginConfig,
):
    """Jac Feature."""

    @staticmethod
    def get_user_manager(base_path: str) -> UserManager:
        """Get UserManager instance (hookable for plugins).

        Plugins can override this to provide custom UserManager implementations.
        Default returns core UserManager.

        Args:
            base_path: Base path for user data storage

        Returns:
            UserManager instance
        """
        from jaclang.runtimelib.server import UserManager

        return UserManager(base_path=base_path)


def generate_plugin_helpers(
    plugin_class: type[Any],
) -> tuple[type[Any], type[Any], type[Any]]:
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

    # Use the original class's metaclass when creating the proxy class
    original_metaclass: type = cast(type, type(plugin_class))
    proxy_cls = original_metaclass(
        f"{plugin_class.__name__}", (object,), proxy_namespace
    )

    return spec_cls, impl_cls, proxy_cls


JacRuntimeSpec, JacRuntimeImpl, JacRuntimeInterface = generate_plugin_helpers(  # type: ignore[misc]
    JacRuntimeInterface
)
plugin_manager.add_hookspecs(JacRuntimeSpec)


class JacRuntime(JacRuntimeInterface):
    """Jac Machine State."""

    base_path_dir: str | None = os.getcwd()
    compiler: JacCompiler | None = None
    program: JacProgram | None = None
    pool: ThreadPoolExecutor = ThreadPoolExecutor()
    exec_ctx: ExecutionContext | None = None
    loaded_modules: dict[str, types.ModuleType] = {}

    @classmethod
    def get_compiler(cls) -> JacCompiler:
        """Get or create the JacCompiler singleton.

        The compiler is separate from the program and handles all compilation
        operations. It persists across program resets and can be reused.
        """
        if cls.compiler is None:
            from jaclang.pycore.compiler import JacCompiler

            cls.compiler = JacCompiler()
        return cls.compiler

    @classmethod
    def get_program(cls) -> JacProgram:
        """Get or create the JacProgram instance."""
        if cls.program is None:
            from jaclang.pycore.program import JacProgram

            cls.program = JacProgram()
        return cls.program

    @staticmethod
    def set_base_path(base_path: str | None) -> None:
        """Set the base path for the machine.

        When base_path is None, L3 persistence is disabled (faster for tests).
        """
        if base_path is None:
            JacRuntime.base_path_dir = None
        else:
            JacRuntime.base_path_dir = (
                base_path if os.path.isdir(base_path) else os.path.dirname(base_path)
            )

    @staticmethod
    def set_context(context: ExecutionContext) -> None:
        """Set the context for the machine."""
        JacRuntime.exec_ctx = context


@contextmanager
def without_plugins() -> Iterator[None]:
    """Context manager to temporarily disable external plugins.

    Useful for tests that need to run without plugin interference.
    Core JacRuntimeImpl is preserved, only external plugins are disabled.

    Usage:
        from jaclang.pycore.runtime import without_plugins

        def test_something():
            with without_plugins():
                # Test code runs without external plugins
                pass

        # Or as a pytest fixture:
        @pytest.fixture
        def no_plugins():
            with without_plugins():
                yield
    """
    # Store external plugins to restore later
    external_plugins: list[tuple[str, Any]] = []

    # Identify and unregister external plugins
    for name, plugin in list(plugin_manager.list_name_plugin()):
        # Keep JacRuntimeImpl (the core implementation)
        if plugin is JacRuntimeImpl or name == "JacRuntimeImpl":
            continue
        external_plugins.append((name, plugin))
        plugin_manager.unregister(plugin=plugin, name=name)

    try:
        yield
    finally:
        # Re-register all external plugins
        for name, plugin in external_plugins:
            with suppress(ValueError):
                plugin_manager.register(plugin, name=name)
