"""Server binding for the portable Object-Spatial kernel.

Builds the kernel's dispatch descriptors (`WalkerDesc`/`NodeDesc`) and type-tag
relation from live archetype classes — the server's analogue of the static
descriptors the native backend emits at compile time. The kernel itself stays
backend-free; this module is the `OspRuntime` the server supplies.

Descriptors are derived from each archetype's compiler-populated
`_jac_entry_funcs_` / `_jac_exit_funcs_` (their `.trigger` is now compiler-known
data) so the slot order matches the server engine. Union triggers expand into
one slot per member; an untyped trigger becomes `UNTYPED`. Archetype classes are
reflected dynamically, so reflected values are typed loosely (`any`).
"""

import from types { UnionType }
import from typing { cast }
import from jaclang.jac0core.archetype { ObjectSpatialFunction }
import from jaclang.jac0core.osp_kernel {
    Slot,
    WalkerDesc,
    NodeDesc,
    WalkScope,
    OspRuntime,
    UNTYPED
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

"""Build the dispatch slots for one ability-function list."""
def _slots_from(funcs: list[ObjectSpatialFunction]) -> list[Slot] {
    slots: list[Slot] = [];
    for f in funcs {
        members = _trigger_members(f.trigger);
        if not members {
            slots.append(Slot(trig_tag=UNTYPED, fn=f.func));
        } else {
            for m in members {
                slots.append(Slot(trig_tag=_tag_for(m), fn=f.func));
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

"""`tag_of`: archetype class tag of a node/walker instance."""
def _sv_tag_of(handle: any) -> int {
    return _tag_for(type(handle));
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

"""`on_complete`: deliver collected reports onto the walker at the boundary."""
def _sv_on_complete(scope: WalkScope, ok: bool) {
    scope.wlk.reports = scope.reports;
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
