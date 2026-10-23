impl traverse_graph(
    nd: NodeArchetype,
    cur_depth: int,
    depth: int,
    edge_type: list[str],
    traverse: bool,
    connections: list[tuple[NodeArchetype, NodeArchetype, EdgeArchetype]],
    node_depths: dict[(NodeArchetype, int)],
    visited_nodes: list[NodeArchetype],
    queue: list[tuple[NodeArchetype, int]],
    bfs: bool,
    dfs: Callable,
    node_limit: int,
    edge_limit: int
) -> None {
    nd_anchor = nd.__jac__;
    sv_register_hydrated(nd_anchor, fetch_stubs=True);
    for edge_arch in JacRuntimeInterface.hop(nd, 3, None, True) {
        `edge = edge_arch.__jac__;
        if not isinstance(`edge, EdgeAnchor) {
            continue;
        }
        is_self_loop = id(`edge.source) == id(`edge.target);
        is_in_edge = `edge.target == nd_anchor;
        if (
            (traverse and is_in_edge)
            or (`edge.archetype.__class__.__name__ in edge_type)
        ) {
            continue;
        }
        if is_self_loop {
            continue;
        } elif (
            (other_nda := (`edge.target if not is_in_edge else `edge.source))
            and (other_nd := other_nda.archetype)
        ) {
            new_con = (nd, other_nd, `edge.archetype)
                if not is_in_edge
                else (other_nd, nd, `edge.archetype);
            if ((nd in node_depths) and (node_depths[nd] is not None)) {
                if (other_nd in node_depths) {
                    node_depths[nd] = min(
                        cur_depth, node_depths[nd], (node_depths[other_nd] + 1)
                    );
                    node_depths[other_nd] = min(
                        (cur_depth + 1), (node_depths[nd] + 1), node_depths[other_nd]
                    );
                } elif other_nd {
                    node_depths[other_nd] = min((cur_depth + 1), (node_depths[nd] + 1));
                } else {
                    raise ValueError('Edge is detached from node in graph');
                }
            }
            if (
                other_nd
                and (new_con not in connections)
                and (
                    (
                        (depth < 0)
                        or ((min(node_depths[nd], node_depths[other_nd]) + 1) <= depth)
                    )
                    and (node_limit > len(visited_nodes))
                    and (edge_limit > len(connections))
                )
            ) {
                connections.append(new_con);
                if bfs {
                    queue.append((other_nd, (cur_depth + 1)));
                } else {
                    dfs(other_nd, (cur_depth + 1));
                }
            }
        }
    }
}

impl graph_type_named(base: type, key: str) -> (type | None) {
    pending: list[type] = [base];
    seen: set = set();
    while pending {
        cls = pending.pop();
        if cls in seen {
            continue;
        }
        seen.add(cls);
        if storage_type(cls) == key or cls.__name__ == key {
            return cls;
        }
        pending.extend(cls.__subclasses__());
    }
    return None;
}

impl _graph_label(arch: Archetype) -> str {
    return 'root' if isinstance(arch, Root) else type(arch).__name__;
}

impl _graph_fields(arch: Archetype) -> dict[str, str] {
    out: dict[str, str] = {};
    for (name, value) in getattr(arch, '__dict__', {}).items() {
        if name.startswith('_') {
            continue;
        }
        text = repr(value);
        out[name] = text if len(text) <= 80 else text[:77] + '...';
        if len(out) >= 12 {
            break;
        }
    }
    return out;
}

impl graph_node_view(nd: NodeArchetype) -> dict[str, any] {
    mem: any = JacRuntimeInterface.get_context().mem;
    counts: dict[str, dict[str, dict[str, int]]] = {};
    for (name, direction) in [('out', 2), ('in', 1)] {
        counts[name] = {
            'nodes': resolve_query_type_counts(
                mem, GraphQuery(nd, hops=[QHop(dir=direction)]), 'node'
            ),
            'edges': resolve_query_type_counts(
                mem, GraphQuery(nd, hops=[QHop(dir=direction)]), 'edge'
            )
        };
    }
    return {
        'id': nd.__jac__.ensure_id().hex,
        'type': _graph_label(nd),
        'type_key': storage_type(type(nd)),
        'root': isinstance(nd, Root),
        'fields': {} if isinstance(nd, Root) else _graph_fields(nd),
        'counts': counts
    };
}

