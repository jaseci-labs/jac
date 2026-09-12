"""The object-spatial surface the jac0 seed tier lowers to.

jac0 rewrites `node`/`edge`/`walker` declarations, `+>:T:+>`, `[x ->:T:->]`,
`spawn`, `visit`, `disengage`, `del` and `can f with T entry|exit` into calls
on this module. Every helper reaches the same `JacRuntimeInterface` statics
the full compiler's codegen targets, so a seed module and a full-compiler
module share one kernel and one semantics. The runtime is imported lazily:
the seed tier's own modules (the unitree, the parser) define archetypes at
import time, before the runtime package is importable without cycles.

Seed-tier graphs are transient compiler graphs. A field-less directed edge is
a light edge: an entry in the anchors' per-type adjacency (`out_light` /
`in_light`), no edge object, no kernel row, no context. `refs0` reads that
adjacency directly; only edges that carry fields (or attribute assignment at
connect time) become EdgeAnchors in `edges`.
"""

from __future__ import annotations

from typing import Any, Callable

from jaclang.runtime.archetype import (
    EdgeAnchor,
    EdgeArchetype as Edge,
    GenericEdge,
    NodeArchetype as Node,
    WalkerArchetype as Walker,
    _edge_subtypes,
    _light_edge_types,
    edge_subtypes,
    is_light_edge_type,
    light_clear_hop,
    light_connect,
    validate_edge_endpoints,
    light_edge_views,
    light_hop,
    light_hop_answers,
    light_in,
    light_out,
)

__all__ = [
    "Node",
    "Edge",
    "Walker",
    "connect0",
    "disconnect0",
    "refs0",
    "hop0",
    "hop_at0",
    "clear0",
    "spawn0",
    "visit0",
    "disengage0",
    "destroy0",
    "on_entry",
    "on_exit",
    "set_trigger",
]

_ARCH = (Node, Edge, Walker)


def _rt() -> Any:
    from jaclang.runtime.runtime import JacRuntimeInterface

    return JacRuntimeInterface


def connect0(
    left: Any,
    right: Any,
    edge: Any = None,
    conn_assign: tuple[tuple, tuple] | None = None,
) -> Any:
    """Connect in the anchor adjacency: no kernel row, no handle, no context.

    A light edge type (no fields, no attribute assignment) is recorded as an
    adjacency entry on both anchors. Anything else is an EdgeAnchor in the two
    anchors' edge lists. Nothing here pins an anchor in a registry, so a
    released module is collectable.
    """
    if (
        conn_assign is None
        and isinstance(edge, type)
        and not isinstance(left, list)
        and not isinstance(right, list)
    ):
        # One node to one node over a light class: the adjacency write alone.
        light = _light_edge_types.get(edge)
        if light is None:
            light = is_light_edge_type(edge)
        if light:
            src = left.__jac__
            tgt = right.__jac__
            if not (src.persistent or tgt.persistent):
                light_connect(src, edge, tgt)
                return right
    lefts = left if isinstance(left, list) else [left]
    rights = right if isinstance(right, list) else [right]
    ct = edge or GenericEdge
    cls = ct if isinstance(ct, type) else type(ct)
    for source in lefts:
        for target in rights:
            validate_edge_endpoints(source, cls, target)
    light = conn_assign is None and is_light_edge_type(cls)
    for l_arch in lefts:
        src = l_arch.__jac__
        for r_arch in rights:
            tgt = r_arch.__jac__
            if light and not (src.persistent or tgt.persistent):
                light_connect(src, cls, tgt)
                continue
            e = ct() if isinstance(ct, type) else ct
            e.__jac__ = EdgeAnchor(archetype=e, source=src, target=tgt, is_undirected=False)
            src.edges.append(e.__jac__)
            tgt.edges.append(e.__jac__)
            if is_light_edge_type(cls):
                src.mixed = True
                tgt.mixed = True
            if conn_assign:
                for fld, val in zip(conn_assign[0], conn_assign[1], strict=False):
                    setattr(e, fld, val)
    return right


def disconnect0(left: Any, right: Any, dir: int = 2) -> bool:
    from jaclang.compiler.ir.enums import EdgeDir

    return _rt().disconnect(left=left, right=right, dir=EdgeDir(dir))


def _pred_ok(arch: Any, preds: tuple | None) -> bool:
    if not preds:
        return True
    for name, op, value in preds:
        cur = getattr(arch, name, None)
        if op == "==":
            if not (cur == value):
                return False
        elif op == "!=":
            if not (cur != value):
                return False
        elif op == "<":
            if not (cur < value):
                return False
        elif op == "<=":
            if not (cur <= value):
                return False
        elif op == ">":
            if not (cur > value):
                return False
        elif op == ">=":
            if not (cur >= value):
                return False
        else:
            raise ValueError(f"unsupported edge predicate operator {op!r}")
    return True


