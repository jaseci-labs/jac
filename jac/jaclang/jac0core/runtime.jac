"""Jac Language Features."""
import fnmatch;
import html;
import inspect;
import json;
import os;
import sys;
import types;
import from collections { OrderedDict }
import from collections.abc { Callable, Coroutine, Iterator, Mapping, Sequence }
import from concurrent.futures { Future, ThreadPoolExecutor }
import from contextlib { contextmanager, suppress }
import from dataclasses { dataclass, field }
import from functools { wraps }
import from http.server { HTTPServer }
import from inspect { getfile }
import from logging { getLogger }
import from pathlib { Path }
import from typing {
    TYPE_CHECKING,
    Any,
    Literal,
    ParamSpec,
    TypeAlias,
    TypeVar,
    cast,
    get_type_hints
}
import from uuid { UUID }
import from jaclang.jac0core.archetype {
    GenericEdge,
    ObjectSpatialDestination,
    ObjectSpatialFunction,
    ObjectSpatialPath,
    Root
}
import from jaclang.jac0core.constant { EdgeDir, colors }
import from jaclang.jac0core.constructs {
    AccessLevel,
    Anchor,
    Archetype,
    EdgeAnchor,
    EdgeArchetype,
    JsxElement,
    NodeAnchor,
    NodeArchetype,
    WalkerAnchor,
    WalkerArchetype
}
import from jaclang.jac0core.modresolver { infer_language }
import from jaclang.jac0core.mtp { MTIR, Info, MTRuntime }
import from jaclang.vendor { pluggy }

with entry {
    if TYPE_CHECKING {
        import from http.server { BaseHTTPRequestHandler }
        import from jaclang.cli.console { JacConsole as ConsoleImpl }
        import from jaclang.jac0core.compiler { JacCompiler }
        import from jaclang.jac0core.program { JacProgram }
        import from jaclang.runtimelib.client_bundle {
            ClientBundle,
            ClientBundleBuilder
        }
        import from jaclang.runtimelib.context { ExecutionContext }
        import from jaclang.runtimelib.server { JacAPIServer as JacServer }
        import from jaclang.runtimelib.server { ModuleIntrospector, UserManager }
    }
}

glob plugin_manager = pluggy.PluginManager('jac'),
     hookspec = pluggy.HookspecMarker('jac'),
     hookimpl = pluggy.HookimplMarker('jac'),
     logger = getLogger(__name__),
     T = TypeVar('T'),
     P = ParamSpec('P'),
     JsonValue: TypeAlias = None | str | int | float | bool | `list['JsonValue'] | `dict[
         (str, 'JsonValue')
     ],
     StatusCode: TypeAlias = Literal[(200, 201, 400, 401, 404, 500, 503)];

"""Jac Access Validation Specs."""
class JacAccessValidation {
    """Allow all access from target root graph to current Archetype."""
    static def allow_root(
        archetype: Archetype,
        root_id: UUID,
        level: (AccessLevel | int | str | None) = None
    ) -> None {
        if (level is None) {
            level = AccessLevel.READ;
        }
        level = AccessLevel.cast(level);
        anchor = archetype.__jac__;
        jctx = JacRuntimeInterface.get_context();
        mem_anchor = jctx.mem.get(anchor.id);
        if (mem_anchor and (mem_anchor is not anchor)) {
            anchor = mem_anchor;
        }
        access = anchor.access.roots;
        _root_id = str(root_id);
        if (level != access.anchors.get(_root_id, AccessLevel.NO_ACCESS)) {
            access.anchors[_root_id] = level;
            jctx.mem.put(anchor);
        }
    }

    """Disallow all access from target root graph to current Archetype."""
    static def disallow_root(
        archetype: Archetype,
        root_id: UUID,
        level: (AccessLevel | int | str | None) = None
    ) -> None {
        if (level is None) {
            level = AccessLevel.READ;
        }
        level = AccessLevel.cast(level);
        anchor = archetype.__jac__;
        jctx = JacRuntimeInterface.get_context();
        mem_anchor = jctx.mem.get(anchor.id);
        if (mem_anchor and (mem_anchor is not anchor)) {
            anchor = mem_anchor;
        }
        access = anchor.access.roots;
        access.anchors.pop(str(root_id), None);
        jctx.mem.put(anchor);
    }

    """Allow everyone to access current Archetype."""
    static def perm_grant(
        archetype: Archetype, level: (AccessLevel | int | str | None) = None
    ) -> None {
        if (level is None) {
            level = AccessLevel.READ;
        }
        level = AccessLevel.cast(level);
        anchor = archetype.__jac__;
        jctx = JacRuntimeInterface.get_context();
        mem_anchor = jctx.mem.get(anchor.id);
        if (mem_anchor and (mem_anchor is not anchor)) {
            anchor = mem_anchor;
        }
        if (level != anchor.access.all) {
            anchor.access.all = level;
            jctx.mem.put(anchor);
        }
    }

    """Disallow others to access current Archetype."""
    static def perm_revoke(archetype: Archetype) -> None {
        anchor = archetype.__jac__;
        jctx = JacRuntimeInterface.get_context();
        mem_anchor = jctx.mem.get(anchor.id);
        if (mem_anchor and (mem_anchor is not anchor)) {
            anchor = mem_anchor;
        }
        if (anchor.access.all > AccessLevel.NO_ACCESS) {
            anchor.access.all = AccessLevel.NO_ACCESS;
            jctx.mem.put(anchor);
        }
    }

    """Read Access Validation."""
    static def check_read_access(`to: Anchor) -> bool {
        raw_level = JacRuntimeInterface.check_access_level(`to);
        access_level = raw_level > AccessLevel.NO_ACCESS;
        if not access_level {
            logger.info(
                "Current root doesn't have read access to " + `to.__class__.__name__ + " " + `to.archetype.__class__.__name__ + "[" + str(
                    `to.id
                ) + "]"
            );
        }
        return access_level;
    }

    """Write Access Validation."""
    static def check_connect_access(`to: Anchor) -> bool {
        if not (
            access_level := (
                JacRuntimeInterface.check_access_level(`to) > AccessLevel.READ
            )
        ) {
            logger.info(
                "Current root doesn't have connect access to " + `to.__class__.__name__ + " " + `to.archetype.__class__.__name__ + "[" + str(
                    `to.id
                ) + "]"
            );
        }
        return access_level;
    }

    """Write Access Validation."""
    static def check_write_access(`to: Anchor) -> bool {
        if not (
            access_level := (
                JacRuntimeInterface.check_access_level(`to) > AccessLevel.CONNECT
            )
        ) {
            logger.info(
                "Current root doesn't have write access to " + `to.__class__.__name__ + " " + `to.archetype.__class__.__name__ + "[" + str(
                    `to.id
                ) + "]"
            );
        }
        return access_level;
    }

    """Access validation."""
    static def check_access_level(`to: Anchor, no_custom: bool = False) -> AccessLevel {
        if (not `to.persistent or (`to.hash == 0)) {
            return AccessLevel.WRITE;
        }
        jctx = JacRuntimeInterface.get_context();
        jroot = jctx.user_root;
        if ((jroot == jctx.system_root) or (jroot.id == `to.root) or (jroot == `to)) {
            return AccessLevel.WRITE;
        }
        if (
            not no_custom
            and ((custom_level := `to.archetype.__jac_access__()) is not None)
        ) {
            return AccessLevel.cast(custom_level);
        }
        access_level = AccessLevel.NO_ACCESS;
        if ((to_access := `to.access).all > AccessLevel.NO_ACCESS) {
            access_level = to_access.all;
        }
        if (`to.root and isinstance((to_root := jctx.mem.get(`to.root)), Anchor)) {
            if (to_root.access.all > access_level) {
                access_level = to_root.access.all;
            }
            if ((level := to_root.access.roots.check(str(jroot.id))) is not None) {
                access_level = level;
            }
        }
        if ((level := to_access.roots.check(str(jroot.id))) is not None) {
            access_level = level;
        }
        return access_level;
    }
}

"""Jac Node Operations."""
class JacNode {
    """Get edges connected to this node."""
    static def get_edges(
        origin: list[NodeArchetype], destination: ObjectSpatialDestination
    ) -> list[EdgeArchetype] {
        edges: OrderedDict[(EdgeAnchor, EdgeArchetype)] = OrderedDict();
        for `node in origin {
            nanch = `node.__jac__;
            for anchor in nanch.edges {
                if (
                    (source := anchor.source)
                    and (target := anchor.target)
                    and destination.edge_filter(anchor.archetype)
                    and source.archetype
                    and target.archetype
                ) {
                    if (
                        (destination.direction in [EdgeDir.OUT, EdgeDir.ANY])
                        and (nanch == source)
                        and destination.node_filter(target.archetype)
                        and JacRuntimeInterface.check_read_access(target)
                    ) {
                        edges[anchor] = anchor.archetype;
                    }
                    if (
                        (destination.direction in [EdgeDir.IN, EdgeDir.ANY])
                        and (nanch == target)
                        and destination.node_filter(source.archetype)
                        and JacRuntimeInterface.check_read_access(source)
                    ) {
                        edges[anchor] = anchor.archetype;
                    }
                }
            }
        }
        return `list(edges.values());
    }

    """Get edges connected to this node and the node."""
    static def get_edges_with_node(
        origin: list[NodeArchetype],
        destination: ObjectSpatialDestination,
        from_visit: bool = False
    ) -> list[(EdgeArchetype | NodeArchetype)] {
        loc: OrderedDict[((NodeAnchor | EdgeAnchor), (NodeArchetype | EdgeArchetype))] = OrderedDict();
        for `node in origin {
            nanch = `node.__jac__;
            for anchor in nanch.edges {
                if (
                    (source := anchor.source)
                    and (target := anchor.target)
                    and destination.edge_filter(anchor.archetype)
                    and source.archetype
                    and target.archetype
                ) {
                    if (
                        (destination.direction in [EdgeDir.OUT, EdgeDir.ANY])
                        and (nanch == source)
                        and destination.node_filter(target.archetype)
                        and JacRuntimeInterface.check_read_access(target)
                    ) {
                        loc[anchor] = anchor.archetype;
                        loc[target] = target.archetype;
                    }
                    if (
                        (destination.direction in [EdgeDir.IN, EdgeDir.ANY])
                        and (nanch == target)
                        and destination.node_filter(source.archetype)
                        and JacRuntimeInterface.check_read_access(source)
                    ) {
                        loc[anchor] = anchor.archetype;
                        loc[source] = source.archetype;
                    }
                }
            }
        }
        return `list(loc.values());
    }

