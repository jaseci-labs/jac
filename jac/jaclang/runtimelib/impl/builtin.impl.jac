impl _jac_graph_json(file: (str | None) = None) -> str {
    import from jaclang.runtimelib.utils { collect_node_connections }
    jac = _get_jac();
    visited_nodes: set = set();
    connections: set = set();
    edge_ids: set = set();
    nodes: list[dict] = [];
    edges: list[dict] = [];
    `root = jac.`root();
    collect_node_connections(`root, visited_nodes, connections, edge_ids);
    nodes.append({'id': id(`root), 'label': 'root'});
    for node_arch in visited_nodes {
        if (node_arch != `root) {
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

impl printgraph(
    nd: (NodeArchetype | None) = None,
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
        nd=(nd or jac.`root()),
        depth=depth,
        traverse=traverse,
        bfs=bfs,
        edge_limit=edge_limit,
        node_limit=node_limit,
        file=file,
        format=fmt
    );
}

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
    } elif (name == 'on_commit') {
        return _get_on_commit();
    } elif (name == 'store') {
        return _get_store();
    } elif (name == 'llm') {
        return _get_llm();
    } elif (name == 'archetype_alias') {
        return _get_archetype_alias();
    } elif (name in ('schema_was', 'schema_alias', 'schema_drop', 'schema_upgrade')) {
        return _get_schema_builder(name);
    }
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}");
}

impl _get_commit -> Callable[..., any] {
    return _get_jac().commit;
}

impl _get_on_commit -> Callable[..., any] {
    return _get_jac().on_commit;
}

impl _get_store -> Callable[..., any] {
    return _get_jac().store;
}

impl _get_llm -> LLMModel {
    return _get_jac().default_llm();
}

impl _get_archetype_alias -> Callable[..., any] {
    def factory(old_name: str) -> Callable {
        def decorator(cls: type) -> type {
            import from jaclang.runtimelib.serializer { Serializer }
            Serializer.register_alias(old_name, cls);
            return cls;
        }
        return decorator;
    }
    return factory;
}

impl _get_schema_builder(name: str) -> Callable[..., any] {
    def builder(*args: any, **kwargs: any) -> any {
        import jaclang.runtimelib.schema_rules as _rules;
        return getattr(_rules, name)(*args, **kwargs);
    }
    return builder;
}

impl _get_save -> Callable[..., any] {
    return _get_jac().save;
}

impl _get_allroots -> Callable[..., any] {
    return _get_jac().get_all_root;
}

impl _get_revoke -> Callable[..., any] {
    return _get_jac().perm_revoke;
}

impl _get_grant -> Callable[..., any] {
    return _get_jac().perm_grant;
}

impl _get_jobj -> Callable[..., any] {
    return _get_jac().get_object;
}

impl _get_jid -> Callable[..., any] {
    return _get_jac().object_ref;
}

impl _get_access_level -> type[AccessLevel] {
    import from jaclang.jac0core.constructs { AccessLevel }
    return AccessLevel;
}

impl _get_jac -> type[JacRuntimeInterface] {
    import from jaclang { JacRuntimeInterface }
    return JacRuntimeInterface;
}

impl new(cls: any, *args: any) -> any {
    return cls(*args);
}

impl unsafe_html(html: any) -> dict {
    return {"__jacUnsafeHtml": str(html) if (html is not None) else ""};
}

impl restspec(**specs: any) -> Callable {
    import from jaclang { JacRuntimeInterface as Jac }
    SpecsCls = Jac.get_api_server_class().RestSpecs;
    def decorator(cls: type) -> type {
        cls.restspec = SpecsCls(**specs);
        return cls;
    }
    return decorator;
}

impl schedule(**kwargs: any) -> Callable {
    import from jaclang.runtimelib.scheduler { ScheduleSpec }
    import from jaclang.runtimelib.builtin { ScheduleTrigger }
    trigger = kwargs.pop("trigger", ScheduleTrigger.STATIC);
    if isinstance(trigger, str) {
        trigger = ScheduleTrigger(trigger);
    }
    spec = ScheduleSpec(trigger=trigger, **kwargs);
    def decorator(target: type) -> type {
        target.schedule_spec = spec;
        return target;
    }
    return decorator;
}