def _light_hits(
    me: Any,
    edge: Any,
    outgoing: bool,
    edges_only: bool,
    tgt_anchor: Any,
    out: list,
    seen: set,
) -> None:
    if edges_only:
        for ea in light_edge_views(me, edge, outgoing):
            other = ea.target if outgoing else ea.source
            if tgt_anchor is not None and other is not tgt_anchor:
                continue
            out.append(ea.archetype)
        return
    for arch in light_out(me, edge) if outgoing else light_in(me, edge):
        if tgt_anchor is not None and arch.__jac__ is not tgt_anchor:
            continue
        k = id(arch)
        if k in seen:
            continue
        seen.add(k)
        out.append(arch)


def refs0(
    origin: Any,
    dir: int,
    edge: Any = None,
    edges_only: bool = False,
    preds: tuple | None = None,
    target: Any = None,
) -> list:
    """One hop over the anchors' adjacency, without the persistence planner.

    dir: 1 = in, 2 = out, 3 = any. `edge` filters by edge class (subclasses
    included), `preds` are (attr, op, value) edge-attribute predicates and
    `target` restricts the far end to one node. Light edges are read from the
    per-type adjacency (a predicate can never match a field-less edge, so a
    query with `preds` skips them); EdgeAnchors are scanned. Results keep
    connection order within each tier, deduplicated.
    """
    origins = origin if isinstance(origin, list) else [origin]
    out: list = []
    seen: set = set()
    tgt_anchor = target.__jac__ if target is not None else None
    for o in origins:
        me = o.__jac__
        if not preds:
            if dir != 1 and me.out_light:
                _light_hits(me, edge, True, edges_only, tgt_anchor, out, seen)
            if dir != 2 and me.in_light:
                _light_hits(me, edge, False, edges_only, tgt_anchor, out, seen)
        for ea in me.edges:
            arch = ea.archetype
            if edge is not None and not isinstance(arch, edge):
                continue
            if ea.source is me:
                if dir == 1 and not ea.is_undirected:
                    continue
                other = ea.target
            elif ea.target is me:
                if dir == 2 and not ea.is_undirected:
                    continue
                other = ea.source
            else:
                continue
            if tgt_anchor is not None and other is not tgt_anchor:
                continue
            if not _pred_ok(arch, preds):
                continue
            item = arch if edges_only else other.archetype
            if id(item) in seen:
                continue
            seen.add(id(item))
            out.append(item)
    return out


def hop0(origin: Any, dir: int, edge: Any = None, edges_only: bool = False) -> list:
    """The simple hop: one origin, one direction, one edge class, no filters.

    jac0 lowers `[x ->:T:->]` / `[x <-:T:<-]` / `[x -->]` here when the hop
    carries no predicate, node filter or chain. A typed light hop on a
    transient node is answered from the light tier; an untyped hop, a heavy
    type, a node holding a light class as an EdgeAnchor or a persistent
    origin takes `refs0`.

    The one-node, one-direction, single-class read (every `kid` and `parent`
    of the compiler's tree) is answered here in one frame: a copy of the
    adjacency list, connection order kept, one entry per edge.
    """
    if edge is not None and dir != 3 and not edges_only and not isinstance(origin, list):
        me = origin.__jac__
        if not me.persistent and (
            not me.edges or (not me.mixed and _light_edge_types.get(edge))
        ):
            subs = _edge_subtypes.get(edge)
            if subs is None:
                subs = edge_subtypes(edge)
            if len(subs) == 1:
                if dir == 2:
                    d = me.out_light
                    lst = d.get(edge) if d else None
                    return list(lst) if lst else []
                d = me.in_light
                lst = d.get(edge) if d else None
                if not lst:
                    return []
                out: list = []
                for ref in lst:
                    arch = ref()
                    if arch is not None:
                        out.append(arch)
                return out
    if isinstance(origin, list):
        return refs0(origin, dir, edge, edges_only)
    me = origin.__jac__
    if not light_hop_answers(me, edge):
        return refs0(origin, dir, edge, edges_only)
    return light_hop(me, dir, edge, edges_only)


