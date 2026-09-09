impl _jac_graph_json(file: (str | None) = None) -> str {
    import from jaclang.runtime.graph_utils { collect_node_connections }
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
    if (name == 'AccessLevel') {
        return _get_access_level();
    } elif (name in ('NoPerm', 'ReadPerm', 'ConnectPerm', 'WritePerm')) {
        _member = {
            'NoPerm': 'NO_ACCESS',
            'ReadPerm': 'READ',
            'ConnectPerm': 'CONNECT',
            'WritePerm': 'WRITE'
        }[name];
        raise AttributeError(
            f"'{name}' was removed; use AccessLevel.{_member} (ambient, no import)"
        );
    } elif (name == 'jid') {
        return _get_jid();
    } elif (name == 'jobj') {
        return _get_jobj();
    } elif (name == 'jref') {
        return _get_jref();
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
    } elif (
        name
        in (
            'Region',
            'region_of',
            '_jac_region_open',
            '_jac_region_close',
            '_jac_region_register',
            '_jac_region_instrument'
        )
    ) {
        import jaclang.runtime.region as _region_mod;
        _region_map = {
            'Region': 'JacRegion',
            'region_of': 'region_of',
            '_jac_region_open': 'open_region',
            '_jac_region_close': 'close_region',
            '_jac_region_register': 'register_drop',
            '_jac_region_instrument': 'instrument_drops'
        };
        return getattr(_region_mod, _region_map[name]);
    } elif name.startswith('wrapping_') or _is_sized_type_name(name) {
        import jaclang.runtime.sized as _sized_mod;
        if name.startswith('wrapping_') {
            return getattr(_sized_mod, name);
        }
        return _sized_mod.SIZED_TYPES[name];
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
            import from jaclang.data.serializer { Serializer }
            Serializer.register_alias(old_name, cls);
            return cls;
        }
        return decorator;
    }
    return factory;
}

