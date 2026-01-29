"""Get the graph in json string."""

impl _jac_graph_json(file: (str | None) = None) -> str {
    import from jaclang.runtimelib.utils { collect_node_connections }
    jac = _get_jac();
    visited_nodes: set = <>set();
    connections: set = <>set();
    edge_ids: set = <>set();
    nodes: list[dict] = [];
    edges: list[dict] = [];
    <>root = jac.root();
    collect_node_connections(<>root, visited_nodes, connections, edge_ids);
    nodes.append({'id': id(<>root), 'label': 'root'});
    for node_arch in visited_nodes {
        if (node_arch != <>root) {
            nodes.append({'id': id(node_arch), 'label': repr(node_arch)});
        }
    }
    for (_, source_node, target_node, edge_arch) in connections {
        edge_data = {'from': str(id(source_node)), 'to': str(id(target_node))};
        if (repr(edge_arch) != 'GenericEdge()') {
            edge_data['label'] = repr(edge_arch);
        }
        edges.append(edge_data);
    }
    output = json.dumps({'version': '1.0', 'nodes': nodes, 'edges': edges});
    if file {
        with open(file, 'w') as f {
            f.write(output);
        }
    }
    return output;
}

"""Print the graph in different formats."""
impl printgraph(
    <>node: (NodeArchetype | None) = None,
    depth: int = -1,
    traverse: bool = False,
    edge_type: (list[str] | None) = None,
    bfs: bool = True,
    edge_limit: int = 512,
    node_limit: int = 512,
    file: (str | None) = None,
    format: str = 'dot'
) -> str {
    jac = _get_jac();
    fmt = format.lower();
    if (fmt == 'json') {
        return _jac_graph_json(file);
    }
    return jac.printgraph(
        edge_type=edge_type,
        <>node=(<>node or jac.root()),
        depth=depth,
        traverse=traverse,
        bfs=bfs,
        edge_limit=edge_limit,
        node_limit=node_limit,
        file=file,
        format=fmt
    );
}

"""Lazily resolve module-level attributes."""
impl __getattr__(name: str) -> object {
    if (name == 'NoPerm') {
        return _get_access_level().NO_ACCESS;
    } elif (name == 'ReadPerm') {
        return _get_access_level().READ;
    } elif (name == 'ConnectPerm') {
        return _get_access_level().CONNECT;
    } elif (name == 'WritePerm') {
        return _get_access_level().WRITE;
    } elif (name == 'jid') {
        return _get_jid();
    } elif (name == 'jobj') {
        return _get_jobj();
    } elif (name == 'grant') {
        return _get_grant();
    } elif (name == 'revoke') {
        return _get_revoke();
    } elif (name == 'allroots') {
        return _get_allroots();
    } elif (name == 'save') {
        return _get_save();
    } elif (name == 'commit') {
        return _get_commit();
    } elif (name == 'store') {
        return _get_store();
    }
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}") ;
}

"""Get commit lazily."""
impl _get_commit -> Callable[..., Any] {
    return _get_jac().commit;
}

"""Get storage backend lazily."""
impl _get_store -> Callable[..., Any] {
    return _get_jac().store;
}

"""Get save lazily."""
impl _get_save -> Callable[..., Any] {
    return _get_jac().save;
}

"""Get allroots lazily."""
impl _get_allroots -> Callable[..., Any] {
    return _get_jac().get_all_root;
}

"""Get revoke lazily."""
impl _get_revoke -> Callable[..., Any] {
    return _get_jac().perm_revoke;
}

"""Get grant lazily."""
impl _get_grant -> Callable[..., Any] {
    return _get_jac().perm_grant;
}

"""Get jobj lazily."""
impl _get_jobj -> Callable[..., Any] {
    return _get_jac().get_object;
}

"""Get jid lazily."""
impl _get_jid -> Callable[..., Any] {
    return _get_jac().object_ref;
}

"""Lazily get AccessLevel enum."""
impl _get_access_level -> type[AccessLevel] {
    import from jaclang.pycore.constructs { AccessLevel }
    return AccessLevel;
}

"""Lazily get JacRuntimeInterface."""
impl _get_jac -> type[JacRuntimeInterface] {
    import from jaclang { JacRuntimeInterface }
    return JacRuntimeInterface;
}

"""REST API decorator factory."""
impl restspec(**specs: Any) -> Callable {
    import from jaclang { JacRuntimeInterface as Jac }
    SpecsCls = Jac.get_api_server_class().RestSpecs;
    def decorator(cls: type) -> type {
        cls.restspec = SpecsCls(**specs);
        return cls;
    }
    return decorator;
}