def hop_at0(origin: Any, dir: int, edge: Any, index: int) -> Any:
    """First/last node of a reference, without allocating the intermediate list.

    The seed lowers `[node ->:Edge:->][0]` and `[-1]` here. Persistent,
    polymorphic and multi-origin references retain the normal hop semantics.
    Incoming light adjacency holds weak references, so skip expired endpoints.
    """
    if edge is not None and dir in (1, 2) and not isinstance(origin, list):
        me = origin.__jac__
        if not me.persistent and (
            not me.edges or (not me.mixed and _light_edge_types.get(edge))
        ):
            subs = _edge_subtypes.get(edge)
            if subs is None:
                subs = edge_subtypes(edge)
            if len(subs) == 1:
                adjacency = me.out_light if dir == 2 else me.in_light
                targets = adjacency.get(edge) if adjacency else None
                if targets:
                    if dir == 2:
                        return targets[index]
                    for ref in targets if index == 0 else reversed(targets):
                        value = ref()
                        if value is not None:
                            return value
                raise IndexError("list index out of range")
    return hop0(origin, dir, edge)[index]


def clear0(origin: Any, dir: int, edge: Any = None) -> bool:
    """`del [edge x ->:T:->];`: drop every edge of the set without building it.

    Light edges are popped from the adjacency by class; EdgeAnchors of the
    set are detached one by one (destroyed, if persistent).
    """
    if edge is not None and not isinstance(origin, list):
        me = origin.__jac__
        if not me.edges:
            subs = _edge_subtypes.get(edge)
            if subs is None:
                subs = edge_subtypes(edge)
            if len(subs) == 1:
                # Nothing of that class on this node: no set to clear.
                d_out = me.out_light
                d_in = me.in_light
                if (dir == 1 or not d_out or edge not in d_out) and (
                    dir == 2 or not d_in or edge not in d_in
                ):
                    return False
    origins = origin if isinstance(origin, list) else [origin]
    hit = False
    for o in origins:
        me = o.__jac__
        if light_clear_hop(me, dir, edge):
            hit = True
        for ea in list(me.edges):
            if edge is not None and not isinstance(ea.archetype, edge):
                continue
            if dir == 2 and not (ea.source is me or ea.is_undirected):
                continue
            if dir == 1 and not (ea.target is me or ea.is_undirected):
                continue
            destroy0(ea.archetype)
            hit = True
    return hit


def spawn0(op1: Any, op2: Any) -> Any:
    return _rt().spawn(op1, op2)


_osp_visit: Callable | None = None
_scope_of: Callable | None = None


def visit0(walker: Any, expr: Any, insert_loc: int = -1) -> bool:
    """`visit expr;` from a walker or a node ability.

    A list of node/edge archetypes (the compiler's `visit :0: [k for k in
    self.kid ...]`) is written onto the walker's own queue: the kernel
    registers the live scope per walker at spawn, so the common `visit` and
    `visit :0:` forms need neither the context lookup nor a kernel call.
    Anything else (a GraphQuery, a single archetype, a foreign object, a
    walk with ignores, another insert position) takes the checked path.
    """
    if isinstance(expr, list) and isinstance(walker, Walker):
        if not expr:
            return False
        for item in expr:
            if not isinstance(item, (Node, Edge)):
                return _rt().visit(walker, expr, insert_loc)
        global _osp_visit, _scope_of
        if _osp_visit is None:
            from jaclang.runtime import osp_kernel

            _osp_visit = osp_kernel.osp_visit
            _scope_of = osp_kernel.scope_of
        scope = _scope_of(walker)
        if scope is not None and not scope.ignores:
            if insert_loc == 0:
                scope.front.extend(reversed(expr))
                scope.fenced = True
                scope.pending_fence += len(expr)
                return True
            if insert_loc == -1:
                scope.next.extend(expr)
                return True
        return _osp_visit(expr, insert_loc)
    return _rt().visit(walker, expr, insert_loc)


def disengage0(walker: Any) -> bool:
    return _rt().disengage(walker)


def destroy0(obj: Any) -> None:
    if isinstance(obj, list):
        # an edge set from `del [edge ...]`; a plain `del d[k]` also lands
        # here with whatever the subscript held, so only edges are consumed
        for item in obj:
            if isinstance(item, Edge):
                destroy0(item)
        return
    if isinstance(obj, Edge):
        anchor = obj.__jac__
        if anchor.light or not anchor.persistent:
            anchor.detach()
            return
    if isinstance(obj, _ARCH):
        _rt().destroy(obj)


def on_entry(func: Callable) -> Callable:
    setattr(func, "__jac_entry", True)
    return func


def on_exit(func: Callable) -> Callable:
    setattr(func, "__jac_exit", True)
    return func


def set_trigger(trigger_thunk: Callable) -> Callable[[Callable], Callable]:
    def deco(func: Callable) -> Callable:
        setattr(func, "__jac_trigger__", trigger_thunk)
        return func

    return deco