    """Get set of nodes connected to this node."""
    static def edges_to_nodes(
        origin: list[NodeArchetype], destination: ObjectSpatialDestination
    ) -> list[NodeArchetype] {
        nodes: OrderedDict[(NodeAnchor, NodeArchetype)] = OrderedDict();
        for `node in origin {
            nanch = `node.__jac__;
            for anchor in nanch.edges {
                if (
                    (source := anchor.source)
                    and (target := anchor.target)
                    and destination.edge_filter(anchor.archetype)
                    and source.archetype
                    and target.archetype
                ) {
                    if (
                        (destination.direction in [EdgeDir.OUT, EdgeDir.ANY])
                        and (nanch == source)
                        and destination.node_filter(target.archetype)
                        and JacRuntimeInterface.check_read_access(target)
                    ) {
                        nodes[target] = target.archetype;
                    }
                    if (
                        (destination.direction in [EdgeDir.IN, EdgeDir.ANY])
                        and (nanch == target)
                        and destination.node_filter(source.archetype)
                        and JacRuntimeInterface.check_read_access(source)
                    ) {
                        nodes[source] = source.archetype;
                    }
                }
            }
        }
        return `list(nodes.values());
    }

    """Remove reference without checking sync status."""
    static def remove_edge(`node: NodeAnchor, `edge: EdgeAnchor) -> None {
        for (idx, ed) in enumerate(`node.edges) {
            if (ed.id == `edge.id) {
                `node.edges.pop(idx);
                break;
            }
        }
    }
}

