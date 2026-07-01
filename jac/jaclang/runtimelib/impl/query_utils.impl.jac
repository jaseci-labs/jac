import from typing { cast }


impl _trace_enabled -> bool {
    val = os.environ.get('JAC_QUERY_TRACE', '');
    return val.lower() in ('1', 'true', 'yes', 'on');
}


impl _CodeKey.postinit -> None {
    self.code = self.filt.__code__;
    cells = self.filt.__closure__ if self.filt.__closure__ is not None else ();
    self.closure_types = tuple(
        c.cell_contents
        for c in cells
        if isinstance(c.cell_contents, `type)
    );
}


impl _CodeKey.__hash__ -> int {
    return hash((self.code, self.closure_types));
}


impl _CodeKey.__eq__(other: object) -> bool {
    return (
        isinstance(other, _CodeKey)
        and self.code is other.code
        and self.closure_types == other.closure_types
    );
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
    code = filt?.__code__;
    if code is None {
        return None;
    }
    return _filter_type_name_by_code(_CodeKey(filt));
}


impl _filter_has_predicates(filt: (Callable[[Archetype], bool] | None)) -> bool {
    if filt is None {
        return False;
    }
    code = filt?.__code__;
    if code is None {
        try {
            opcodes = {instr.opname for instr in dis.get_instructions(filt)};
        } except (TypeError, AttributeError, ValueError) {
            return True;
        }
        return bool(opcodes & {'LOAD_ATTR', 'COMPARE_OP', 'CONTAINS_OP', 'IS_OP'});
    }
    return _filter_has_predicates_by_code(code);
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