impl _get_schema_builder(name: str) -> Callable[..., any] {
    def builder(*args: any, **kwargs: any) -> any {
        import jaclang.data.schema_rules as _rules;
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

impl _get_jref -> Callable[..., any] {
    return jref;
}

impl jref(id_or_obj: any) -> any {
    if isinstance(id_or_obj, str) {
        return _get_jobj()(id=id_or_obj);
    }
    return id_or_obj;
}

impl _get_jid -> Callable[..., any] {
    return _get_jac().object_ref;
}

impl _get_access_level -> type[AccessLevel] {
    import from jaclang.runtime.constructs { AccessLevel }
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

impl managed(x: any) -> any {
    return x;
}

impl testskip(reason: str = "") -> NoReturn {
    import from unittest { SkipTest }
    raise SkipTest(reason or "skipped");
}

impl testfail(reason: str = "") -> NoReturn {
    raise AssertionError(reason or "explicit failure");
}

impl testraises(*excs: type, `match: (str | None) = None) -> RaisesContext {
    if not excs {
        raise TypeError("testraises() requires at least one exception type");
    }
    for exc in excs {
        if not (isinstance(exc, type) and issubclass(exc, BaseException)) {
            raise TypeError(f"testraises() expects exception types, got {exc!r}");
        }
    }
    return RaisesContext(excs=tuple(excs), pattern=`match);
}

impl RaisesContext.__enter__ -> RaisesContext {
    return self;
}

impl RaisesContext.__exit__(exc_type: any, exc: any, tb: any) -> bool {
    names = ", ".join([e.__name__ for e in self.excs]);
    if exc_type is None {
        raise AssertionError(f"DID NOT RAISE {names}");
    }
    if not issubclass(exc_type, self.excs) {
        return False;
    }
    self.value = exc;
    if (self.pattern is not None) and not self.`match(self.pattern) {
        raise AssertionError(f"pattern {self.pattern!r} does not match {str(exc)!r}");
    }
    return True;
}

impl RaisesContext.`match(regexp: str) -> bool {
    import re;
    return re.search(regexp, str(self.value)) is not None;
}

impl restspec(**specs: any) -> Callable {
    import logging;
    import from jaclang { JacRuntimeInterface as Jac }
    import from jaclang.server.serving.endpoint { HTTPMethod }
    import type from jaclang.server.server { JacAPIServer }
    ServerCls: type[JacAPIServer] = Jac.get_api_server_class();
    SpecsCls = ServerCls.RestSpecs;

    protocol = specs.get('protocol');
    if protocol is not None and not isinstance(protocol, APIProtocol) {
        raw_p = str(protocol).strip().lower();
        try {
            specs['protocol'] = APIProtocol('websocket' if raw_p == 'ws' else raw_p);
        } except ValueError {
            raise ValueError(
                f"@restspec protocol={protocol!r} is not recognized. Expected "
                "APIProtocol.HTTP / WEBHOOK / WEBSOCKET (or the strings "
                "'http', 'webhook', 'websocket'/'ws')."
            );
        }
    }
    method = specs.get('method');
    if method is not None and not isinstance(method, HTTPMethod) {
        try {
            specs['method'] = HTTPMethod(str(method).strip().upper());
        } except ValueError {
            raise ValueError(
                f"@restspec method={method!r} is not routable. Expected one "
                f"of: {', '.join([m.value for m in HTTPMethod])}."
            );
        }
    }

    def decorator(cls: type) -> type {
        spec = SpecsCls(**specs);
        _validate_restspec_target(spec, cls);
        setattr(cls, "restspec", spec);
        return cls;
    }
    return decorator;
}

def _validate_restspec_target(spec: any, target: any) {
    import inspect;
    import logging;
    logger = logging.getLogger(__name__);
    name = getattr(target, '__name__', repr(target));
    is_walker = inspect.isclass(target);
    proto = getattr(spec, 'protocol', APIProtocol.HTTP) or APIProtocol.HTTP;

    if proto == APIProtocol.WEBHOOK and not is_walker {
        raise ValueError(
            f"@restspec(protocol=WEBHOOK) on '{name}': webhook endpoints are "
            "walker-only; a plain def cannot receive webhooks. Use a walker "
            "or drop the webhook protocol."
        );
    }
    if getattr(spec, 'broadcast', False) and proto != APIProtocol.WEBSOCKET {
        raise ValueError(
            f"@restspec(broadcast=True) on '{name}' requires "
            "protocol=WEBSOCKET; broadcast has no meaning on "
            f"{proto} endpoints."
        );
    }
    if proto in (APIProtocol.WEBHOOK, APIProtocol.WEBSOCKET) {
        fixed = '/webhook/{name}' if proto == APIProtocol.WEBHOOK else '/ws';
        if getattr(spec, 'path', '') or getattr(spec, 'method', '') {
            logger.warning(
                f"@restspec on '{name}': path/method are ignored for "
                f"{proto} endpoints; the route is fixed under {fixed}."
            );
        }
    }
    if is_walker
        and (getattr(spec, 'produces', '') or not getattr(spec, 'envelope', True)) {
        logger.warning(
            f"@restspec on '{name}': produces/envelope are ignored on "
            "walkers; walker responses always use the report envelope."
        );
    }
}

impl schedule(**kwargs: any) -> Callable {
    import from jaclang.server.task_scheduler { ScheduleSpec }
    import from jaclang.runtime.builtin { ScheduleTrigger }
    trigger = kwargs.pop("trigger", ScheduleTrigger.STATIC);
    if isinstance(trigger, str) {
        trigger = ScheduleTrigger(trigger);
    }
    spec = ScheduleSpec(trigger=trigger, **kwargs);
    def decorator(target: type) -> type {
        setattr(target, "schedule_spec", spec);
        return target;
    }
    return decorator;
}

impl JacListView.__len__ -> int {
    return self.stop - self.start;
}

impl JacListView.__getitem__(i: any) -> any {
    _n = self.stop - self.start;
    if i < 0 {
        i = i + _n;
    }
    if i < 0 or i >= _n {
        raise IndexError("list index out of range");
    }
    return self.backing[self.start + i];
}

impl JacListView.__setitem__(i: any, v: any) -> None {
    _n = self.stop - self.start;
    if i < 0 {
        i = i + _n;
    }
    if i < 0 or i >= _n {
        raise IndexError("list assignment index out of range");
    }
    self.backing[self.start + i] = v;
}

impl JacListView.__iter__ -> any {
    return iter([self.backing[k] for k in range(self.start, self.stop)]);
}

impl _jac_take_attr(owner: any, name: str) -> any {
    value = getattr(owner, name);
    setattr(owner, name, None);
    return value;
}

impl _jac_take_item(seq: any, key: any) -> any {
    value = seq[key];
    seq[key] = None;
    return value;
}

impl _jac_replace_attr(owner: any, name: str, value: any) -> any {
    old = getattr(owner, name);
    setattr(owner, name, value);
    return old;
}

impl _jac_replace_item(seq: any, key: any, value: any) -> any {
    old = seq[key];
    seq[key] = value;
    return old;
}

impl _jac_swap_places(
    owner_a: any, key_a: any, attr_a: bool, owner_b: any, key_b: any, attr_b: bool
) -> None {
    value_a = getattr(owner_a, key_a) if attr_a else owner_a[key_a];
    value_b = getattr(owner_b, key_b) if attr_b else owner_b[key_b];
    if attr_a {
        setattr(owner_a, key_a, value_b);
    } else {
        owner_a[key_a] = value_b;
    }
    if attr_b {
        setattr(owner_b, key_b, value_a);
    } else {
        owner_b[key_b] = value_a;
    }
}

impl _jac_chunks(xs: any, n: int) -> list {
    if n < 1 {
        n = 1;
    }
    out: list = [];
    i = 0;
    total = len(xs);
    while i < total {
        j = i + n;
        if j > total {
            j = total;
        }
        out.append(JacListView(backing=xs, start=i, stop=j));
        i = j;
    }
    return out;
}

def _is_sized_type_name(name: str) -> bool {
    import from jaclang.runtime.scalars { is_sized }
    return is_sized(name);
}