"""Jac Edge Operations."""
class JacEdge {
    """Detach edge from nodes."""
    static def detach(`edge: EdgeAnchor) -> None {
        JacRuntimeInterface.remove_edge(`node=`edge.source, `edge=`edge);
        JacRuntimeInterface.remove_edge(`node=`edge.target, `edge=`edge);
    }
}

"""Jac Edge Operations."""
class JacWalker {
    """Jac's visit stmt feature."""
    static def `visit(
        `walker: WalkerArchetype,
        expr:
            (
                list[(NodeArchetype | EdgeArchetype)] | list[NodeArchetype] | list[
                    EdgeArchetype
                ] | NodeArchetype | EdgeArchetype | ObjectSpatialPath
            ),
        insert_loc: int = -1
    ) -> bool {
        if isinstance(expr, ObjectSpatialPath) {
            expr.from_visit = True;
            expr = JacRuntimeInterface.refs(expr);
        }
        if isinstance(`walker, WalkerArchetype) {
            'Walker visits node.';
            wanch = `walker.__jac__;
            before_len = len(wanch.next);
            next = [];
            for anchor in (i.__jac__ for i in expr)
            if isinstance(expr, `list)
            else [expr.__jac__] {
                if (anchor not in wanch.ignores) {
                    if isinstance(anchor, (NodeAnchor, EdgeAnchor)) {
                        next.append(anchor);
                    } else {
                        raise ValueError('Anchor should be NodeAnchor or EdgeAnchor.') ;
                    }
                }
            }
            if (insert_loc < -len(wanch.next)) {
                insert_loc = 0;
            } elif (insert_loc < 0) {
                insert_loc += len(wanch.next) + 1;
            }
            wanch.next = wanch.next[:insert_loc] + next + wanch.next[insert_loc:];
            return (len(wanch.next) > before_len);
        } else {
            raise TypeError('Invalid walker object') ;
        }
    }

    """Execute all entry abilities for current location.

        Returns True if walker should continue, False if disengaged.
        """
    static def _execute_entries(
        warch: WalkerArchetype,
        `walker: WalkerAnchor,
        current_loc: (NodeArchetype | EdgeArchetype)
    ) -> bool {
        import from jaclang.runtimelib.utils { all_issubclass }
        for i in warch._jac_entry_funcs_ {
            if (
                i.trigger
                and (
                    all_issubclass(i.trigger, NodeArchetype)
                    or all_issubclass(i.trigger, EdgeArchetype)
                )
                and isinstance(current_loc, i.trigger)
            ) {
                i.func(warch, current_loc);
            }
            if `walker.disengaged {
                return False;
            }
        }
        for i in current_loc._jac_entry_funcs_ {
            if not i.trigger {
                i.func(current_loc, warch);
            }
            if `walker.disengaged {
                return False;
            }
        }
        for i in current_loc._jac_entry_funcs_ {
            if (
                i.trigger
                and all_issubclass(i.trigger, WalkerArchetype)
                and isinstance(warch, i.trigger)
            ) {
                i.func(current_loc, warch);
            }
            if `walker.disengaged {
                return False;
            }
        }
        return True;
    }

    """Execute all exit abilities for current location.

        Returns True if walker should continue, False if disengaged.
        """
    static def _execute_exits(
        warch: WalkerArchetype,
        `walker: WalkerAnchor,
        current_loc: (NodeArchetype | EdgeArchetype)
    ) -> bool {
        import from jaclang.runtimelib.utils { all_issubclass }
        for i in current_loc._jac_exit_funcs_ {
            if (
                i.trigger
                and all_issubclass(i.trigger, WalkerArchetype)
                and isinstance(warch, i.trigger)
            ) {
                i.func(current_loc, warch);
            }
            if `walker.disengaged {
                return False;
            }
        }
        for i in current_loc._jac_exit_funcs_ {
            if not i.trigger {
                i.func(current_loc, warch);
            }
            if `walker.disengaged {
                return False;
            }
        }
        for i in warch._jac_exit_funcs_ {
            if (
                i.trigger
                and (
                    all_issubclass(i.trigger, NodeArchetype)
                    or all_issubclass(i.trigger, EdgeArchetype)
                )
                and isinstance(current_loc, i.trigger)
            ) {
                i.func(warch, current_loc);
            }
            if `walker.disengaged {
                return False;
            }
        }
        return True;
    }

    """Recursively visit a node with DFS semantics.

        1. Execute entries for this node
        2. Recursively visit all children added during entry
        3. Execute exits for this node (post-order)

        Returns True if walker should continue, False if disengaged.
        """
    static def _visit_node_recursive(
        warch: WalkerArchetype,
        `walker: WalkerAnchor,
        anchor: (NodeAnchor | EdgeAnchor)
    ) -> bool {
        current_loc = anchor.archetype;
        if not current_loc {
            return True;
        }
        `walker.path.append(anchor);
        if not JacWalker._execute_entries(warch, `walker, current_loc) {
            return False;
        }
        while `walker.next {
            child_anchor = `walker.next.pop(0);
            if (
                (child_anchor not in `walker.ignores)
                and not JacWalker._visit_node_recursive(warch, `walker, child_anchor)
            ) {
                return False;
            }
        }
        return JacWalker._execute_exits(warch, `walker, current_loc);
    }

    """Jac's spawn operator feature with recursive DFS semantics.

        Entry abilities execute when entering a node, exit abilities execute
        after all descendants are visited (post-order/LIFO).
        """
    static def spawn_call(
        `walker: WalkerAnchor, `node: (NodeAnchor | EdgeAnchor)
    ) -> WalkerArchetype {
        warch = `walker.archetype;
        `walker.path = [];
        current_loc = `node.archetype;
        ctx = JacRuntimeInterface.get_context();
        call_state = ctx.call_state.get(None);
        for i in warch._jac_entry_funcs_ {
            if not i.trigger {
                i.func(warch, current_loc);
            }
            if `walker.disengaged {
                `walker.ignores = [];
                if call_state {
                    warch.reports = call_state.reports;
                }
                return warch;
            }
        }
        while `walker.next {
            next_anchor = `walker.next.pop(0);
            if (
                (next_anchor not in `walker.ignores)
                and not JacWalker._visit_node_recursive(warch, `walker, next_anchor)
            ) {
                break;
            }
        }
        if `walker.path {
            current_loc = `walker.path[-1].archetype;
        }
        for i in warch._jac_exit_funcs_ {
            if not i.trigger {
                i.func(warch, current_loc);
            }
            if `walker.disengaged {
                break;
            }
        }
        `walker.ignores = [];
        if call_state {
            warch.reports = call_state.reports;
        }
        return warch;
    }

    """Async version: Execute all entry abilities for current location.

        Returns True if walker should continue, False if disengaged.
        """
    async static def _async_execute_entries(
        warch: WalkerArchetype,
        `walker: WalkerAnchor,
        current_loc: (NodeArchetype | EdgeArchetype)
    ) -> bool {
        import from jaclang.runtimelib.utils { all_issubclass }
        for i in warch._jac_entry_funcs_ {
            if (
                i.trigger
                and (
                    all_issubclass(i.trigger, NodeArchetype)
                    or all_issubclass(i.trigger, EdgeArchetype)
                )
                and isinstance(current_loc, i.trigger)
            ) {
                result = i.func(warch, current_loc);
                if isinstance(result, Coroutine) {
                    await result;
                }
            }
            if `walker.disengaged {
                return False;
            }
        }
        for i in current_loc._jac_entry_funcs_ {
            if not i.trigger {
                result = i.func(current_loc, warch);
                if isinstance(result, Coroutine) {
                    await result;
                }
            }
            if `walker.disengaged {
                return False;
            }
        }
        for i in current_loc._jac_entry_funcs_ {
            if (
                i.trigger
                and all_issubclass(i.trigger, WalkerArchetype)
                and isinstance(warch, i.trigger)
            ) {
                result = i.func(current_loc, warch);
                if isinstance(result, Coroutine) {
                    await result;
                }
            }
            if `walker.disengaged {
                return False;
            }
        }
        return True;
    }

    """Async version: Execute all exit abilities for current location.

        Returns True if walker should continue, False if disengaged.
        """
    async static def _async_execute_exits(
        warch: WalkerArchetype,
        `walker: WalkerAnchor,
        current_loc: (NodeArchetype | EdgeArchetype)
    ) -> bool {
        import from jaclang.runtimelib.utils { all_issubclass }
        for i in current_loc._jac_exit_funcs_ {
            if (
                i.trigger
                and all_issubclass(i.trigger, WalkerArchetype)
                and isinstance(warch, i.trigger)
            ) {
                result = i.func(current_loc, warch);
                if isinstance(result, Coroutine) {
                    await result;
                }
            }
            if `walker.disengaged {
                return False;
            }
        }
        for i in current_loc._jac_exit_funcs_ {
            if not i.trigger {
                result = i.func(current_loc, warch);
                if isinstance(result, Coroutine) {
                    await result;
                }
            }
            if `walker.disengaged {
                return False;
            }
        }
        for i in warch._jac_exit_funcs_ {
            if (
                i.trigger
                and (
                    all_issubclass(i.trigger, NodeArchetype)
                    or all_issubclass(i.trigger, EdgeArchetype)
                )
                and isinstance(current_loc, i.trigger)
            ) {
                result = i.func(warch, current_loc);
                if isinstance(result, Coroutine) {
                    await result;
                }
            }
            if `walker.disengaged {
                return False;
            }
        }
        return True;
    }

    """Async version: Recursively visit a node with DFS semantics.

        1. Execute entries for this node
        2. Recursively visit all children added during entry
        3. Execute exits for this node (post-order)

        Returns True if walker should continue, False if disengaged.
        """
    async static def _async_visit_node_recursive(
        warch: WalkerArchetype,
        `walker: WalkerAnchor,
        anchor: (NodeAnchor | EdgeAnchor)
    ) -> bool {
        current_loc = anchor.archetype;
        if not current_loc {
            return True;
        }
        `walker.path.append(anchor);
        if not await JacWalker._async_execute_entries(warch, `walker, current_loc) {
            return False;
        }
        while `walker.next {
            child_anchor = `walker.next.pop(0);
            if (
                (child_anchor not in `walker.ignores)
                and not await JacWalker._async_visit_node_recursive(
                    warch, `walker, child_anchor
                )
            ) {
                return False;
            }
        }
        return await JacWalker._async_execute_exits(warch, `walker, current_loc);
    }

    """Jac's async spawn operator feature with recursive DFS semantics.

        Entry abilities execute when entering a node, exit abilities execute
        after all descendants are visited (post-order/LIFO).
        """
    async static def async_spawn_call(
        `walker: WalkerAnchor, `node: (NodeAnchor | EdgeAnchor)
    ) -> WalkerArchetype {
        warch = `walker.archetype;
        `walker.path = [];
        current_loc = `node.archetype;
        ctx = JacRuntimeInterface.get_context();
        call_state = ctx.call_state.get(None);
        for i in warch._jac_entry_funcs_ {
            if not i.trigger {
                result = i.func(warch, current_loc);
                if isinstance(result, Coroutine) {
                    await result;
                }
            }
            if `walker.disengaged {
                `walker.ignores = [];
                if call_state {
                    warch.reports = call_state.reports;
                }
                return warch;
            }
        }
        while `walker.next {
            next_anchor = `walker.next.pop(0);
            if (
                (next_anchor not in `walker.ignores)
                and not await JacWalker._async_visit_node_recursive(
                    warch, `walker, next_anchor
                )
            ) {
                break;
            }
        }
        if `walker.path {
            current_loc = `walker.path[-1].archetype;
        }
        for i in warch._jac_exit_funcs_ {
            if not i.trigger {
                result = i.func(warch, current_loc);
                if isinstance(result, Coroutine) {
                    await result;
                }
            }
            if `walker.disengaged {
                break;
            }
        }
        `walker.ignores = [];
        if call_state {
            warch.reports = call_state.reports;
        }
        return warch;
    }

    """Jac's spawn operator feature."""
    static def `spawn(
        op1: (Archetype | list[Archetype]), op2: (Archetype | list[Archetype])
    ) -> (WalkerArchetype | Coroutine) {
        def collect_targets(
            `walker: WalkerAnchor, items: list[Archetype]
        ) -> (NodeAnchor | EdgeAnchor) {
            for i in items {
                a = i.__jac__;
                `walker.next.append(a)
                if isinstance(a, (NodeAnchor, EdgeAnchor))
                else None;
                if (isinstance(a, EdgeAnchor) and a.target) {
                    `walker.next.append(a.target);
                }
            }
            return `walker.next[0];
        }
        def assign(
            `walker: WalkerAnchor, t: (Archetype | list[Archetype])
        ) -> (NodeAnchor | EdgeAnchor) {
            if isinstance(t, NodeArchetype) {
                `node = t.__jac__;
                `walker.next = [`node];
                return `node;
            } elif isinstance(t, EdgeArchetype) {
                `edge = t.__jac__;
                `walker.next = [`edge, `edge.target];
                return `edge;
            } elif (
                isinstance(t, `list)
                and all(isinstance(i, (NodeArchetype, EdgeArchetype)) for i in t)
            ) {
                return collect_targets(`walker, t);
            } else {
                raise TypeError('Invalid target object') ;
            }
        }
        if isinstance(op1, WalkerArchetype) {
            (warch, targ) = (op1, op2);
        } elif isinstance(op2, WalkerArchetype) {
            (warch, targ) = (op2, op1);
        } else {
            raise TypeError('Invalid walker object') ;
        }
        `walker: WalkerAnchor = warch.__jac__;
        loc: (NodeAnchor | EdgeAnchor) = assign(`walker, targ);
        if warch.__jac_async__ {
            return JacRuntimeInterface.async_spawn_call(`walker=`walker, `node=loc);
        }
        return JacRuntimeInterface.spawn_call(`walker=`walker, `node=loc);
    }

    """Jac's disengage stmt feature."""
    static def `disengage(`walker: WalkerArchetype) -> bool {
        `walker.__jac__.disengaged = True;
        return True;
    }
}

"""Default Classes References - direct class attributes (no lazy loading)."""
class JacClassReferences {
    with entry {
        TYPE_CHECKING: bool = TYPE_CHECKING;
        DSFunc = ObjectSpatialFunction;
        OPath = ObjectSpatialPath;
        Root = Root;
        GenericEdge = GenericEdge;
        Obj = Archetype;
        Node = NodeArchetype;
        Edge = EdgeArchetype;
        Walker = WalkerArchetype;
        JsxElement = JsxElement;
    }
}

"""Jac Builtins."""
class JacBuiltin {
    """Generate graph for visualizing nodes and edges."""
    static def printgraph(
        `node: NodeArchetype,
        depth: int,
        traverse: bool,
        edge_type: (list[str] | None),
        bfs: bool,
        edge_limit: int,
        node_limit: int,
        file: (str | None),
        format: str
    ) -> str {
        import from jaclang.runtimelib.utils { traverse_graph }
        edge_type = edge_type or [];
        visited_nodes: list[NodeArchetype] = [];
        node_depths: dict[(NodeArchetype, int)] = {`node: 0};
        queue: list = [[`node, 0]];
        connections: list[tuple[(NodeArchetype, NodeArchetype, EdgeArchetype)]] = [];
        """Depth first search.""";
        def dfs(`node: NodeArchetype, cur_depth: int) -> None {
            if (`node not in visited_nodes) {
                visited_nodes.append(`node);
                traverse_graph(
                    `node,
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
                    edge_limit
                );
            }
        }
        if bfs {
            cur_depth = 0;
            while queue {
                (current_node, cur_depth) = queue.pop(0);
                if (current_node not in visited_nodes) {
                    visited_nodes.append(current_node);
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
                        edge_limit
                    );
                }
            }
        } else {
            dfs(`node, cur_depth=0);
        }
        dot_content = 'digraph {\nnode [style="filled", shape="ellipse", fillcolor="invis", fontcolor="black"];\n';
        mermaid_content = 'flowchart LR\n';
        for (source, target, `edge) in connections {
            edge_label = html.escape(str(`edge.__jac__.archetype));
            dot_content += (
                f"{visited_nodes.index(source)} -> {visited_nodes.index(target)} " + f' [label="{edge_label
                if "GenericEdge" not in edge_label
                else ""}"];\n'
            );
            if (('GenericEdge' in edge_label) or not edge_label.strip()) {
                mermaid_content += (
                    f"{visited_nodes.index(source)} -->{visited_nodes.index(target)}\n"
                );
            } else {
                mermaid_content += (
                    f'{visited_nodes.index(source)} -->|"{edge_label}"| {visited_nodes.index(
                        target
                    )}\n'
                );
            }
        }
        for node_ in visited_nodes {
            color = colors[node_depths[node_]]
            if (node_depths[node_] < 25)
            else colors[24];
            label = html.escape(str(node_.__jac__.archetype));
            dot_content += (
                f'{visited_nodes.index(node_)} [label="{label}"fillcolor="{color}"];\n'
            );
            mermaid_content += f'{visited_nodes.index(node_)}["{label}"]\n';
        }
        output = (dot_content + '}') if (format == 'dot') else mermaid_content;
        if file {
            with open(file, 'w') as f {
                f.write(output);
            }
        }
        return output;
    }
}