impl _graph_edge(
    e: (Anchor | None), origin: Anchor, other: Anchor, direction: int
) -> dict[str, any] {
    if isinstance(e, EdgeAnchor) and e.archetype is not None {
        kind = type(e.archetype);
        return {
            'id': e.ensure_id().hex,
            'from': e.source.ensure_id().hex,
            'to': e.target.ensure_id().hex,
            'type': kind.__name__,
            'type_key': storage_type(kind),
            'label': '' if isinstance(e.archetype, GenericEdge) else kind.__name__,
            'undirected': bool(e.is_undirected)
        };
    }
    (src, dst) = (other, origin) if direction == 1 else (origin, other);
    return {
        'id': None,
        'from': src.ensure_id().hex,
        'to': dst.ensure_id().hex,
        'type': '',
        'type_key': '',
        'label': '',
        'undirected': False
    };
}

impl _graph_cursor(text: (str | None)) -> (tuple[int, (UUID | None)] | None) {
    if not text {
        return None;
    }
    (seq, _, eid) = text.partition('.');
    return (int(seq), UUID(eid) if eid else None);
}

impl graph_neighbors_view(
    nd: NodeArchetype,
    direction: str = 'out',
    node_type: (type | None) = None,
    edge_type: (type | None) = None,
    limit: int = 50,
    cursor: (str | None) = None
) -> dict[str, any] {
    if direction not in GRAPH_DIRS {
        raise ValueError(f"dir must be one of {sorted(GRAPH_DIRS)}");
    }
    hop_dir = GRAPH_DIRS[direction];
    q = GraphQuery(
        nd,
        hops=[QHop(dir=hop_dir, `edge=edge_type, nd=node_type)],
        limit=max(1, min(int(limit), GRAPH_PAGE_MAX)),
        after=_graph_cursor(cursor)
    );
    mem: any = JacRuntimeInterface.get_context().mem;
    (page, nxt) = resolve_query_page(mem, q);
    origin = nd.__jac__;
    nodes: list[dict[str, any]] = [];
    edges: list[dict[str, any]] = [];
    seen: set = set();
    for (a, e) in page {
        nid = a.ensure_id().hex;
        if nid not in seen {
            seen.add(nid);
            nodes.append(
                {
                    'id': nid,
                    'type': _graph_label(a.archetype),
                    'type_key': storage_type(type(a.archetype)),
                    'root': isinstance(a.archetype, Root)
                }
            );
        }
        edges.append(_graph_edge(e, origin, a, hop_dir));
    }
    next_cursor: (str | None) = None;
    if nxt is not None {
        next_cursor = f"{nxt[0]}.{nxt[1].hex if nxt[1] is not None else ''}";
    }
    return {
        'id': origin.ensure_id().hex,
        'dir': direction,
        'nodes': nodes,
        'edges': edges,
        'next_cursor': next_cursor
    };
}

impl get_name(target_path: (str | None) = None) -> str | None {
    import from pathlib { Path }

    effective_target = target_path or JacRuntime.get_full_target_path();
    if not effective_target {
        return None;
    }
    file_path = Path(effective_target);

    try {
        cfg = get_config(start_path=file_path.parent, force_discover=False);
        if cfg and cfg.toml_path and cfg.project.name {
            if cfg.toml_path.parent == file_path.parent {
                return cfg.project.name;
            }
        }
    } except Exception {}

    stem = file_path.stem;
    return stem if stem not in ['jac', '__main__'] else None;
}

impl get_db_path(base_path: str, target_path: (str | None) = None) -> (str | None) {
    import os;
    import from pathlib { Path }

    data_path_override = os.environ.get('JAC_DATA_PATH');
    if data_path_override {
        data_dir = Path(data_path_override) / ".jac" / "data";
    } else {
        data_dir = Path(base_path) / ".jac" / "data";
    }

    if (project_name := get_name(target_path=target_path)) {
        return str(data_dir / f"{project_name}.db");
    }

    return str(data_dir / "main.db");
}

impl storage_key(id: UUID) -> str {
    return f"anchor:{str(id)}";
}

impl to_uuid(id: (UUID | str)) -> UUID {
    if isinstance(id, UUID) {
        return id;
    }
    return UUID(str(id));
}

impl release_arch(raw: str) -> str {
    m = raw.strip().lower();
    if m in ("arm64", "aarch64") {
        return "aarch64";
    }
    if m in ("amd64", "x86_64") {
        return "x86_64";
    }
    return m;
}

impl host_arch -> str {
    return release_arch(platform.machine());
}

impl host_os -> str {
    sysname = platform.system().strip().lower();
    if sysname == "darwin" {
        return "macos";
    }
    return sysname;
}

impl triple_arch(triple: str) -> str {
    if "aarch64" in triple.lower() or "arm64" in triple.lower() {
        return "aarch64";
    }
    return "x86_64";
}
