import from collections { deque }
import from jaclang.runtime.archetype {
    Anchor,
    Archetype,
    Root,
    NodeAnchor,
    EdgeAnchor
}

def _destroy_anchors(objs: any, strict: bool) -> list[Anchor] {
    anchors: list[Anchor] = [];
    queue: list[any] = [objs];
    seen: set[int] = set();
    idx = 0;
    while idx < len(queue) {
        item = queue[idx];
        idx += 1;
        if isinstance(item, Archetype) {
            anchors.append(item.__jac__);
        } elif isinstance(item, Anchor) {
            anchors.append(item);
        } elif isinstance(item, (`list, `tuple, `set, frozenset, deque, `dict)) {
            if id(item) not in seen {
                seen.add(id(item));
                for sub in (item.values() if isinstance(item, `dict) else item) {
                    queue.append(sub);
                }
            }
        } elif strict {
            raise TypeError(
                f"cannot destroy {type(item).__name__!r}: a `del` value "
                "target must yield nodes, edges or archetypes"
            );
        }
    }
    return anchors;
}

def destroy(objs: any, strict: bool = False) -> None {
    anchors = _destroy_anchors(objs, strict);
    if not anchors {
        return;
    }
    import from jaclang.runtime.runtime { JacRuntimeInterface }
    import from jaclang.runtime.osp_kernel { osp_forget }
    import from jaclang.runtime.region { run_drop }
    for anchor in anchors {
        if isinstance(anchor.archetype, Root) {
            raise RuntimeError("cannot destroy root");
        }
        if anchor.destroyed {
            continue;
        }
        if JacRuntimeInterface.check_write_access(anchor, op_hint="delete") {
            match anchor {
                case NodeAnchor():
                    anchor.detach_light();
                    for `edge in anchor.edges[:] {
                        eid = `edge.id;
                        `edge.detach();
                        `edge.destroyed = True;
                        _edge_handle: any = `edge.archetype;
                        run_drop(_edge_handle);
                        osp_forget(_edge_handle);
                        if eid is not None {
                            JacRuntimeInterface.get_context().mem.delete(eid);
                        }
                    }

                case EdgeAnchor():
                    anchor.detach();

                case _:
                    ;

            }
            aid = anchor.id;
            if aid is not None {
                JacRuntimeInterface.get_context().mem.delete(aid);
            }
            anchor.destroyed = True;
            _handle: any = anchor.archetype;
            run_drop(_handle);
            osp_forget(_handle);
        }
    }
}

def peek_attr(`obj: any, name: str) -> any {
    try {
        return getattr(`obj, name);
    } except Exception {
        return None;
    }
}

def peek_item(container: any, key: any) -> any {
    try {
        if isinstance(container, `dict) {
            return `dict.get(container, key);
        }
        if isinstance(container, (`list, `tuple)) {
            builtin_getitem: any = `list.__getitem__
                if isinstance(container, `list)
                else `tuple.__getitem__;
            return builtin_getitem(container, key);
        }
        return container[key];
    } except Exception {
        return None;
    }
}
