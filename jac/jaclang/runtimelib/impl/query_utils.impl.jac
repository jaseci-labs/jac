"""Shared edge-traversal query helpers implementation."""

import from typing { cast }


impl _trace_enabled -> bool {
    val = os.environ.get('JAC_QUERY_TRACE', '');
    return val.lower() in ('1', 'true', 'yes', 'on');
}


impl _filter_type_name(filt: (Callable[[Archetype], bool] | None)) -> (str | None) {
    if filt is None {
        return None;
    }
    try {
        if isinstance(filt, Archetype) {
            return `type(filt).__name__;
        }
    } except Exception {
        ;
    }
    try {
        closure = inspect.getclosurevars(filt);
        for val in `list(closure.nonlocals.values()) + `list(
            closure.globals.values()
        ) {
            if isinstance(val, `type) and issubclass(val, Archetype) {
                return val.__name__;
            }
        }
    } except Exception {
        ;
    }
    return None;
}


impl _filter_has_predicates(filt: (Callable[[Archetype], bool] | None)) -> bool {
    if filt is None {
        return False;
    }
    try {
        opcodes = {instr.opname for instr in dis.get_instructions(filt)};
    } except (TypeError, AttributeError, ValueError) {
        return True;
    }
    return bool(opcodes & {'LOAD_ATTR', 'COMPARE_OP', 'CONTAINS_OP', 'IS_OP'});
}


impl _materialize_ids(
    mem: Memory,
    ids: list[UUID],
    post_filter: (Callable[[Archetype], bool] | None) = None,
    slc: (slice | None) = None
) -> list[NodeAnchor] {
    if not ids {
        return [];
    }
    import from jaclang.runtimelib.memory { TieredMemory }
    loaded: dict[UUID, Anchor];
    if isinstance(mem, TieredMemory) {
        loaded = mem.batch_get(ids);
    } else {
        loaded = {
            i: a
            for i in ids
            if (a := mem.get(i)) is not None
        };
    }
    result: list[NodeAnchor] = [];
    for i in ids {
        anchor = loaded.get(i);
        if isinstance(anchor, NodeAnchor) and anchor.archetype {
            if post_filter is not None and not post_filter(anchor.archetype) {
                continue;
            }
            result.append(cast(NodeAnchor, anchor));
        }
    }
    if slc is not None {
        result = result[slc];
    }
    return result;
}


impl _path_root_anchor(mem: Memory, path: ObjectSpatialPath) -> (NodeAnchor | None) {
    if not path.origin {
        return None;
    }
    origin_anchor = path.origin[0].__jac__;
    if not origin_anchor.persistent {
        return None;
    }
    import from jaclang.jac0core.archetype { Root }
    if origin_anchor.root is None {
        if isinstance(origin_anchor, NodeAnchor)
        and isinstance(origin_anchor.archetype, Root) {
            return origin_anchor;
        }
        return None;
    }
    try {
        `root = mem.get(origin_anchor.root);
        if isinstance(`root, NodeAnchor) {
            return `root;
        }
    } except Exception {
        ;
    }
    return None;
}
