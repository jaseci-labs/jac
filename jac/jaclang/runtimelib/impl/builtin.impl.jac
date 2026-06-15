"""Get the graph in json string."""

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

"""Print the graph in different formats."""
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
    } elif (name == 'llm') {
        return _get_llm();
    } elif (name == 'archetype_alias') {
        return _get_archetype_alias();
    } elif (name in ('schema_was', 'schema_alias', 'schema_drop', 'schema_upgrade')) {
        return _get_schema_builder(name);
    }
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}");
}

"""Get commit lazily."""
impl _get_commit -> Callable[..., any] {
    return _get_jac().commit;
}

"""Get storage backend lazily."""
impl _get_store -> Callable[..., any] {
    return _get_jac().store;
}

"""Get default LLM model instance lazily."""
impl _get_llm -> LLMModel {
    return _get_jac().default_llm();
}

"""Get archetype_alias decorator factory lazily.

Returns a closure that defers the `Serializer` import to
decorator-application time (not module-attribute-access time).
Importing the serializer at the moment `from jaclang.runtimelib.builtin
import archetype_alias` is resolved would race with serializer's own
module-level init (serializer defines its alias decorator near the
bottom, and `register(Root)` runs earlier), producing a circular
"partially initialized module" ImportError for any user app that uses
`@archetype_alias`. Deferring the Serializer import past preamble-time
lets the module finish loading through the normal path.
"""
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

"""Get a schema-rule builder (schema_was/schema_alias/schema_drop/
schema_upgrade) lazily.

Same call-time-deferred pattern as `archetype_alias`: the schema_rules
module is imported only when the builder actually fires (inside an
executing `__jac_schema__` during class registration), keeping the
builtin module's import preamble free of runtimelib init-order races.
"""
impl _get_schema_builder(name: str) -> Callable[..., any] {
    def builder(*args: any, **kwargs: any) -> any {
        import jaclang.runtimelib.schema_rules as _rules;
        return getattr(_rules, name)(*args, **kwargs);
    }
    return builder;
}

"""Get save lazily."""
impl _get_save -> Callable[..., any] {
    return _get_jac().save;
}

"""Get allroots lazily."""
impl _get_allroots -> Callable[..., any] {
    return _get_jac().get_all_root;
}

"""Get revoke lazily."""
impl _get_revoke -> Callable[..., any] {
    return _get_jac().perm_revoke;
}

"""Get grant lazily."""
impl _get_grant -> Callable[..., any] {
    return _get_jac().perm_grant;
}

"""Get jobj lazily."""
impl _get_jobj -> Callable[..., any] {
    return _get_jac().get_object;
}

"""Get jid lazily."""
impl _get_jid -> Callable[..., any] {
    return _get_jac().object_ref;
}

"""Lazily get AccessLevel enum."""
impl _get_access_level -> type[AccessLevel] {
    import from jaclang.jac0core.constructs { AccessLevel }
    return AccessLevel;
}

"""Lazily get JacRuntimeInterface."""
impl _get_jac -> type[JacRuntimeInterface] {
    import from jaclang { JacRuntimeInterface }
    return JacRuntimeInterface;
}

"""Portable constructor: server-side spelling of `Cls(*args)`.

The cl backend rewrites `new(...)` calls at compile time into
`Reflect.construct(...)` (see ESBuiltinEmitter.emit_new), so this runtime
implementation is only invoked when the call survives to the server target.
"""
impl new(cls: any, *args: any) -> any {
    return cls(*args);
}

"""Wrap a string so the JSX flattener renders it as raw HTML.

The marker is a plain dict with a single ``__jacUnsafeHtml`` key, so it
survives JSON serialisation across the walker boundary and is recognised
by both client runtimes (jac-client React adapter and bare-serve DOM
adapter). Server code never renders -- it just produces the marker for
client-side consumption.
"""
impl unsafe_html(html: any) -> dict {
    return {"__jacUnsafeHtml": str(html) if (html is not None) else ""};
}

"""REST API decorator factory."""
impl restspec(**specs: any) -> Callable {
    import from jaclang { JacRuntimeInterface as Jac }
    SpecsCls = Jac.get_api_server_class().RestSpecs;
    def decorator(cls: type) -> type {
        cls.restspec = SpecsCls(**specs);
        return cls;
    }
    return decorator;
}

"""Schedule decorator factory — attaches ScheduleSpec to a walker or function."""
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
