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
        source.id,
        _type_name(source.archetype),
        _get_type_mro(source.archetype),
        None if source.root == root_anchor.id else source.root
    );
    target_owner = None;
    if target.root and target.root != root_anchor.id {
        target_owner = target.root;
    }
    idx.add_node(
        target.id,
        _type_name(target.archetype),
        _get_type_mro(target.archetype),
        target_owner
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
    source_root = _get_root_anchor(source);
    if source_root is None {
        return;
    }
    _index_edge_into(source_root, source, target, `edge);
    if target.root and target.root != source_root.id {
        target_root = _get_root_anchor(target);
        if target_root is not None {
            _index_edge_into(target_root, source, target, `edge);
        }
    }
}

impl on_edge_destroyed(source: any, target: any, `edge: any) -> None {
    if not _is_enabled() {
        return;
    }
    if not source.persistent {
        return;
    }
    source_root = _get_root_anchor(source);
    if source_root is None {
        return;
    }
    _unindex_edge_from(source_root, source, target, `edge);
    if target.root and target.root != source_root.id {
        target_root = _get_root_anchor(target);
        if target_root is not None {
            _unindex_edge_from(target_root, source, target, `edge);
        }
    }
}

impl on_node_saved(node_anchor: any) -> None {
    if not _is_enabled() {
        return;
    }
    if not node_anchor.persistent or node_anchor.root is None {
        return;
    }
    root_anchor = _get_root_anchor(node_anchor);
    if root_anchor is None {
        return;
    }

    if root_anchor.id == node_anchor.id {
        return;
    }
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
        node_anchor.id,
        _type_name(node_anchor.archetype),
        _get_type_mro(node_anchor.archetype)
    );
    root_anchor.set_topology_index(idx);
}

impl on_node_destroyed(node_anchor: any) -> None {
    if not _is_enabled() {
        return;
    }
    if not node_anchor.persistent or node_anchor.root is None {
        return;
    }
    root_anchor = _get_root_anchor(node_anchor);
    if root_anchor is None {
        return;
    }
    import from jaclang.runtimelib.topology_index { TopologyIndex }
    idx = root_anchor.get_topology_index();
    if not isinstance(idx, TopologyIndex) {
        return;
    }
    idx.remove_node(node_anchor.id);
    root_anchor.set_topology_index(idx);
}
