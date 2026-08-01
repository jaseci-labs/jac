impl _is_enabled -> bool {
    import os;
    env = os.environ.get("JAC_TOPOLOGY_INDEX");
    if env is not None {
        return env.lower() in ("1", "true", "yes", "on");
    }
    try {
        import from jaclang.project.config { get_config }
        cfg = get_config();
        return cfg is not None and cfg.run.topology_index;
    } except Exception {
        return False;
    }
}

impl _get_root_anchor(anchor: any) -> any {
    import from jaclang.jac0core.archetype { NodeAnchor as NA, Root }
    if anchor.root is None {
        if isinstance(anchor, NA) and isinstance(anchor.archetype, Root) {
            return anchor;
        }
        return None;
    }
    try {
        import from jaclang { JacRuntimeInterface as Jac }
        ctx = Jac.get_context();
        `root = ctx.mem.get(anchor.root);
        if isinstance(`root, NA) {
            return `root;
        }
    } except Exception {
        ;
    }
    return None;
}

impl _get_index_anchor -> any {
    try {
        import from jaclang { JacRuntimeInterface as Jac }
        import from uuid { UUID }
        import from jaclang.jac0core.archetype { NodeAnchor }
        import from jaclang.jac0core.constant { Constants as Con }
        ctx = Jac.get_context();
        system_root_id = UUID(Con.SUPER_ROOT_UUID);
        active_root = ctx.mem.get(system_root_id);
        if isinstance(active_root, NodeAnchor) {
            ctx.system_root = active_root;
            return active_root;
        }
        if isinstance(ctx.system_root, NodeAnchor) {
            ctx.system_root.id = system_root_id;
            ctx.system_root.persistent = True;
            ctx.mem.put(ctx.system_root);
            return ctx.system_root;
        }
    } except Exception {
        return None;
    }
    return None;
}

impl _type_name(`obj: object) -> str {
    return `type(`obj).__name__;
}

impl _get_type_mro(`obj: object) -> list[str] {
    import from jaclang.jac0core.archetype {
        NodeArchetype,
        EdgeArchetype,
        WalkerArchetype,
        Archetype
    }
    stop_classes = (NodeArchetype, EdgeArchetype, WalkerArchetype, Archetype, object);
    chain: list[str] = [];
    for cls in `type(`obj).__mro__ {
        if cls in stop_classes {
            break;
        }
        chain.append(cls.__name__);
    }
    return chain;
}

impl _index_edge_into(root_anchor: any, source: any, target: any, `edge: any) -> None {
    import from jaclang.runtimelib.topology_index { TopologyIndex }
    idx = root_anchor.get_topology_index();
    if not isinstance(idx, TopologyIndex) {
        idx = TopologyIndex();
    }
    idx.add_node(
        root_anchor.id,
        _type_name(root_anchor.archetype),
        _get_type_mro(root_anchor.archetype)
    );
    idx.add_node(
        source.id, _type_name(source.archetype), _get_type_mro(source.archetype)
    );
    idx.add_node(
        target.id, _type_name(target.archetype), _get_type_mro(target.archetype)
    );
    idx.add_edge(source.id, target.id, _type_name(`edge.archetype));
    if `edge.is_undirected {
        idx.add_edge(target.id, source.id, _type_name(`edge.archetype));
    }
    root_anchor.set_topology_index(idx);
}

impl _unindex_edge_from(
    root_anchor: any, source: any, target: any, `edge: any
) -> None {
    import from jaclang.runtimelib.topology_index { TopologyIndex }
    idx = root_anchor.get_topology_index();
    if not isinstance(idx, TopologyIndex) {
        return;
    }
    idx.remove_edge(source.id, target.id, _type_name(`edge.archetype));
    if `edge.is_undirected {
        idx.remove_edge(target.id, source.id, _type_name(`edge.archetype));
    }
    root_anchor.set_topology_index(idx);
}

impl on_edge_created(source: any, target: any, `edge: any) -> None {
    if not _is_enabled() {
        return;
    }
    if not source.persistent {
        return;
    }
    index_anchor = _get_index_anchor();
    if index_anchor is None {
        return;
    }
    _index_edge_into(index_anchor, source, target, `edge);
}

impl on_edge_destroyed(source: any, target: any, `edge: any) -> None {
    if not _is_enabled() {
        return;
    }
    if not source.persistent {
        return;
    }
    index_anchor = _get_index_anchor();
    if index_anchor is None {
        return;
    }
    _unindex_edge_from(index_anchor, source, target, `edge);
}

impl on_node_saved(node_anchor: any) -> None {
    if not _is_enabled() {
        return;
    }
    if not node_anchor.persistent {
        return;
    }
    index_anchor = _get_index_anchor();
    if index_anchor is None {
        return;
    }

    if index_anchor.id == node_anchor.id {
        return;
    }
    import from jaclang.runtimelib.topology_index { TopologyIndex }
    idx = index_anchor.get_topology_index();
    if not isinstance(idx, TopologyIndex) {
        idx = TopologyIndex();
    }
    idx.add_node(
        index_anchor.id,
        _type_name(index_anchor.archetype),
        _get_type_mro(index_anchor.archetype)
    );
    idx.add_node(
        node_anchor.id,
        _type_name(node_anchor.archetype),
        _get_type_mro(node_anchor.archetype)
    );
    index_anchor.set_topology_index(idx);
}

impl on_node_destroyed(node_anchor: any) -> None {
    if not _is_enabled() {
        return;
    }
    if not node_anchor.persistent {
        return;
    }
    index_anchor = _get_index_anchor();
    if index_anchor is None or index_anchor.id == node_anchor.id {
        return;
    }
    import from jaclang.runtimelib.topology_index { TopologyIndex }
    idx = index_anchor.get_topology_index();
    if not isinstance(idx, TopologyIndex) {
        return;
    }
    idx.remove_node(node_anchor.id);
    index_anchor.set_topology_index(idx);
}