"""Jac CLI command."""
class JacCmd {
    """Create Jac CLI cmds."""
    static def create_cmd -> None { }
}

"""Jac Feature."""
class JacBasics {
    """Set Class References."""
    static def setup -> None { }

    """Get current execution context."""
    static def get_context -> ExecutionContext {
        if (JacRuntime.exec_ctx is None) {
            JacRuntime.exec_ctx = JacRuntimeInterface.create_j_context(user_root=None);
        }
        return JacRuntime.exec_ctx;
    }

    """Commit all data from memory to datasource."""
    static def commit(anchor: Anchor | Archetype | None = None) -> None {
        if isinstance(anchor, Archetype) {
            anchor = anchor.__jac__;
        }
        ctx = JacRuntimeInterface.get_context();
        ctx.mem.commit(anchor);
    }

    """Purge current or target graph."""
    static def reset_graph(`root: (Root | None) = None) -> int {
        import pickle;
        import sqlite3;
        ctx = JacRuntimeInterface.get_context();
        mem = ctx.mem;
        ranchor = `root.__jac__ if `root else ctx.user_root;
        deleted_count = 0;
        deleted_ids: set[UUID] = `set();
        persistence = mem.l3;
        conn = getattr(persistence, '__conn__', None) if persistence else None;
        if (conn and isinstance(conn, sqlite3.Connection)) {
            cursor = conn.execute('SELECT data FROM anchors');
            anchors = [pickle.loads(row[0]) for row in cursor.fetchall()];
        } else {
            anchors = `list(mem.get_mem().values());
        }
        for anchor in anchors {
            if ((anchor == ranchor) or (anchor.root != ranchor.id)) {
                continue;
            }
            deleted_ids.add(anchor.id);
            mem.delete(anchor.id);
            deleted_count += 1;
        }
        ranchor.edges = [
            e
            for e in ranchor.edges
            if (e.id not in deleted_ids)
        ];
        mem.commit(ranchor);
        return deleted_count;
    }

    """Get object given id."""
    static def get_object(id: str) -> (Archetype | None) {
        if (id == 'root') {
            return JacRuntimeInterface.get_context().user_root.archetype;
        } elif (`obj := JacRuntimeInterface.get_context().mem.get(UUID(id))) {
            return `obj.archetype;
        }
        return None;
    }

    """Get object reference id."""
    static def object_ref(`obj: Archetype) -> str {
        return `obj.__jac__.id.hex;
    }

    """Create a obj archetype."""
    static def make_archetype(cls: type[Archetype]) -> type[Archetype] {
        entries: OrderedDict[(str, ObjectSpatialFunction)] = OrderedDict(
            (fn.name, fn) for fn in cls._jac_entry_funcs_
        );
        exits: OrderedDict[(str, ObjectSpatialFunction)] = OrderedDict(
            (fn.name, fn) for fn in cls._jac_exit_funcs_
        );
        for func in cls.__dict__.values() {
            if callable(func) {
                if func?.__jac_entry {
                    entries[func.__name__] = JacRuntimeInterface.DSFunc(
                        func.__name__, func
                    );
                }
                if func?.__jac_exit {
                    exits[func.__name__] = JacRuntimeInterface.DSFunc(
                        func.__name__, func
                    );
                }
            }
        }
        cls._jac_entry_funcs_ = [*entries.values()];
        cls._jac_exit_funcs_ = [*exits.values()];
        dataclass(eq=False)(cls);
        return cls;
    }

    """Update impl file location."""
    static def impl_patch_filename(
        file_loc: str
    ) -> Callable[([Callable[(P, T)]], Callable[(P, T)])] {
        def decorator(func: Callable[(P, T)]) -> Callable[(P, T)] {
            try {
                code = func.__code__;
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
                    code.co_cellvars
                );
                func.__code__ = new_code;
            } except AttributeError {
                ;
            }
            return func;
        }
        return decorator;
    }

    """Import a Jac or Python module using Python's standard import machinery.

        This function bridges Jac's import semantics with Python's import
system,
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
            (func, cls) = jac_import("mymod", "/path", items={"myfunc": None,
"MyClass": None})

            # Run as __main__
            jac_import("mymod", "/path", override_name="__main__")
        """
    static def jac_import(
        target: str,
        base_path: str,
        absorb: bool = False,
        override_name: (str | None) = None,
        items: (dict[(str, str | str | None)] | None) = None,
        reload_module: (bool | None) = False,
        lng: (str | None) = None
    ) -> tuple[(types.ModuleType, ...)] {
        import importlib;
        import importlib.util;
        if (lng is None) {
            lng = infer_language(target, base_path);
        }
        _ = JacRuntime.get_program();
        if target.startswith('.') {
            caller_dir = base_path
            if os.path.isdir(base_path)
            else os.path.dirname(base_path);
            chomp_target = target;
            while chomp_target.startswith('.') {
                if ((len(chomp_target) > 1) and (chomp_target[1] == '.')) {
                    caller_dir = os.path.dirname(caller_dir);
                    chomp_target = chomp_target[1:];
                } else {
                    chomp_target = chomp_target[1:];
                    break;
                }
            }
            module_name = chomp_target;
        } else {
            module_name = target;
        }
        caller_dir = base_path
        if os.path.isdir(base_path)
        else os.path.dirname(base_path);
        original_path = None;
        if (caller_dir and (caller_dir not in sys.path)) {
            original_path = sys.path.copy();
            sys.path.insert(0, caller_dir);
        }
        try {
            if (override_name == '__main__') {
                import from jaclang.meta_importer { JacMetaImporter }
                finder = JacMetaImporter();
                spec = finder.find_spec(module_name, None);
                if (
                    spec
                    and spec.origin
                    and spec.origin.endswith('.jac')
                    and (lng == 'py')
                ) {
                    spec = None;
                }
                if ((not spec or not spec.origin) and (lng == 'py')) {
                    file_path = os.path.join(caller_dir, f"{module_name}.py");
                    if os.path.isfile(file_path) {
                        spec_name = '__main__'
                        if (override_name == '__main__')
                        else module_name;
                        spec = importlib.util.spec_from_file_location(
                            spec_name, file_path
                        );
                    }
                }
                if (not spec or not spec.origin) {
                    raise ImportError(f"Cannot find module {module_name}") ;
                }
                if (('__main__' in sys.modules) and not reload_module) {
                    module = sys.modules['__main__'];
                    to_keep = {
                        k: v
                        for (k, v) in module.__dict__.items()
                        if k.startswith('__')
                    };
                    module.__dict__.update(to_keep);
                } else {
                    module = types.ModuleType('__main__');
                    sys.modules['__main__'] = module;
                }
                module.__file__ = spec.origin;
                module.__name__ = '__main__';
                module.__spec__ = spec;
                if spec.submodule_search_locations {
                    module.__path__ = spec.submodule_search_locations;
                }
                JacRuntimeInterface.load_module('__main__', module);
                if spec.loader {
                    spec.loader.exec_module(module);
                }
            } elif (reload_module and (module_name in sys.modules)) {
                module = importlib.reload(sys.modules[module_name]);
                JacRuntimeInterface.load_module(module_name, module, force=True);
            } else {
                module = importlib.import_module(module_name);
                if reload_module {
                    JacRuntimeInterface.load_module(module_name, module, force=True);
                }
            }
            if items {
                imported_items = [];
                for (item_name, _) in items.items() {
                    if hasattr(module, item_name) {
                        item = getattr(module, item_name);
                        imported_items.append(item);
                    } else {
                        raise ImportError(
                            f"Cannot import name '{item_name}' from '{module_name}'"
                        ) ;
                    }
                }
                return `tuple(imported_items) if not absorb else (module, );
            }
            return (module, );
        } finally {
            if (original_path is not None) {
                sys.path[:] = original_path;
            }
        }
    }

    """Create a test."""
    static def jac_test(test_fun: Callable) -> Callable {
        import from jaclang.runtimelib.test { JacTestCheck }
        file_path = getfile(test_fun);
        func_name = test_fun.__name__;
        def test_deco -> None {
            test_fun(JacTestCheck());
        }
        test_deco.__name__ = test_fun.__name__;
        JacTestCheck.add_test(file_path, func_name, test_deco);
        return test_deco;
    }

    """JSX interface for creating elements.

        Args:
            tag: Element tag (string for HTML elements, callable for components)
            attributes: Element attributes/props
            children: Child elements

        Returns:
            JSX element representation.
        """
    static def jsx(
        tag: object,
        attributes: (Mapping[(str, object)] | None) = None,
        children: (Sequence[object] | None) = None
    ) -> JsxElement {
        `props: dict[(str, object)] = `dict(attributes) if attributes else {};
        child_list = `list(children) if children else [];
        return JsxElement(tag=tag, `props=`props, children=child_list);
    }

    """Run the test suite in the specified .jac file."""
    static def run_test(
        filepath: str,
        func_name: (str | None) = None,
        filter: (str | None) = None,
        xit: bool = False,
        maxfail: (int | None) = None,
        directory: (str | None) = None,
        verbose: bool = False
    ) -> int {
        import from jaclang.runtimelib.test { JacTestCheck }
        test_file = False;
        ret_count = 0;
        if filepath {
            if filepath.endswith('.jac') {
                (base, mod_name) = os.path.split(filepath);
                base = base or './';
                mod_name = mod_name[:-4];
                if mod_name.endswith('.test') {
                    mod_name = mod_name[:-5];
                }
                JacTestCheck.reset();
                JacRuntimeInterface.jac_import(target=mod_name, base_path=base);
                JacTestCheck.run_test(
                    xit, maxfail, verbose, os.path.abspath(filepath), func_name
                );
                ret_count = JacTestCheck.failcount;
            } else {
                JacConsole.get_console().error('Not a .jac file.');
            }
        } else {
            directory = directory or os.getcwd();
        }
        if (filter or directory) {
            current_dir = directory or os.getcwd();
            for (root_dir, _, files) in os.walk(current_dir, topdown=True) {
                files = [
                    file
                    for file in files
                    if fnmatch.fnmatch(file, filter)
                ]
                if filter
                else files;
                files = [
                    file
                    for file in files
                    if not file.endswith(('.test.jac', '.impl.jac'))
                ];
                for file in files {
                    if file.endswith('.jac') {
                        test_file = True;
                        JacConsole.get_console().info(
                            f"\n\n\t\t* Inside {root_dir}/{file} *"
                        );
                        JacTestCheck.reset();
                        JacRuntimeInterface.jac_import(
                            target=file[:-4], base_path=root_dir
                        );
                        JacTestCheck.run_test(
                            xit, maxfail, verbose, os.path.abspath(file), func_name
                        );
                    }
                    if (JacTestCheck.breaker and (xit or maxfail)) {
                        break;
                    }
                }
                if (JacTestCheck.breaker and (xit or maxfail)) {
                    break;
                }
            }
            JacTestCheck.breaker = False;
            ret_count += JacTestCheck.failcount;
            JacTestCheck.failcount = 0;
            if not test_file {
                JacConsole.get_console().warning('No test files found.');
            }
        }
        return ret_count;
    }

    """Jac's field handler."""
    static def field(
        factory: (Callable[([], T)] | None) = None, `init: bool = True
    ) -> T {
        if factory {
            return field(default_factory=factory);
        }
        return field(`init=`init);
    }

    """Jac's report stmt feature."""
    static def log_report(expr: Any, custom: bool = False) -> None {
        ctx = JacRuntimeInterface.get_context();
        if custom {
            ctx.custom = expr;
        } else {
            JacConsole.get_console().print(expr);
            call_state = ctx.call_state.get(None);
            if call_state {
                call_state.reports.put_nowait(expr);
            }
        }
    }

    """Jac's apply_dir stmt feature."""
    static def refs(
        path: ObjectSpatialPath | NodeArchetype | list[NodeArchetype]
    ) -> list[NodeArchetype] | list[EdgeArchetype] | list[
        (NodeArchetype | EdgeArchetype)
    ] {
        if not isinstance(path, ObjectSpatialPath) {
            path = ObjectSpatialPath(path, [ObjectSpatialDestination(EdgeDir.OUT)]);
        }
        origin = path.origin;
        destinations = path.destinations[:-1] if path.edge_only else path.destinations;
        while destinations {
            dest = path.destinations.pop(0);
            origin = JacRuntimeInterface.edges_to_nodes(origin, dest);
        }
        if path.edge_only {
            if path.from_visit {
                return JacRuntimeInterface.get_edges_with_node(
                    origin, path.destinations[-1]
                );
            }
            return JacRuntimeInterface.get_edges(origin, path.destinations[-1]);
        }
        return origin;
    }

    """Jac's apply_dir stmt feature."""
    async static def arefs(
        path: ObjectSpatialPath | NodeArchetype | list[NodeArchetype]
    ) -> None {
        ;
    }

    """Jac's filter archetype list."""
    static def filter_on(
        items: list[Archetype], func: Callable[([Archetype], bool)]
    ) -> list[Archetype] {
        return [
            item
            for item in items
            if func(item)
        ];
    }

    """Jac's connect operator feature."""
    static def connect(
        left: (NodeArchetype | list[NodeArchetype]),
        right: (NodeArchetype | list[NodeArchetype]),
        `edge: type[EdgeArchetype] | EdgeArchetype | None = None,
        undir: bool = False,
        conn_assign: (tuple[(tuple, tuple)] | None) = None,
        edges_only: bool = False
    ) -> (list[NodeArchetype] | list[EdgeArchetype]) {
        left = [left] if isinstance(left, NodeArchetype) else left;
        right = [right] if isinstance(right, NodeArchetype) else right;
        edges = [];
        for i in left {
            _left = i.__jac__;
            if JacRuntimeInterface.check_connect_access(_left) {
                for j in right {
                    _right = j.__jac__;
                    if JacRuntimeInterface.check_connect_access(_right) {
                        edges.append(
                            JacRuntimeInterface.build_edge(
                                is_undirected=undir,
                                conn_type=`edge,
                                conn_assign=conn_assign
                            )(
                                _left, _right
                            )
                        );
                    }
                }
            }
        }
        return right if not edges_only else edges;
    }

    """Jac's disconnect operator feature."""
    static def disconnect(
        left: (NodeArchetype | list[NodeArchetype]),
        right: (NodeArchetype | list[NodeArchetype]),
        dir: EdgeDir = EdgeDir.OUT,
        filter: (Callable[([EdgeArchetype], bool)] | None) = None
    ) -> bool {
        disconnect_occurred = False;
        left = [left] if isinstance(left, NodeArchetype) else left;
        right = [right] if isinstance(right, NodeArchetype) else right;
        for i in left {
            `node = i.__jac__;
            for anchor in `set(`node.edges) {
                if (
                    (source := anchor.source)
                    and (target := anchor.target)
                    and (not filter or filter(anchor.archetype))
                    and source.archetype
                    and target.archetype
                ) {
                    if (
                        (dir in [EdgeDir.OUT, EdgeDir.ANY])
                        and (`node == source)
                        and (target.archetype in right)
                        and JacRuntimeInterface.check_connect_access(target)
                    ) {
                        JacRuntimeInterface.destroy([anchor])
                        if anchor.persistent
                        else JacRuntimeInterface.detach(anchor);
                        disconnect_occurred = True;
                    }
                    if (
                        (dir in [EdgeDir.IN, EdgeDir.ANY])
                        and (`node == target)
                        and (source.archetype in right)
                        and JacRuntimeInterface.check_connect_access(source)
                    ) {
                        JacRuntimeInterface.destroy([anchor])
                        if anchor.persistent
                        else JacRuntimeInterface.detach(anchor);
                        disconnect_occurred = True;
                    }
                }
            }
        }
        return disconnect_occurred;
    }

    """Jac's assign comprehension feature."""
    static def assign_all(
        target: list[T], attr_val: tuple[(tuple[str], tuple[Any])]
    ) -> list[T] {
        for `obj in target {
            (attrs, values) = attr_val;
            for (attr, value) in zip(attrs, values, strict=False) {
                setattr(`obj, attr, value);
            }
        }
        return target;
    }

    """Jac's safe subscript feature."""
    static def safe_subscript(`obj: Any, key: Any) -> Any {
        try {
            return `obj[key];
        } except (KeyError, IndexError, TypeError) {
            return None;
        }
    }

    """Jac's root getter."""
    static def `root -> Root {
        return JacRuntime.get_context().get_root();
    }

    """Get all the roots."""
    static def get_all_root -> list[Root] {
        jmem = JacRuntimeInterface.get_context().mem;
        return `list(jmem.get_roots());
    }

    """Jac's root getter."""
    static def build_edge(
        is_undirected: bool,
        conn_type: type[EdgeArchetype] | EdgeArchetype | None,
        conn_assign: (tuple[(tuple, tuple)] | None)
    ) -> Callable[([NodeAnchor, NodeAnchor], EdgeArchetype)] {
        ct = conn_type or GenericEdge;
        def builder(source: NodeAnchor, target: NodeAnchor) -> EdgeArchetype {
            `edge = ct() if isinstance(ct, `type) else ct;
            eanch = `edge.__jac__=EdgeAnchor(
                archetype=`edge,
                source=source,
                target=target,
                is_undirected=is_undirected
            );
            source.edges.append(eanch);
            target.edges.append(eanch);
            if conn_assign {
                for (fld, val) in zip(conn_assign[0], conn_assign[1], strict=False) {
                    if hasattr(`edge, fld) {
                        setattr(`edge, fld, val);
                    } else {
                        raise ValueError(f"Invalid attribute: {fld}") ;
                    }
                }
            }
            if (source.persistent or target.persistent) {
                JacRuntimeInterface.save(eanch);
            }
            return `edge;
        }
        return builder;
    }

    """Destroy object."""
    static def save(`obj: (Archetype | Anchor)) -> None {
        anchor = `obj.__jac__ if isinstance(`obj, Archetype) else `obj;
        jctx = JacRuntimeInterface.get_context();
        if (not anchor.persistent and not anchor.root) {
            anchor.persistent = True;
            anchor.root = jctx.user_root.id;
        }
        jctx.mem.put(anchor);
        match anchor {
            case NodeAnchor():
                for ed in anchor.edges {
                    if (ed.is_populated() and not ed.persistent) {
                        JacRuntimeInterface.save(ed);
                    }
                }

            case EdgeAnchor():
                if (
                    (src := anchor.source)
                    and src.is_populated()
                    and not src.persistent
                ) {
                    JacRuntimeInterface.save(src);
                }
                if (
                    (trg := anchor.target)
                    and trg.is_populated()
                    and not trg.persistent
                ) {
                    JacRuntimeInterface.save(trg);
                }

            case _:
                ;

        }
    }

    """Destroy multiple objects passed in a tuple or list."""
    static def destroy(objs: Archetype | Anchor | list[(Archetype | Anchor)]) -> None {
        obj_list = objs if isinstance(objs, `list) else [objs];
        for `obj in obj_list {
            if not isinstance(`obj, (Archetype, Anchor)) {
                return;
            }
            anchor = `obj.__jac__ if isinstance(`obj, Archetype) else `obj;
            if JacRuntimeInterface.check_write_access(anchor) {
                match anchor {
                    case NodeAnchor():
                        for `edge in anchor.edges[:] {
                            JacRuntimeInterface.destroy([`edge]);
                        }

                    case EdgeAnchor():
                        JacRuntimeInterface.detach(anchor);

                    case _:
                        ;

                }
                JacRuntimeInterface.get_context().mem.delete(anchor.id);
            }
        }
    }

    """Mark a method as jac entry with this decorator."""
    static def on_entry(func: Callable) -> Callable {
        setattr(func, '__jac_entry', True);
        return func;
    }

    """Mark a method as jac exit with this decorator."""
    static def on_exit(func: Callable) -> Callable {
        setattr(func, '__jac_exit', True);
        return func;
    }
}

"""Jac Client Bundle Operations - Generic interface for client bundling."""
class JacClientBundle {
    """Get the client bundle builder instance."""
    static def get_client_bundle_builder -> ClientBundleBuilder {
        import from jaclang.runtimelib.client_bundle { ClientBundleBuilder }
        return ClientBundleBuilder();
    }

    """Build a client bundle for the supplied module."""
    static def build_client_bundle(
        module: types.ModuleType, force: bool = False
    ) -> ClientBundle {
        builder = JacRuntimeInterface.get_client_bundle_builder();
        return builder.build(module, force=force);
    }
}

"""Jac Console Operations - Generic interface for console output."""
class JacConsole {
    """Get the console instance to use for CLI output.

        Plugins can override this hook to provide their own console
implementation.
        The returned instance should be compatible with the JacConsole
interface.
        """
    static def get_console -> ConsoleImpl {
        import from jaclang.cli.console { JacConsole }
        return JacConsole();
    }
}

"""Jac API Server Operations - Generic interface for API server."""
class JacAPIServer {
    """Get the JacAPIServer class to use for serve command.

        Plugins can override this hook to provide their own server class.
        The returned class should be compatible with the JacAPIServer interface.
        """
    static def get_api_server_class -> type {
        import from jaclang.runtimelib.server { JacAPIServer }
        return JacAPIServer;
    }

    """Create the API server instance."""
    static def create_server(jac_server: JacServer, host: str, port: int) -> HTTPServer {
        handler_class = jac_server.create_handler();
        return HTTPServer((host, port), handler_class);
    }

    """Render HTML page for client function."""
    static def render_page(
        introspector: ModuleIntrospector,
        function_name: str,
        args: dict[(str, Any)],
        username: str
    ) -> dict[(str, Any)] {
        import from jaclang.runtimelib.server { JacSerializer }
        introspector.load();
        available_exports = (
            `set(introspector._client_manifest.get('exports', []))
            or `set(introspector.get_client_functions().keys())
        );
        if (function_name not in available_exports) {
            raise ValueError(f"Client function '{function_name}' not found") ;
        }
        bundle_hash = introspector.ensure_bundle();
        arg_order = `list(
            introspector._client_manifest.get('params', {}).get(function_name, [])
        );
        globals_payload = {
            name: JacSerializer.serialize(value)
            for (name, value) in introspector._collect_client_globals().items()
        };
        initial_state = {
            'module': introspector._module.__name__
            if introspector._module
            else introspector.module_name,
            'function': function_name,
            'args': {
                key: JacSerializer.serialize(value) for (key, value) in args.items()
            },
            'globals': globals_payload,
            'argOrder': arg_order
        };
        safe_initial_json = json.dumps(initial_state).replace('</', '<\\/');
        page = f'<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"/><title>{html.escape(
            function_name
        )}</title></head><body><div id="__jac_root"></div><script id="__jac_init__" type="application/json">{safe_initial_json}</script><script type="module" src="/static/client.js?hash={bundle_hash}"></script></body></html>';
        return {
            'html': page,
            'bundle_hash': bundle_hash,
            'bundle_code': introspector._bundle.code
        };
    }

    """Get the client JavaScript bundle code.

        Plugins can override this hook to provide custom bundle serving logic
        (e.g., serving Vite-built PWA bundles).
    """
    static def get_client_js(introspector: ModuleIntrospector) -> str {
        introspector.load();
        introspector.ensure_bundle();
        return introspector._bundle.code;
    }
}

"""Jac Response Builder."""
class JacResponseBuilder {
    """Send JSON response."""
    static def send_json(
        handler: BaseHTTPRequestHandler,
        status: StatusCode,
        data: dict[(str, JsonValue)]
    ) -> None {
        import from jaclang.runtimelib.server { ResponseBuilder }
        ResponseBuilder.send_json(handler, status, data);
    }

    """Send HTML response with CORS headers."""
    static def send_html(
        handler: BaseHTTPRequestHandler, status: StatusCode, body: str
    ) -> None {
        import from jaclang.runtimelib.server { ResponseBuilder }
        ResponseBuilder.send_html(handler, status, body);
    }

    """Send JavaScript response."""
    static def send_javascript(handler: BaseHTTPRequestHandler, code: str) -> None {
        import from jaclang.runtimelib.server { ResponseBuilder }
        ResponseBuilder.send_javascript(handler, code);
    }

    """Send CSS response."""
    static def send_css(handler: BaseHTTPRequestHandler, css_code: str) -> None {
        import from jaclang.runtimelib.server { ResponseBuilder }
        ResponseBuilder.send_css(handler, css_code);
    }

    """Send static file response (images, fonts, etc.)."""
    static def send_static_file(
        handler: BaseHTTPRequestHandler,
        file_path: Path,
        content_type: (str | None) = None
    ) -> None {
        raise NotImplementedError('send_static_file method is not implemented') ;
    }
}

"""Jac byLLM integration."""
class JacByLLM {
    """Get byLLM library."""
    static def get_mtir(
        caller: Callable,
        args: dict[((int | str), object)],
        call_params: dict[(str, object)]
    ) -> MTRuntime {
        return MTIR(caller=caller, args=args, call_params=call_params).runtime;
    }

    """Attach the semstring to the given object."""
    static def `sem(semstr: str, inner_semstr: dict[(str, str)]) -> Callable {
        def decorator(`obj: object) -> object {
            setattr(`obj, '_jac_semstr', semstr);
            setattr(`obj, '_jac_semstr_inner', inner_semstr);
            return `obj;
        }
        return decorator;
    }

    """Call the LLM model."""
    static def call_llm(model: object, mt_run: MTRuntime) -> Any {
        import from jaclang.utils { NonGPT }
        try {
            random_value_for_type = cast(
                Callable[([Any], Any)], NonGPT.random_value_for_type
            );
        } except AttributeError {
            def random_value_for_type(_t: object) -> object {
                return None;
            }
        }
        try {
            type_hints = get_type_hints(
                mt_run.caller,
                globalns=getattr(mt_run.caller, '__globals__', {}),
                localns=None,
                include_extras=True
            );
        } except Exception {
            type_hints = getattr(mt_run.caller, '__annotations__', {});
        }
        return_type = type_hints.get('return', Any);
        return random_value_for_type(return_type);
    }

    """Python library mode decorator for Jac's by llm() syntax."""
    static def `by(model: object) -> Callable {
        def _decorator(caller: Callable) -> Callable {
            def _wrapped_caller(*args: object, **kwargs: object) -> object {
                invoke_args: dict[((int | str), object)] = {};
                for (i, arg) in enumerate(args) {
                    invoke_args[i] = arg;
                }
                for (key, value) in kwargs.items() {
                    invoke_args[key] = value;
                }
                mt_run = JacRuntime.get_mtir(
                    caller=caller,
                    args=invoke_args,
                    call_params=model?.call_params or {}
                );
                return JacRuntime.call_llm(model, mt_run);
            }
            return _wrapped_caller;
        }
        return _decorator;
    }

    static def filter_visitable_by(
        connected_nodes: list[NodeArchetype], model: object, descriptions: str = ''
    ) -> list[NodeArchetype] {
        import from jaclang.jac0core.helpers { _describe_nodes_list }
        visitable_list: list = [];
        """
            Determine which connected nodes are visitable using an LLM.

            The input represents structurally reachable nodes. This function
applies
            semantic reasoning to decide which of those nodes a walker is
allowed
            or intended to visit, returning their indexes in priority order.

            Returns an empty list if no nodes are deemed visitable.
            """;
        @JacByLLM.by(model=model)
        def _filter_visitable_by(
            connected_nodes: list[NodeArchetype], descriptions: str = ''
        ) -> list[int] {
            return [];
        }
        descriptions = _describe_nodes_list(connected_nodes);
        indexes = _filter_visitable_by(connected_nodes, descriptions);
        for idx in indexes {
            visitable_list.append(connected_nodes[idx]);
        }
        return visitable_list;
    }

    """by operator feature for expression composition.

        Currently not implemented - raises NotImplementedError.
        Plugins like byllm can override this via the plugin hook system.
        """
    static def by_operator(lhs: Any, rhs: Any) -> Any {
        raise NotImplementedError(
            "The 'by' operator is not yet implemented. This feature is reserved for future use."
        ) ;
    }

    """Add MTIR to the node's MTIR map."""
    static def add_mtir_to_map(scope: str, mtir: Info) -> None {
        if (JacRuntime.program is None) {
            raise AttributeError('JacRuntime.program is not initialized') ;
        }
        JacRuntime.program.mtir_map[scope] = mtir;
    }

    """Get MTIR from the node's MTIR map."""
    static def get_mtir_from_map(scope: str) -> (Info | None) {
        if (JacRuntime.program is None) {
            raise AttributeError('JacRuntime.program is not initialized') ;
        }
        if (scope not in JacRuntime.program.mtir_map) {
            raise KeyError(f"MTIR not found for scope {scope}") ;
        }
        return JacRuntime.program.mtir_map[scope];
    }
}

"""Jac Machine Utilities."""
class JacUtils {
    """Create a new execution context.

        Args:
            user_root: User root ID for permission boundary. Required parameter.
                       Pass None for CLI/system contexts (uses system_root).
                       Pass user's root ID for authenticated server requests.

        Storage backend is configured via plugins/environment, not per-context.
        For file backend: auto-generates path from JacRuntime.base_path_dir.
        For database backends (jac-scale): configured via environment variables.
        """
    static def create_j_context(user_root: (str | None)) -> ExecutionContext {
        import from jaclang.runtimelib.context { ExecutionContext }
        ctx = ExecutionContext();
        if (user_root is not None) {
            ctx.set_user_root(user_root);
        }
        return ctx;
    }

    """Attach a JacProgram to the machine."""
    static def attach_program(jac_program: JacProgram) -> None {
        JacRuntime.program = jac_program;
    }

    """Attach a JacCompiler to the machine."""
    static def attach_compiler(jac_compiler: JacCompiler) -> None {
        JacRuntime.compiler = jac_compiler;
    }

    """Load a module into the machine."""
    static def load_module(
        module_name: str, module: types.ModuleType, force: bool = False
    ) -> None {
        if ((module_name not in JacRuntime.loaded_modules) or force) {
            JacRuntime.loaded_modules[module_name] = module;
            sys.modules[module_name] = module;
        }
    }

    """List all loaded modules."""
    static def list_modules -> list[str] {
        return `list(JacRuntime.loaded_modules.keys());
    }

    """List all walkers in a specific module."""
    static def list_walkers(module_name: str) -> list[str] {
        module = JacRuntime.loaded_modules.get(module_name);
        if module {
            walkers = [];
            for (name, `obj) in inspect.getmembers(module) {
                if (
                    isinstance(`obj, `type)
                    and issubclass(`obj, WalkerArchetype)
                    and (`obj.__module__ == module_name)
                ) {
                    walkers.append(name);
                }
            }
            return walkers;
        }
        return [];
    }

    """List all nodes in a specific module."""
    static def list_nodes(module_name: str) -> list[str] {
        module = JacRuntime.loaded_modules.get(module_name);
        if module {
            nodes = [];
            for (name, `obj) in inspect.getmembers(module) {
                if (
                    isinstance(`obj, `type)
                    and issubclass(`obj, NodeArchetype)
                    and (`obj.__module__ == module_name)
                ) {
                    nodes.append(name);
                }
            }
            return nodes;
        }
        return [];
    }

    """List all edges in a specific module."""
    static def list_edges(module_name: str) -> list[str] {
        module = JacRuntime.loaded_modules.get(module_name);
        if module {
            edges = [];
            for (name, `obj) in inspect.getmembers(module) {
                if (
                    isinstance(`obj, `type)
                    and issubclass(`obj, EdgeArchetype)
                    and (`obj.__module__ == module_name)
                ) {
                    edges.append(name);
                }
            }
            return edges;
        }
        return [];
    }

    """Dynamically creates archetypes (nodes, walkers, etc.) from Jac source
code.

        This leverages Python's standard import machinery via jac_import(),
        which will automatically invoke JacMetaImporter.
        """
    static def create_archetype_from_source(
        source_code: str,
        module_name: (str | None) = None,
        base_path: (str | None) = None,
        cachable: bool = False,
        keep_temporary_files: bool = False
    ) -> (types.ModuleType | None) {
        if not base_path {
            base_path = JacRuntime.base_path_dir or os.getcwd();
        }
        if (base_path and not os.path.exists(base_path)) {
            os.makedirs(base_path);
        }
        if not module_name {
            module_name = f"_dynamic_module_{len(JacRuntime.loaded_modules)}";
        }
        import tempfile;
        with tempfile.NamedTemporaryFile(
            mode='w',
            suffix='.jac',
            prefix=(module_name + '_'),
            dir=base_path,
            delete=False
        ) as tmp_file {
            tmp_file_path = tmp_file.name;
            tmp_file.write(source_code);
        }
        try {
            tmp_file_basename = os.path.basename(tmp_file_path);
            (tmp_module_name, _) = os.path.splitext(tmp_file_basename);
            result = JacRuntimeInterface.jac_import(
                target=tmp_module_name,
                base_path=base_path,
                override_name=module_name,
                lng='jac'
            );
            module = result[0] if result else None;
            if module {
                JacRuntime.loaded_modules[module_name] = module;
            }
            return module;
        } except Exception as e {
            logger.error(f"Error importing dynamic module '{module_name}':{e}");
            return None;
        } finally {
            if (not keep_temporary_files and os.path.exists(tmp_file_path)) {
                os.remove(tmp_file_path);
            }
        }
    }

    """Reimport the module using Python's reload mechanism."""
    static def update_walker(
        module_name: str, items: (dict[(str, str | str | None)] | None)
    ) -> tuple[(types.ModuleType, ...)] {
        if (module_name in JacRuntime.loaded_modules) {
            try {
                old_module = JacRuntime.loaded_modules[module_name];
                result = JacRuntimeInterface.jac_import(
                    target=module_name,
                    base_path=(JacRuntime.base_path_dir or os.getcwd()),
                    items=items,
                    reload_module=True,
                    lng='jac'
                );
                if items {
                    ret_items = [];
                    for (idx, item_name) in enumerate(items.keys()) {
                        if (hasattr(old_module, item_name) and (idx < len(result))) {
                            new_attr = result[idx];
                            ret_items.append(new_attr);
                            setattr(old_module, item_name, new_attr);
                        }
                    }
                    return `tuple(ret_items);
                }
                return (old_module, );
            } except Exception as e {
                logger.error(f"Failed to update module {module_name}: {e}");
            }
        } else {
            logger.warning(f"Module {module_name} not found in loadedmodules.");
        }
        return ();
    }

    """Spawn a node instance of the given node_name with attributes."""
    static def spawn_node(
        node_name: str, attributes: (dict | None) = None, module_name: str = '__main__'
    ) -> NodeArchetype {
        node_class = JacRuntimeInterface.get_archetype(module_name, node_name);
        if (isinstance(node_class, `type) and issubclass(node_class, NodeArchetype)) {
            if (attributes is None) {
                attributes = {};
            }
            node_instance = node_class(**attributes);
            return node_instance;
        } else {
            raise ValueError(f"Node {node_name} not found.") ;
        }
    }

    """Spawn a walker instance of the given walker_name."""
    static def spawn_walker(
        walker_name: str,
        attributes: (dict | None) = None,
        module_name: str = '__main__'
    ) -> WalkerArchetype {
        walker_class = JacRuntimeInterface.get_archetype(module_name, walker_name);
        if (
            isinstance(walker_class, `type)
            and issubclass(walker_class, WalkerArchetype)
        ) {
            if (attributes is None) {
                attributes = {};
            }
            walker_instance = walker_class(**attributes);
            return walker_instance;
        } else {
            raise ValueError(f"Walker {walker_name} not found.") ;
        }
    }

    """Retrieve an archetype class from a module."""
    static def get_archetype(
        module_name: str, archetype_name: str
    ) -> (Archetype | None) {
        module = JacRuntime.loaded_modules.get(module_name);
        if module {
            return getattr(module, archetype_name, None);
        }
        return None;
    }

    """Run a function in a thread."""
    static def thread_run(func: Callable, *args: object) -> Future {
        _executor = JacRuntime.pool;
        return _executor.submit(func, *args);
    }

    """Wait for a thread to finish."""
    static def thread_wait(future: Any) -> None {
        return future.result();
    }
}

"""Plugin configuration hooks for jac.toml integration.

    Plugins can implement these hooks to register their configuration schemas
    and receive configuration values from jac.toml.
    """
class JacPluginConfig {
    """Return plugin metadata.

        Returns:
            dict with keys:
                - name: Plugin name (used in [plugins.<name>])
                - version: Plugin version
                - description: Brief description
        """
    static def get_plugin_metadata -> (dict[(str, Any)] | None) {
        return None;
    }

    """Return the plugin's configuration schema.

        Returns:
            dict with keys:
                - section: Section name in jac.toml (e.g., 'byllm' for
[plugins.byllm])
                - options: dict mapping option names to their specs:
                    {
                        'option_name': {
                            'type': 'str' | 'int' | 'float' | 'bool' | 'list' |
'dict',
                            'default': <default_value>,
                            'description': 'Description of the option',
                            'env_var': 'OPTIONAL_ENV_VAR_OVERRIDE',
                            'required': False,
                        }
                    }
        """
    static def get_config_schema -> (dict[(str, Any)] | None) {
        return None;
    }

    """Called when plugin configuration is loaded from jac.toml.

        Args:
            config: The plugin's configuration values from [plugins.<name>]
        """
    static def on_config_loaded(config: dict[(str, Any)]) -> None {
        ;
    }

    """Validate plugin configuration.

        Args:
            config: The plugin's configuration values

        Returns:
            List of error messages (empty if valid)
        """
    static def validate_config(config: dict[(str, Any)]) -> list[str] {
        return [];
    }

    """Register a custom dependency type.

        Allows plugins to extend [dependencies.*] sections in jac.toml.

        Returns:
            dict with keys:
                - name: Dependency type name (e.g., 'npm' for
[dependencies.npm])
                - dev_name: Dev dependency section (e.g., 'npm.dev')
                - cli_flag: CLI flag for 'jac add' (e.g., '--cl')
                - install_dir: Directory for installed deps (e.g., 'client')
                - install_handler: Callable to install packages
                - remove_handler: Callable to remove packages
        """
    static def register_dependency_type -> (dict[(str, Any)] | None) {
        return None;
    }

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
                - post_create: optional callable(project_path, project_name)
        """
    static def register_project_template -> (dict[(str, Any)] | None) {
        return None;
    }
}

"""Jac Feature."""
class JacRuntimeInterface(JacClassReferences, JacAccessValidation, JacNode, JacEdge, JacWalker, JacBuiltin, JacCmd, JacBasics, JacClientBundle, JacConsole, JacAPIServer, JacByLLM, JacResponseBuilder, JacUtils, JacPluginConfig) {
    """Get UserManager instance (hookable for plugins).

        Plugins can override this to provide custom UserManager implementations.
        Default returns core UserManager.

        Args:
            base_path: Base path for user data storage

        Returns:
            UserManager instance
        """
    static def get_user_manager(base_path: str) -> UserManager {
        import from jaclang.runtimelib.server { UserManager }
        return UserManager(base_path=base_path);
    }

    """Get storage backend instance (hookable for plugins).

        Default returns LocalStorage. Plugins (like jac-scale) can override
        to provide cloud storage backends with full config support.

        Args:
            base_path: Base directory for file storage.
            create_dirs: Whether to auto-create directories.

        Returns:
            Storage instance (LocalStorage by default)
        """
    static def store(base_path: str = './storage', create_dirs: bool = True) -> Any {
        import from jaclang.runtimelib.storage { LocalStorage }
        return LocalStorage(base_path=base_path, create_dirs=create_dirs);
    }
}

"""Generate three helper classes based on a plugin class.

    - Spec class: contains @hookspec placeholder methods.
    - Impl class: contains original plugin methods decorated with @hookimpl.
    - Proxy class: contains methods that call plugin_manager.hook.<method>.

    Returns:
        Tuple of (SpecClass, ImplClass, ProxyClass).
    """
def generate_plugin_helpers(
    plugin_class: type[Any]
) -> tuple[(type[Any], type[Any], type[Any])] {
    spec_methods = {};
    impl_methods = {};
    proxy_methods = {};
    for (name, method) in inspect.getmembers(
        plugin_class, predicate=inspect.isfunction
    ) {
        if name.startswith('_') {
            continue;
        }
        sig = inspect.signature(method);
        sig_nodef = sig.replace(
            parameters=[
                p.replace(`default=inspect.Parameter.empty)
                for p in sig.parameters.values()
            ]
        );
        doc = method.__doc__ or '';
        """Create a placeholder method for the spec class.""";
        def make_spec(
            name: str, sig_nodef: inspect.Signature, doc: str, method: Callable
        ) -> Callable {
            @wraps(method)
            def placeholder(*args: object, **kwargs: object) -> None {
                ;
            }
            placeholder.__name__ = name;
            placeholder.__doc__ = doc;
            placeholder.__signature__ = sig_nodef;
            return placeholder;
        }
        spec_methods[name] = hookspec(firstresult=True)(
            make_spec(name, sig_nodef, doc, method)
        );
        wrapped_impl = wraps(method)(method);
        wrapped_impl.__signature__ = sig_nodef;
        impl_methods[name] = hookimpl(wrapped_impl);
        class_vars: dict[(str, Any)] = {};
        annotations: dict[(str, Any)] = {};
        for base in reversed(plugin_class.__mro__) {
            if (base is object) {
                continue;
            }
            base_ann = getattr(base, '__annotations__', {});
            annotations.update(base_ann);
            for (key, value) in base.__dict__.items() {
                if key.startswith('__') {
                    continue;
                }
                if (callable(value) and not isinstance(value, `type)) {
                    continue;
                }
                class_vars[key] = value;
            }
        }
        """Create a proxy method for the proxy class.""";
        def make_proxy(name: str, sig: inspect.Signature) -> Callable {
            def proxy(*args: object, **kwargs: object) -> object {
                bound = sig.bind_partial(*args, **kwargs);
                bound.apply_defaults();
                hookcaller = getattr(plugin_manager.hook, name);
                return hookcaller(**bound.arguments);
            }
            proxy.__name__ = name;
            proxy.__signature__ = sig;
            return proxy;
        }
        proxy_methods[name] = make_proxy(name, sig);
    }
    spec_cls = `type(f"{plugin_class.__name__}Spec", (object, ), spec_methods);
    impl_cls = `type(f"{plugin_class.__name__}Impl", (object, ), impl_methods);
    proxy_namespace = {};
    proxy_namespace.update(class_vars);
    if annotations {
        proxy_namespace['__annotations__'] = annotations;
    }
    proxy_namespace.update(proxy_methods);
    original_metaclass: type = cast(`type, `type(plugin_class));
    proxy_cls = original_metaclass(
        f"{plugin_class.__name__}", (object, ), proxy_namespace
    );
    return (spec_cls, impl_cls, proxy_cls);
}

with entry {
    (JacRuntimeSpec, JacRuntimeImpl, JacRuntimeInterface) = generate_plugin_helpers(
        JacRuntimeInterface
    );
    plugin_manager.add_hookspecs(JacRuntimeSpec);
}

"""Jac Machine State."""
class JacRuntime(JacRuntimeInterface) {
    with entry {
        base_path_dir: (str | None) = os.getcwd();
        compiler: (JacCompiler | None) = None;
        program: (JacProgram | None) = None;
        pool: ThreadPoolExecutor = ThreadPoolExecutor();
        exec_ctx: (ExecutionContext | None) = None;
        loaded_modules: dict[(str, types.ModuleType)] = {};
    }

    """Get or create the JacCompiler singleton.

        The compiler is separate from the program and handles all compilation
        operations. It persists across program resets and can be reused.
        """
    @classmethod
    def get_compiler(cls: Any) -> JacCompiler {
        if (cls.compiler is None) {
            import from jaclang.jac0core.compiler { JacCompiler }
            cls.compiler = JacCompiler();
        }
        return cls.compiler;
    }

    """Get or create the JacProgram instance."""
    @classmethod
    def get_program(cls: Any) -> JacProgram {
        if (cls.program is None) {
            import from jaclang.jac0core.program { JacProgram }
            cls.program = JacProgram();
        }
        return cls.program;
    }

    """Set the base path for the machine.

        When base_path is None, L3 persistence is disabled (faster for tests).
        """
    static def set_base_path(base_path: (str | None)) -> None {
        if (base_path is None) {
            JacRuntime.base_path_dir = None;
        } else {
            JacRuntime.base_path_dir = base_path
            if os.path.isdir(base_path)
            else os.path.dirname(base_path);
        }
    }

    """Set the context for the machine."""
    static def set_context(context: ExecutionContext) -> None {
        JacRuntime.exec_ctx = context;
    }
}

"""Context manager to temporarily disable external plugins.

    Useful for tests that need to run without plugin interference.
    Core JacRuntimeImpl is preserved, only external plugins are disabled.

    Usage:
        from jaclang.jac0core.runtime import without_plugins

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
@contextmanager
def without_plugins -> Iterator[None] {
    external_plugins: list[tuple[(str, Any)]] = [];
    for (name, plugin) in `list(plugin_manager.list_name_plugin()) {
        if ((plugin is JacRuntimeImpl) or (name == 'JacRuntimeImpl')) {
            continue;
        }
        external_plugins.append((name, plugin));
        plugin_manager.unregister(plugin=plugin, name=name);
    }
    try {
        yield ;
    } finally {
        for (name, plugin) in external_plugins {
            with suppress(ValueError) {
                plugin_manager.register(plugin, name=name);
            }
        }
    }
}
