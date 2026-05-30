"""Server binding for the portable Object-Spatial kernel.

Builds the kernel's dispatch descriptors (`WalkerDesc` / `NodeDesc`) and
type-tag relation from live archetype classes -- the server's analogue of the
static descriptors the native backend emits at compile time. The kernel stays
backend-free; this module is the `OspRuntime` the server supplies.

The sv runtime stores `NodeAnchor` / `EdgeAnchor` wrappers in
`walker.next` / `walker.path` / `walker.ignores`, but ability functions receive
the underlying archetype (`anchor.archetype`). The slot wrappers below unwrap
any anchor argument before invoking the user's ability function, so the kernel
can be anchor-agnostic and uniformly call `slot.fn(a, b)`.

Reports bubble: a nested spawn forwards its collected reports up to the
outer scope (mirroring the sv `CallState` contextvar semantics); the outermost
spawn drains them onto the walker and commits the persistence buffer on
success.
"""

import from types { UnionType }
import from typing { cast }
import from jaclang.jac0core.archetype {
    NodeAnchor,
    EdgeAnchor,
    ObjectSpatialFunction,
    WalkerArchetype
}
import from jaclang.jac0core.osp_kernel {
    Slot,
    WalkerDesc,
    NodeDesc,
    WalkScope,
    OspRuntime,
    UNTYPED,
    _walk_stack
}

"""class -> int tag, the inverse list (index == tag), and a descriptor cache."""
glob _tag_of_cls: dict[(any, int)] = {},
     _cls_of_tag: list[any] = [],
     _desc_of_cls: dict[(any, WalkerDesc)] = {};

"""Assign (or fetch) the stable type-tag for an archetype class."""
def _tag_for(cls: any) -> int {
    if cls in _tag_of_cls {
        return _tag_of_cls[cls];
    }
    t = len(_cls_of_tag);
    _tag_of_cls[cls] = t;
    _cls_of_tag.append(cls);
    return t;
}

"""Expand a trigger (single type / union / tuple / None) into member types."""
def _trigger_members(trig: any) -> list[any] {
    if trig is None {
        return [];
    }
    if isinstance(trig, UnionType) {
        return `list(trig.__args__);
    }
    if isinstance(trig, tuple) {
        return `list(trig);
    }
    return [trig];
}

"""Unwrap a sv `NodeAnchor` / `EdgeAnchor` to its archetype; pass through any
non-anchor value. Lets ability functions written against archetypes be invoked
uniformly from a kernel that carries anchors in its scope."""
def _unwrap(x: any) -> any {
    if isinstance(x, (NodeAnchor, EdgeAnchor)) {
        return x.archetype;
    }
    return x;
}

"""Wrap an ability function so kernel-side `(a, b)` arguments are unwrapped to
archetypes before the user's code runs. Captures `f` by default-arg so each
slot binds its own function."""
def _wrap_ability(f: any) -> any {
    def call(a: any, b: any, fn: any = f) -> any {
        return fn(_unwrap(a), _unwrap(b));
    }
    return call;
}

"""Build the dispatch slots for one ability-function list."""
def _slots_from(funcs: list[ObjectSpatialFunction]) -> list[Slot] {
    slots: list[Slot] = [];
    for f in funcs {
        members = _trigger_members(f.trigger);
        wrapped = _wrap_ability(f.func);
        if not members {
            slots.append(Slot(trig_tag=UNTYPED, fn=wrapped));
        } else {
            for m in members {
                slots.append(Slot(trig_tag=_tag_for(m), fn=wrapped));
            }
        }
    }
    return slots;
}

"""Build (and cache) the dispatch descriptor for an archetype class."""
def desc_for(cls: any) -> WalkerDesc {
    if cls in _desc_of_cls {
        return _desc_of_cls[cls];
    }
    desc = WalkerDesc(
        type_tag=_tag_for(cls),
        entry=_slots_from(cast(list[ObjectSpatialFunction], cls._jac_entry_funcs_)),
        exit=_slots_from(cast(list[ObjectSpatialFunction], cls._jac_exit_funcs_))
    );
    _desc_of_cls[cls] = desc;
    return desc;
}

"""`tag_of`: archetype class tag of a node / walker handle. Unwraps anchors so
dispatch keys on the user-defined archetype class, not on the anchor wrapper."""
def _sv_tag_of(handle: any) -> int {
    return _tag_for(`type(_unwrap(handle)));
}

"""`is_a`: subtype test over the registered archetype classes."""
def _sv_is_a(tag: int, base: int) -> bool {
    return issubclass(cast(type, _cls_of_tag[tag]), cast(type, _cls_of_tag[base]));
}

"""`node_desc`: descriptor for a location's type-tag (as a NodeDesc view)."""
def _sv_node_desc(tag: int) -> NodeDesc {
    d = desc_for(_cls_of_tag[tag]);
    return NodeDesc(type_tag=d.type_tag, entry=d.entry, exit=d.exit);
}

"""`on_complete`: deliver reports + commit persistence at the spawn boundary.

Nested spawns bubble their collected reports up to the outer scope (matching
the sv `CallState` contextvar semantics where a nested spawn shares the
outermost report queue). The outermost spawn drains `scope.reports` onto the
walker and commits the persistence buffer on success."""
def _sv_on_complete(scope: WalkScope, ok: bool) {
    # Mirror the kernel scope onto the walker anchor (sv legacy contract:
    # walker.path holds the visited locations; next/ignores reset at spawn end).
    if isinstance(scope.wlk, WalkerArchetype) {
        anch = scope.wlk.__jac__;
        anch.path = `list(scope.path);
        anch.next = [];
        anch.ignores = [];
    }
    if _walk_stack {
        # Nested spawn: bubble reports up to the outer scope; the outermost
        # spawn drains them onto the walker and commits.
        outer = _walk_stack[-1];
        for r in scope.reports {
            outer.reports.append(r);
        }
        return;
    }
    # Outermost spawn: drain reports onto the walker and commit on success.
    if isinstance(scope.wlk, WalkerArchetype) {
        scope.wlk.reports = scope.reports;
    }
    if ok {
        # Commit the deferred L1 buffer to durable storage (mirrors sv's
        # ExecutionManager.spawn_walker so direct `walker spawn node` flows
        # persist without manual Jac.commit()). On native / client builds the
        # context's mem.commit is a no-op so this is safe to call uniformly.
        import from jaclang.jac0core.runtime { JacRuntimeInterface }
        try {
            JacRuntimeInterface.get_context().mem.commit();
        } except Exception {
            ;
        }
    }
}

"""The server's OspRuntime: type-tag intrinsics + descriptor lookup, bridged to
live archetype reflection."""
def make_sv_runtime -> OspRuntime {
    return OspRuntime(
        tag_of=_sv_tag_of,
        is_a=_sv_is_a,
        node_desc=_sv_node_desc,
        on_complete=_sv_on_complete
    );
}
