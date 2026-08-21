impl JacAccessValidation._resolve_anchor(
    archetype: Archetype
) -> tuple[Anchor, ExecutionContext] {
    anchor = archetype.__jac__;
    jctx = JacRuntimeInterface.get_context();
    mem_anchor = jctx.mem.get(anchor.id);
    if (mem_anchor and (mem_anchor is not anchor)) {
        anchor = mem_anchor;
    }
    return (anchor, jctx);
}

impl JacAccessValidation._check_access(
    to: Anchor, min_level: AccessLevel, operation: str
) -> bool {
    actual = JacRuntimeInterface.check_access_level(to);
    granted = actual.value > min_level.value;
    if not granted {
        logger.info(
            "Current root doesn't have "
                + operation
                + " access to "
                + to.__class__.__name__
                + " "
                + to.archetype.__class__.__name__
                + "["
                + str(to.id)
                + "]"
        );
        if operation != "read" {
            required = AccessLevel(min_level.value + 1);
            diag = PermissionDenied(
                operation=operation,
                target_id=str(to.id),
                target_type=to.archetype.__class__.__name__,
                target_owner=str(to.root) if to.root else None,
                required=required,
                actual=actual
            );
            try {
                ctx = JacRuntimeInterface.get_context();
                ctx.diagnostics.append(diag);
            } except Exception {
                ;
            }
            if JacRuntime.strict_permissions {
                raise PermissionError(diag.message());
            }
            logger.warning(diag.message());
        }
    }
    return granted;
}

impl JacAccessValidation.allow_root(
    archetype: Archetype, root_id: UUID, level: (AccessLevel | int | str | None) = None
) -> None {
    if (level is None) {
        level = AccessLevel.READ;
    }
    level = access_level_cast(level);
    (anchor, jctx) = JacAccessValidation._resolve_anchor(archetype);
    access = anchor.access.roots;
    _root_id = str(root_id);
    if (level != access.anchors.get(_root_id, AccessLevel.NO_ACCESS)) {
        access.anchors[_root_id] = level;
        jctx.mem.put(anchor);
    }
}

impl JacAccessValidation.disallow_root(
    archetype: Archetype, root_id: UUID, level: (AccessLevel | int | str | None) = None
) -> None {
    if (level is None) {
        level = AccessLevel.READ;
    }
    level = access_level_cast(level);
    (anchor, jctx) = JacAccessValidation._resolve_anchor(archetype);
    access = anchor.access.roots;
    access.anchors.pop(str(root_id), None);
    jctx.mem.put(anchor);
}

impl JacAccessValidation.perm_grant(
    archetype: Archetype, level: (AccessLevel | int | str | None) = None
) -> None {
    if (level is None) {
        level = AccessLevel.READ;
    }
    level = access_level_cast(level);
    (anchor, jctx) = JacAccessValidation._resolve_anchor(archetype);
    if (level != anchor.access.all) {
        anchor.access.all = level;
        jctx.mem.put(anchor);
    }
}

impl JacAccessValidation.perm_revoke(archetype: Archetype) -> None {
    (anchor, jctx) = JacAccessValidation._resolve_anchor(archetype);
    if (anchor.access.all.value > AccessLevel.NO_ACCESS.value) {
        anchor.access.all = AccessLevel.NO_ACCESS;
        jctx.mem.put(anchor);
    }
}

impl JacAccessValidation.check_read_access(to: Anchor) -> bool {
    return JacAccessValidation._check_access(to, AccessLevel.NO_ACCESS, "read");
}

impl JacAccessValidation.check_connect_access(
    to: Anchor, op_hint: str = "connect"
) -> bool {
    return JacAccessValidation._check_access(to, AccessLevel.READ, op_hint);
}

impl JacAccessValidation.check_write_access(
    to: Anchor, op_hint: str = "write"
) -> bool {
    return JacAccessValidation._check_access(to, AccessLevel.CONNECT, op_hint);
}

impl JacAccessValidation.check_access_level(
    to: Anchor, no_custom: bool = False
) -> AccessLevel {
    if (not to.persistent or (to.hash == 0)) {
        return AccessLevel.WRITE;
    }
    jctx = JacRuntimeInterface.get_context();
    _jroot = jctx.user_root;
    if (_jroot is None) {
        return AccessLevel.NO_ACCESS;
    }
    jroot: NodeAnchor = _jroot;
    if ((jroot == jctx.system_root) or (jroot.id == to.root) or (jroot == to)) {
        return AccessLevel.WRITE;
    }
    if (
        not no_custom and ((custom_level := to.archetype.__jac_access__()) is not None)
    ) {
        return access_level_cast(custom_level);
    }
    access_level = AccessLevel.NO_ACCESS;
    if ((to_access := to.access).all.value > AccessLevel.NO_ACCESS.value) {
        access_level = to_access.all;
    }
    if (to.root and isinstance((to_root := jctx.mem.get(to.root)), Anchor)) {
        if (to_root.access.all.value > access_level.value) {
            access_level = to_root.access.all;
        }
        if ((level := to_root.access.roots.check(str(jroot.id))) is not None) {
            access_level = level;
        }
    }
    if ((level := to_access.roots.check(str(jroot.id))) is not None) {
        access_level = level;
    }
    return access_level;
}

impl JacWalker.`visit(
    `walker: WalkerArchetype,
    expr:
        (
            list[(NodeArchetype | EdgeArchetype)]
            | list[NodeArchetype]
            | list[EdgeArchetype]
            | NodeArchetype
            | EdgeArchetype
            | GraphQuery
        ),
    insert_loc: int = -1
) -> bool {
    import from jaclang.jac0core.osp_kernel { osp_visit }
    if isinstance(expr, GraphQuery) {
        expr.from_visit = True;
        expr = JacRuntimeInterface.refs(expr);
    }
    if not isinstance(`walker, WalkerArchetype) {
        raise TypeError('Invalid walker object');
    }
    items: list = `list(expr)
        if isinstance(expr, `list)
        else ([expr] if isinstance(expr, (NodeArchetype, EdgeArchetype)) else []);
    targets: list = [];
    for arch in items {
        anchor = arch.__jac__;
        if not isinstance(anchor, (NodeAnchor, EdgeAnchor)) {
            raise ValueError('Anchor should be NodeAnchor or EdgeAnchor.');
        }
        targets.append(anchor);
    }
    return osp_visit(targets, insert_loc);
}

impl JacWalker.spawn_call(
    `walker: WalkerAnchor, nd: (NodeAnchor | EdgeAnchor)
) -> WalkerArchetype {
    import from jaclang.jac0core.osp_kernel { osp_spawn }
    import from jaclang.jac0core.osp_kernel_sv { desc_for, make_sv_runtime }
    warch = `walker.archetype;
    osp_spawn(make_sv_runtime(), warch, desc_for(`type(warch)), `list(`walker.next));
    return warch;
}

impl JacWalker.async_spawn_call(
    `walker: WalkerAnchor, nd: (NodeAnchor | EdgeAnchor)
) -> WalkerArchetype {
    import from jaclang.jac0core.osp_kernel_sv {
        osp_spawn_async,
        desc_for,
        make_sv_runtime
    }
    warch = `walker.archetype;
    await osp_spawn_async(
        make_sv_runtime(), warch, desc_for(`type(warch)), `list(`walker.next)
    );
    return warch;
}

impl JacWalker.`spawn(
    op1: (Archetype | list[Archetype]), op2: (Archetype | list[Archetype])
) -> (WalkerArchetype | Coroutine) {
    def collect_targets(
        `walker: WalkerAnchor, items: list[Archetype]
    ) -> (NodeAnchor | EdgeAnchor) {
        for i in items {
            a = i.__jac__;
            `walker.next.append(a) if isinstance(a, (NodeAnchor, EdgeAnchor)) else None;
            if (isinstance(a, EdgeAnchor) and a.target) {
                `walker.next.append(a.target);
            }
        }
        return `walker.next[0];
    }
    def assign(
        `walker: WalkerAnchor, t: (Archetype | list[Archetype])
    ) -> (NodeAnchor | EdgeAnchor) {
        if isinstance(t, NodeArchetype) {
            nd = t.__jac__;
            `walker.next = [nd];
            return nd;
        } elif isinstance(t, EdgeArchetype) {
            `edge = t.__jac__;
            `walker.next = [`edge, `edge.target];
            return `edge;
        } elif (
            isinstance(t, `list)
            and all(isinstance(i, (NodeArchetype, EdgeArchetype)) for i in t)
        ) {
            return collect_targets(`walker, t);
        } else {
            raise TypeError('Invalid target object');
        }
    }
    if isinstance(op1, WalkerArchetype) {
        (warch, targ) = (op1, op2);
    } elif isinstance(op2, WalkerArchetype) {
        (warch, targ) = (op2, op1);
    } else {
        raise TypeError('Invalid walker object');
    }
    `walker: WalkerAnchor = warch.__jac__;
    loc: (NodeAnchor | EdgeAnchor) = assign(`walker, targ);
    if warch.__jac_async__ {
        return JacRuntimeInterface.async_spawn_call(`walker=`walker, nd=loc);
    }
    return JacRuntimeInterface.spawn_call(`walker=`walker, nd=loc);
}

impl JacWalker.`disengage(`walker: WalkerArchetype) -> bool {
    import from jaclang.jac0core.osp_kernel { osp_disengage }

    `walker.__jac__.disengaged = True;
    osp_disengage();
    return True;
}

impl JacBuiltin.printgraph(
    nd: NodeArchetype,
    depth: int,
    traverse: bool,
    edge_type: (list[str] | None),
    bfs: bool,
    edge_limit: int,
    node_limit: int,
    file: (str | None),
    format: str
) -> str {
    import from jaclang.runtimelib.utils { traverse_graph }
    edge_type = edge_type or [];
    visited_nodes: list[NodeArchetype] = [];
    node_depths: dict[(NodeArchetype, int)] = {nd: 0};
    queue: list[tuple[NodeArchetype, int]] = [(nd, 0)];
    connections: list[tuple[(NodeArchetype, NodeArchetype, EdgeArchetype)]] = [];
    """Depth first search.""";
    def dfs(nd: NodeArchetype, cur_depth: int) {
        if (nd not in visited_nodes) {
            visited_nodes.append(nd);
            traverse_graph(
                nd,
                cur_depth,
                depth,
                edge_type,
                traverse,
                connections,
                node_depths,
                visited_nodes,
                queue,
                bfs,
                dfs,
                node_limit,
                edge_limit
            );
        }
    }
    if bfs {
        cur_depth = 0;
        while queue {
            (current_node, cur_depth) = queue.pop(0);
            if (current_node not in visited_nodes) {
                visited_nodes.append(current_node);
                traverse_graph(
                    current_node,
                    cur_depth,
                    depth,
                    edge_type,
                    traverse,
                    connections,
                    node_depths,
                    visited_nodes,
                    queue,
                    bfs,
                    dfs,
                    node_limit,
                    edge_limit
                );
            }
        }
    } else {
        dfs(nd, cur_depth=0);
    }
    dot_content = 'digraph {\nnode [style="filled", shape="ellipse", fillcolor="invis", fontcolor="black"];\n';
    mermaid_content = 'flowchart LR\n';
    for (source, target, `edge) in connections {
        edge_label = html.escape(str(`edge.__jac__.archetype));
        dot_content += (
            f"{visited_nodes.index(source)} -> {visited_nodes.index(target)} "
            + f'[label="{edge_label if "GenericEdge" not in edge_label else ""}"];\n'
        );
        if (('GenericEdge' in edge_label) or not edge_label.strip()) {
            mermaid_content += (
                f"{visited_nodes.index(source)} -->{visited_nodes.index(target)}\n"
            );
        } else {
            mermaid_content += (
                f'{visited_nodes.index(source)} -->|"{edge_label}"| {visited_nodes.index(
                    target
                )}\n'
            );
        }
    }
    for node_ in visited_nodes {
        color = colors[node_depths[node_]] if (node_depths[node_] < 25) else colors[24];
        label = html.escape(str(node_.__jac__.archetype));
        dot_content += (
            f'{visited_nodes.index(node_)} [label="{label}"fillcolor="{color}"];\n'
        );
        mermaid_content += f'{visited_nodes.index(node_)}["{label}"]\n';
    }
    output = (dot_content + '}') if (format == 'dot') else mermaid_content;
    if file {
        with open(file, 'w') as f {
            f.write(output);
        }
    }
    return output;
}


impl JacCmd.run_ai_agent(req: object) -> int {
    try {
        import from jaclang.cli.ai_agent { run_agent }
    } except ImportError {
        import from jaclang.cli.console { console }
        console.error(
            "`jac ai` needs the byLLM plugin, which is not installed.",
            hint="Install it with:  pip install byllm"
        );
        return 1;
    }
    return run_agent(req);
}

impl JacContext.get_context -> ExecutionContext {
    ctx = _request_context.get();
    if ctx is not None {
        return ctx;
    }

    ctx = JacRuntime.exec_ctx;
    if ctx is None {
        ctx = JacRuntimeInterface.create_j_context(user_root=None);
        JacRuntime.exec_ctx = ctx;
    }
    return ctx;
}

impl JacPersistence.commit(anchor: Anchor | Archetype | None = None) -> None {
    if isinstance(anchor, Archetype) {
        anchor = anchor.__jac__;
    }
    ctx = JacRuntimeInterface.get_context();
    ctx.mem.commit(anchor);
    ctx.run_pending_effects();
}

impl JacPersistence.acommit(anchor: Anchor | Archetype | None = None) -> None {
    if isinstance(anchor, Archetype) {
        anchor = anchor.__jac__;
    }
    ctx = JacRuntimeInterface.get_context();
    await ctx.mem.acommit(anchor);
    ctx.run_pending_effects();
}

impl JacPersistence.on_commit(callback: Callable) -> None {
    JacRuntimeInterface.get_context().on_commit(callback);
}

impl JacContext.reset_graph(root_node: (Root | None) = None) -> int {
    ctx = JacRuntimeInterface.get_context();
    mem = ctx.mem;
    ranchor = root_node.__jac__ if root_node else ctx.user_root;
    deleted_count = 0;
    deleted_ids: set[UUID] = `set();
    cand_map: dict = {};
    store = mem?.store;
    if store is not None {
        mem.read_barrier();
        for row in store.rows("SELECT id, root_id FROM anchors", {}) {
            cand_map[UUID(str(row[0]))] = str(row[1]) if row[1] else None;
        }
    }
    for anchor in mem.get_mem().values() {
        cand_map[anchor.id] = str(anchor.root) if anchor.root else None;
    }
    candidates = list(cand_map.items());
    import from jaclang.jac0core.osp_graph_sv { sv_forget_by_id }
    for (aid, aroot) in candidates {
        if ((aid == ranchor.id) or (aroot != str(ranchor.id))) {
            continue;
        }
        deleted_ids.add(aid);
        mem.delete(aid);
        sv_forget_by_id(aid, mem);
        deleted_count += 1;
    }
    ranchor.edges = [
        e
        for e in ranchor.edges
        if (e.id not in deleted_ids)
    ];
    mem.commit(ranchor);
    return deleted_count;
}

impl JacPersistence.get_object(id: str) -> (Archetype | None) {
    if (id == 'root') {
        return JacRuntimeInterface.get_context().user_root.archetype;
    } elif (`obj := JacRuntimeInterface.get_context().mem.get(UUID(id))) {
        if not JacRuntimeInterface.check_read_access(`obj) {
            return None;
        }
        return `obj.archetype;
    }
    return None;
}

impl JacPersistence.aget_object(id: str) -> (Archetype | None) {
    if (id == 'root') {
        return JacRuntimeInterface.get_context().user_root.archetype;
    }
    `obj = await JacRuntimeInterface.get_context().mem.aget(UUID(id));
    if `obj is not None {
        if not JacRuntimeInterface.check_read_access(`obj) {
            return None;
        }
        return `obj.archetype;
    }
    return None;
}

impl JacPersistence.object_ref(`obj: Archetype) -> str {
    anchor = `obj.__jac__;
    if isinstance(anchor, ObjectAnchor) {
        try {
            JacRuntimeInterface.get_context().mem.put(anchor);
        } except Exception as e {
            logger.warning(f"object_ref: failed to register anchor in memory: {e}");
        }
    }
    return anchor.id.hex;
}

impl JacArchetype.make_archetype(cls: type[Archetype]) -> type[Archetype] {
    entries: OrderedDict[(str, ObjectSpatialFunction)] = OrderedDict(
        (fn.name, fn) for fn in cls._jac_entry_funcs_
    );
    exits: OrderedDict[(str, ObjectSpatialFunction)] = OrderedDict(
        (fn.name, fn) for fn in cls._jac_exit_funcs_
    );
    for func in cls.__dict__.values() {
        if callable(func) and (func?.__jac_entry or func?.__jac_exit) {
            dsfunc = JacRuntimeInterface.DSFunc(
                func.__name__, func, func.__jac_trigger__
            )
                if func?.__jac_trigger__
                else JacRuntimeInterface.DSFunc(func.__name__, func);
            if func?.__jac_entry {
                entries[func.__name__] = dsfunc;
            }
            if func?.__jac_exit {
                exits[func.__name__] = dsfunc;
            }
        }
    }
    cls._jac_entry_funcs_ = [*entries.values()];
    cls._jac_exit_funcs_ = [*exits.values()];
    if issubclass(cls, WalkerArchetype)
        and 'reports' not in cls.__dict__.get('__annotations__', {}) {
        if not hasattr(cls, '__annotations__') {
            cls.__annotations__ = {};
        }
        cls.__annotations__['reports'] = list;
        cls.reports = dataclasses.field(
            default_factory=`list, init=False, repr=False, compare=False
        );
    }
    if cls.__dict__.get('__annotations__', {}) {
        dataclass(eq=False)(cls);
    } else {
        dataclass(eq=False, init=False)(cls);
    }
    return cls;
}

impl JacModule.impl_patch_filename(
    file_loc: str
) -> Callable[([Callable[(P, T)]], Callable[(P, T)])] {
    def decorator(func: Callable[(P, T)]) -> Callable[(P, T)] {
        try {
            code = func.__code__;
            new_code = types.CodeType(
                code.co_argcount,
                code.co_posonlyargcount,
                code.co_kwonlyargcount,
                code.co_nlocals,
                code.co_stacksize,
                code.co_flags,
                code.co_code,
                code.co_consts,
                code.co_names,
                code.co_varnames,
                file_loc,
                code.co_name,
                code.co_qualname,
                code.co_firstlineno,
                code.co_linetable,
                code.co_exceptiontable,
                code.co_freevars,
                code.co_cellvars
            );
            func.__code__ = new_code;
        } except AttributeError {
            ;
        }
        return func;
    }
    return decorator;
}

impl JacModule.jac_import(
    target: str,
    base_path: str,
    absorb: bool = False,
    override_name: (str | None) = None,
    items: (dict[(str, str | str | None)] | None) = None,
    reload_module: (bool | None) = False,
    lng: (str | None) = None
) -> tuple[(types.ModuleType, ...)] {
    import importlib;
    import importlib.util;
    if (lng is None) {
        lng = infer_language(target, base_path);
    }
    _ = JacRuntime.get_program();
    if target.startswith('.') {
        caller_dir = base_path
            if os.path.isdir(base_path)
            else os.path.dirname(base_path);
        chomp_target = target;
        while chomp_target.startswith('.') {
            if ((len(chomp_target) > 1) and (chomp_target[1] == '.')) {
                caller_dir = os.path.dirname(caller_dir);
                chomp_target = chomp_target[1:];
            } else {
                chomp_target = chomp_target[1:];
                break;
            }
        }
        module_name = chomp_target;
    } else {
        module_name = target;
    }
    caller_dir = base_path if os.path.isdir(base_path) else os.path.dirname(base_path);

    project_root = find_jac_project_root(caller_dir);
    roots_to_add = [];
    for d in [caller_dir, project_root] {
        if (d and (d not in sys.path) and (d not in roots_to_add)) {
            roots_to_add.append(d);
        }
    }
    original_path = None;
    if roots_to_add {
        original_path = sys.path.copy();
        for d in reversed(roots_to_add) {
            sys.path.insert(0, d);
        }
    }

    pushed_base = bool(caller_dir);
    if pushed_base {
        push_import_base(caller_dir);
    }
    try {
        if (override_name == '__main__') {
            import from jaclang.meta_importer { JacMetaImporter }
            finder = JacMetaImporter();
            spec = finder.find_spec(module_name, None);
            if (
                spec and spec.origin and spec.origin.endswith('.jac') and (lng == 'py')
            ) {
                spec = None;
            }
            if ((not spec or not spec.origin) and (lng == 'py')) {
                file_path = os.path.join(caller_dir, f"{module_name}.py");
                if os.path.isfile(file_path) {
                    spec_name = '__main__'
                        if (override_name == '__main__')
                        else module_name;
                    spec = importlib.util.spec_from_file_location(spec_name, file_path);
                }
            }
            if (not spec or not spec.origin) {
                raise ImportError(f"Cannot find module {module_name}");
            }
            if (('__main__' in sys.modules) and not reload_module) {
                module = sys.modules['__main__'];
                to_keep = {
                    k: v
                    for (k, v) in module.__dict__.items()
                    if k.startswith('__')
                };
                module.__dict__.update(to_keep);
            } else {
                module = types.ModuleType('__main__');
                sys.modules['__main__'] = module;
            }
            module.__file__ = spec.origin;
            module.__name__ = '__main__';
            module.__spec__ = spec;
            if spec.submodule_search_locations {
                module.__path__ = spec.submodule_search_locations;
            }
            JacRuntimeInterface.load_module('__main__', module);

            if (spec.origin and spec.origin.endswith('.py')) {
                codeobj = JacRuntime.get_compiler().get_bytecode(
                    full_target=spec.origin, target_program=JacRuntime.get_program()
                );
                if codeobj {
                    exec(codeobj, module.__dict__);
                } elif spec.loader {
                    spec.loader.exec_module(module);
                }
            } elif spec.loader {
                spec.loader.exec_module(module);
            }
        } elif (reload_module and (module_name in sys.modules)) {
            module = importlib.reload(sys.modules[module_name]);
            JacRuntimeInterface.load_module(module_name, module, force=True);
        } else {
            module = importlib.import_module(module_name);
            JacRuntimeInterface.load_module(
                module_name, module, force=bool(reload_module)
            );
        }
        if items {
            imported_items = [];
            for (item_name, _) in items.items() {
                if hasattr(module, item_name) {
                    item = getattr(module, item_name);
                    imported_items.append(item);
                } else {
                    raise ImportError(
                        f"Cannot import name '{item_name}' from '{module_name}'"
                    );
                }
            }
            return `tuple(imported_items) if not absorb else (module, );
        }
        return (module, );
    } finally {
        if pushed_base {
            pop_import_base();
        }
        if (original_path is not None) {
            sys.path[:] = original_path;
        }
    }
}

impl JacTest.jac_test(description: str = "") -> Callable {
    import from jaclang.runtimelib.test { JacTestCheck }
    def decorator(test_fun: Callable) -> Callable {
        file_path = getfile(test_fun);
        func_name = test_fun.__name__;
        def test_deco {
            test_fun();
        }
        test_deco.__name__ = test_fun.__name__;
        JacTestCheck.add_test(
            file_path, func_name, test_deco, display_name=description
        );
        return test_deco;
    }
    return decorator;
}

impl JacBuiltin.jsx(
    tag: object,
    attributes: (Mapping[(str, object)] | None) = None,
    children: (Sequence[object] | None) = None
) -> JsxElement {
    `props: dict[(str, object)] = `dict(attributes) if attributes else {};
    child_list = `list(children) if children else [];
    return JsxElement(tag=tag, `props=`props, children=child_list);
}

impl JacTest.run_test(
    filepath: str,
    func_name: (str | None) = None,
    filter: (str | None) = None,
    xit: bool = False,
    maxfail: (int | None) = None,
    directory: (str | None) = None,
    verbose: bool = False
) -> int {
    import from jaclang.runtimelib.test { JacTestCheck }
    import from jaclang.runtimelib.cl_test_runner {
        is_cl_test_file,
        is_cl_test_file_for_discovery,
        run_cl_test_file,
        register_results_into_jactestcheck
    }
    import from jaclang.jac0core.ext_registry { base_stem, is_annex }
    test_file = False;
    ret_count = 0;
    if filepath {
        if is_cl_test_file(filepath) {
            JacTestCheck.reset();
            results = run_cl_test_file(filepath, test_name=func_name);
            register_results_into_jactestcheck(os.path.abspath(filepath), results);
            JacTestCheck.run_test(
                xit, maxfail, verbose, os.path.abspath(filepath), func_name
            );
            ret_count = JacTestCheck.failcount;
        } elif filepath.endswith('.jac') {
            (base, mod_name) = os.path.split(filepath);
            base = base or './';
            mod_name = base_stem(mod_name);
            JacTestCheck.reset();
            JacRuntimeInterface.jac_import(target=mod_name, base_path=base);
            JacTestCheck.run_test(
                xit, maxfail, verbose, os.path.abspath(filepath), func_name
            );
            ret_count = JacTestCheck.failcount;
        } else {
            JacRuntimeInterface.get_console().error('Not a .jac file.');
        }
    } else {
        directory = directory or os.getcwd();
    }
    if (filter or directory) {
        current_dir = directory or os.getcwd();
        for (root_dir, dirs, files) in os.walk(current_dir, topdown=True) {
            dirs[:] = [
                d
                for d in dirs
                if not (d.startswith('.') or d == '__pycache__')
            ];
            files = [
                file
                for file in files
                if fnmatch.fnmatch(file, filter)
            ]
                if filter
                else files;
            files = [
                file
                for file in files
                if not is_annex(file)
            ];
            for file in files {
                if is_cl_test_file_for_discovery(os.path.join(root_dir, file)) {
                    test_file = True;
                    cl_path = os.path.join(root_dir, file);
                    JacRuntimeInterface.get_console().info(
                        f"\n\n\t\t* Inside {root_dir}/{file} *"
                    );
                    JacTestCheck.reset();
                    register_results_into_jactestcheck(
                        os.path.abspath(cl_path),
                        run_cl_test_file(cl_path, test_name=func_name)
                    );
                    JacTestCheck.run_test(
                        xit, maxfail, verbose, os.path.abspath(file), func_name
                    );
                } elif file.endswith('.jac') {
                    test_file = True;
                    JacRuntimeInterface.get_console().info(
                        f"\n\n\t\t* Inside {root_dir}/{file} *"
                    );
                    JacTestCheck.reset();
                    mod_target = base_stem(file);
                    JacRuntimeInterface.jac_import(
                        target=mod_target, base_path=root_dir
                    );
                    JacTestCheck.run_test(
                        xit, maxfail, verbose, os.path.abspath(file), func_name
                    );
                }
                if (JacTestCheck.breaker and (xit or maxfail)) {
                    break;
                }
            }
            if (JacTestCheck.breaker and (xit or maxfail)) {
                break;
            }
        }
        JacTestCheck.breaker = False;
        ret_count += JacTestCheck.failcount;
        JacTestCheck.failcount = 0;
        if not test_file {
            JacRuntimeInterface.get_console().warning('No test files found.');
        }
    }
    return ret_count;
}

impl JacArchetype.field(
    factory: (Callable[([], T)] | None) = None, `init: bool = True
) -> T {
    if factory {
        return field(default_factory=factory);
    }
    return field(`init=`init);
}


impl JacBuiltin.log_report(expr: any, custom: bool = False) -> None {
    import from jaclang.jac0core.osp_kernel { osp_report, _current_scope }
    if custom {
        JacRuntimeInterface.get_context().custom = expr;
    } else {
        JacRuntimeInterface.get_console().print(expr);
        if _current_scope() is not None {
            osp_report(expr);
        } else {
            cs = JacRuntimeInterface.get_context().call_state.get(None);
            if cs is not None {
                cs.reports.put_nowait(expr);
            }
        }
    }
}

impl JacGraph.refs(
    path: GraphQuery | NodeArchetype | list[NodeArchetype], slc: (slice | None) = None
) -> list[NodeArchetype] | list[EdgeArchetype] | list[(NodeArchetype | EdgeArchetype)] {
    if not isinstance(path, GraphQuery) {
        path = GraphQuery(path, hops=[QHop(dir=EdgeDir.OUT.value)]);
    }
    import from jaclang.runtimelib.query_planner { resolve_query, resolve_query_edges }
    ctx = JacRuntimeInterface.get_context();
    ctx.note_traversal_reads([nd.__jac__ for nd in path.origin]);
    if slc is not None and path.slc is None {
        path.slc = slc;
    }
    planned = (
        resolve_query_edges(ctx.mem, path)
            if path.edges_only
            else resolve_query(ctx.mem, path)
    );
    return [
        a.archetype
        for a in planned
        if a.archetype is not None
    ];
}

impl JacGraph.arefs(path: GraphQuery | NodeArchetype | list[NodeArchetype]) -> None {
    ;
}


impl JacGraph.filter_on(
    items: list[Archetype], func: Callable[([Archetype], bool)]
) -> list[Archetype] {
    return [
        item
        for item in items
        if func(item)
    ];
}

impl JacGraph.connect(
    left: (NodeArchetype | list[NodeArchetype]),
    right: (NodeArchetype | list[NodeArchetype]),
    `edge: type[EdgeArchetype] | EdgeArchetype | None = None,
    undir: bool = False,
    conn_assign: (tuple[(tuple, tuple)] | None) = None,
    edges_only: bool = False
) -> (NodeArchetype | list[NodeArchetype] | list[EdgeArchetype]) {
    left = [left] if isinstance(left, NodeArchetype) else left;
    right_is_node = isinstance(right, NodeArchetype);
    right = [right] if right_is_node else right;
    edges = [];
    for i in left {
        _left = i.__jac__;
        if JacRuntimeInterface.check_connect_access(_left, op_hint="edge_write") {
            for j in right {
                _right = j.__jac__;
                if JacRuntimeInterface.check_connect_access(
                    _right, op_hint="edge_write"
                ) {
                    edges.append(
                        JacRuntimeInterface.build_edge(
                            is_undirected=undir,
                            conn_type=`edge,
                            conn_assign=conn_assign
                        )(
                            _left, _right
                        )
                    );
                }
            }
        }
    }
    if edges_only {
        return edges;
    }

    return right[0] if right_is_node else right;
}

impl JacGraph.disconnect(
    left: (NodeArchetype | list[NodeArchetype]),
    right: (NodeArchetype | list[NodeArchetype]),
    dir: EdgeDir = EdgeDir.OUT,
    filter: (Callable[([EdgeArchetype], bool)] | None) = None
) -> bool {
    import from jaclang.jac0core.osp_graph_sv {
        sv_candidate_edges_between,
        sv_register_hydrated
    }
    disconnect_occurred = False;
    left = [left] if isinstance(left, NodeArchetype) else left;
    right = [right] if isinstance(right, NodeArchetype) else right;
    for i in left {
        nd = i.__jac__;
        for stub in `set(nd.edges) {
            if not stub.is_populated() {
                stub.populate();
            }
        }
        sv_register_hydrated(nd);
        handled: set = set();
        for j in right {
            for anchor in sv_candidate_edges_between(nd, j.__jac__, dir.value) {
                if anchor.id in handled {
                    continue;
                }
                handled.add(anchor.id);
                if (
                    (source := anchor.source)
                    and (target := anchor.target)
                    and (not filter or filter(anchor.archetype))
                    and source.archetype
                    and target.archetype
                ) {
                    other = target if source.id == nd.id else source;
                    if JacRuntimeInterface.check_connect_access(
                        other, op_hint="edge_delete"
                    ) {
                        JacRuntimeInterface.destroy([anchor])
                            if anchor.persistent
                            else anchor.detach();
                        disconnect_occurred = True;
                    }
                }
            }
        }
    }
    return disconnect_occurred;
}

impl JacGraph.assign_all(
    target: list[T], attr_val: tuple[(tuple[str], tuple[any])]
) -> list[T] {
    for `obj in target {
        (attrs, values) = attr_val;
        for (attr, value) in zip(attrs, values, strict=False) {
            setattr(`obj, attr, value);
        }
    }
    return target;
}

impl JacBuiltin.safe_subscript(`obj: any, key: any) -> any {
    try {
        return `obj[key];
    } except (KeyError, IndexError, TypeError) {
        return None;
    }
}

impl JacGraph.`root -> Root {
    return JacRuntime.get_context().get_root();
}

impl JacGraph.get_all_root -> list[Root] {
    jmem = JacRuntimeInterface.get_context().mem;
    return `list(jmem.get_roots());
}

impl JacGraph.build_edge(
    is_undirected: bool,
    conn_type: type[EdgeArchetype] | EdgeArchetype | None,
    conn_assign: (tuple[(tuple, tuple)] | None)
) -> Callable[([NodeAnchor, NodeAnchor], EdgeArchetype)] {
    ct = conn_type or GenericEdge;
    def builder(source: NodeAnchor, target: NodeAnchor) -> EdgeArchetype {
        import from jaclang.jac0core.osp_graph_sv { sv_conn }
        `edge = ct() if isinstance(ct, `type) else ct;
        eanch = `edge.__jac__=EdgeAnchor(
            archetype=`edge, source=source, target=target, is_undirected=is_undirected
        );
        source.edges.append(eanch);
        target.edges.append(eanch);
        sv_conn(source, target, eanch, is_undirected);
        if conn_assign {
            for (fld, val) in zip(conn_assign[0], conn_assign[1], strict=False) {
                if hasattr(`edge, fld) {
                    setattr(`edge, fld, val);
                } else {
                    raise ValueError(f"Invalid attribute: {fld}");
                }
            }
        }
        if (source.persistent or target.persistent) {
            JacRuntimeInterface.save(eanch);
        }
        return `edge;
    }
    return builder;
}

impl JacPersistence.save(`obj: (Archetype | Anchor)) -> None {
    anchor = `obj.__jac__ if isinstance(`obj, Archetype) else `obj;
    jctx = JacRuntimeInterface.get_context();
    if (not anchor.persistent and not anchor.root) {
        anchor.persistent = True;
        anchor.root = jctx.user_root.id;
    }
    jctx.mem.put(anchor);
    match anchor {
        case NodeAnchor():
            for ed in anchor.edges {
                if (ed.is_populated() and not ed.persistent) {
                    JacRuntimeInterface.save(ed);
                }
            }

        case EdgeAnchor():
            if ((src := anchor.source) and src.is_populated() and not src.persistent) {
                JacRuntimeInterface.save(src);
            }
            if ((trg := anchor.target) and trg.is_populated() and not trg.persistent) {
                JacRuntimeInterface.save(trg);
            }

        case _:
            ;

    }
}

impl JacPersistence.destroy(
    objs: Archetype | Anchor | list[(Archetype | Anchor)]
) -> None {
    obj_list = objs if isinstance(objs, `list) else [objs];
    for `obj in obj_list {
        if not isinstance(`obj, (Archetype, Anchor)) {
            return;
        }
        anchor = `obj.__jac__ if isinstance(`obj, Archetype) else `obj;
        if JacRuntimeInterface.check_write_access(anchor, op_hint="delete") {
            match anchor {
                case NodeAnchor():
                    for `edge in anchor.edges[:] {
                        `edge.detach();
                        JacRuntimeInterface.get_context().mem.delete(`edge.id);
                    }

                case EdgeAnchor():
                    anchor.detach();

                case _:
                    ;

            }
            JacRuntimeInterface.get_context().mem.delete(anchor.id);
        }
    }
}

impl JacArchetype.on_entry(func: Callable) -> Callable {
    setattr(func, '__jac_entry', True);
    return func;
}

impl JacArchetype.on_exit(func: Callable) -> Callable {
    setattr(func, '__jac_exit', True);
    return func;
}

impl JacArchetype.set_trigger(
    trigger_thunk: Callable
) -> Callable[([Callable], Callable)] {
    def deco(func: Callable) -> Callable {
        setattr(func, '__jac_trigger__', trigger_thunk);
        return func;
    }
    return deco;
}

impl JacServe.get_client_bundle_builder -> ClientBundleBuilder {
    import from jaclang.runtimelib.client.vite_client_bundle {
        make_client_bundle_builder
    }
    return make_client_bundle_builder();
}

impl JacServe.build_client_bundle(
    module: types.ModuleType, force: bool = False
) -> ClientBundle {
    builder = JacRuntimeInterface.get_client_bundle_builder();
    return builder.build(module, force=force);
}

impl JacServe.format_build_error(
    error_output: str, project_dir: Path, config: object = None
) -> str {
    import from jaclang.runtimelib.client.serving { JacClient }
    return JacClient.format_build_error(error_output, project_dir, config);
}

impl JacBuiltin.get_console -> ConsoleImpl {
    import from jaclang.cli.console { JacConsole }
    return JacConsole();
}

impl JacServe.get_api_server_class -> type {
    _sp = _scale_provider();
    if _sp is not None {
        _scaled = _sp.get_api_server_class();
        if _scaled is not None {
            return _scaled;
        }
    }
    import from jaclang.runtimelib.server { JacAPIServer }
    return JacAPIServer;
}

impl JacServe.ensure_sv_service(module_name: str, base_path: str) -> None {
    _sp = _scale_provider();
    if _sp is not None {
        _sp.ensure_sv_service(module_name, base_path);
        return;
    }
    import os;
    import time;
    import urllib.request;
    import from jaclang.runtimelib { sv_client }
    import from jaclang.runtimelib.server { JacAPIServer as CoreJacAPIServer }
    import from jaclang.runtimelib.serving.server { ServingServer }
    if module_name in sv_client._registry {
        return;
    }
    import from jaclang.jac0core.sv_service_host { resolve_sv_service_host }
    import from jaclang.jac0core.host { HOST_BUN, HOST_TEST }
    import from jaclang.runtimelib.test_sv_host { prepare_test_sv_service, get_test_adapter }
    import from jaclang.runtimelib.bun_sv_spawn { spawn_bun_sv_service }
    import from pathlib { Path }
    host_kind = resolve_sv_service_host(module_name, base_path);
    if host_kind == HOST_TEST {
        if get_test_adapter(module_name) is not None {
            sv_client.register(module_name, f"test://{module_name}");
            return;
        }
        module_file = str(Path(base_path) / f"{module_name}.jac");
        base_url = prepare_test_sv_service(module_name, module_file, base_path);
        sv_client.register(module_name, base_url);
        return;
    }
    if host_kind == HOST_BUN {
        base_port = 18000 + (hash(module_name) % 1000);
        spawn_result = spawn_bun_sv_service(
            module_name, base_path, base_port
        );
        base_url = spawn_result.base_url;
        sv_client.register(module_name, base_url);
        return;
    }
    base_port = 18000 + (hash(module_name) % 1000);

    srv = CoreJacAPIServer(
        module_name=module_name, port=0, base_path=base_path, is_sv_sibling=True
    );
    srv.load_module();
    serving = ServingServer(app=srv.build_app(), host='127.0.0.1', port=base_port);
    serving.serve_background(port_retries=100);
    port = serving.bound_port;
    srv.port = port;
    srv.server = serving;
    base_url = f"http://127.0.0.1:{port}";
    import from jaclang.scale.runtime.context.util { wait_for_health }
    healthy = wait_for_health(
        base_url, lambda { serving.bound_port > 0; }, timeout=10.0, poll_interval=0.05
    );
    if not healthy {
        raise RuntimeError(
            f"sv-to-sv service '{module_name}' did not become healthy at {base_url}"
        );
    }
    sv_client.register(module_name, base_url);
}

impl JacServe.sv_service_call(module_name: str, func_name: str, args: dict) -> any {
    import from jaclang.scale.runtime.rpc.rpc { service_call }
    return service_call(module_name, func_name, args);
}

impl JacServe.sv_walker_call(
    module_name: str, walker_name: str, args: dict, stub_cls: any
) -> any {
    import from jaclang.scale.runtime.rpc.rpc { walker_call }
    return walker_call(module_name, walker_name, args, stub_cls);
}


impl JacServe.get_sv_registry -> dict[str, str] {
    _sp = _scale_provider();
    if _sp is not None {
        return _sp.get_sv_registry();
    }
    import from jaclang.runtimelib { sv_client }
    return dict(sv_client._registry);
}

impl JacServe.create_server(
    jac_server: JacServer, host: str, port: int, max_retries: int = 10
) -> any {
    _sp = _scale_provider();
    if _sp is not None {
        _scaled = _sp.create_server(jac_server, host, port);
        if _scaled is not None {
            return _scaled;
        }
    }
    raise RuntimeError(
        "create_server is retired: JacAPIServer.start binds the Jac-native "
        "serving core directly"
    );
}

impl JacServe.render_page(
    introspector: ModuleIntrospector,
    function_name: str,
    args: dict[(str, any)],
    username: str
) -> dict[(str, any)] {
    import from jaclang.runtimelib.client.serving { JacClient }
    return JacClient.render_page(introspector, function_name, args, username);
}

impl JacServe.get_client_js(introspector: ModuleIntrospector) -> str {
    import from jaclang.runtimelib.client.serving { JacClient }
    return JacClient.get_client_js(introspector);
}

impl JacLLM.get_mtir(
    caller: Callable,
    args: dict[((int | str), object)],
    call_params: dict[(str, object)]
) -> MTRuntime {
    import from jaclang.jac0core.mtp { fetch_mtir }
    import from jaclang.byllm.mtir { MTIR }
    return MTIR(caller, args, call_params, fetch_mtir(caller)).runtime;
}

impl JacLLM.`sem(semstr: str, inner_semstr: dict[(str, str)]) -> Callable {
    def decorator(`obj: object) -> object {
        setattr(`obj, '_jac_semstr', semstr);
        setattr(`obj, '_jac_semstr_inner', inner_semstr);
        return `obj;
    }
    return decorator;
}

impl JacLLM.call_llm(model: LLMModel, mt_run: MTRuntime) -> any {
    return model.invoke(mt_run=mt_run);
}

impl JacLLM.acall_llm(model: LLMModel, mt_run: MTRuntime) -> any {
    return await model.ainvoke(mt_run=mt_run);
}

impl JacLLM.`by(model: LLMModel) -> Callable {
    def _decorator(caller: Callable) -> Callable {
        def _wrapped_caller(*args: object, **kwargs: object) -> object {
            import from jaclang.jac0core.mtp { fetch_mtir }
            import from jaclang.byllm.mtir { MTIR }
            invoke_args: dict[((int | str), object)] = {};
            for (i, arg) in enumerate(args) {
                invoke_args[i] = arg;
            }
            for (key, value) in kwargs.items() {
                invoke_args[key] = value;
            }
            mt_run = MTIR(
                caller, invoke_args, model.call_params, fetch_mtir(caller)
            ).runtime;
            return model.invoke(mt_run=mt_run);
        }
        return _wrapped_caller;
    }
    return _decorator;
}

impl JacLLM.by_operator(lhs: any, rhs: any) -> any {
    import from jaclang.byllm.llm { BaseLLM }
    import from jaclang.jac0core.archetype { NodeArchetype, EdgeArchetype }

    lhs_list = lhs if isinstance(lhs, list) else [lhs];
    if all(isinstance(element, (NodeArchetype, EdgeArchetype)) for element in lhs_list)
        and isinstance(rhs, BaseLLM) {
        import from jaclang.byllm.visit_routing { route_visit }
        return route_visit(lhs_list, rhs);
    }
    raise NotImplementedError(
        "The 'by' operator requires visitable nodes on the left and an LLM model on the right."
    );
}

impl JacLLM.default_llm -> LLMModel {
    import os;
    _cache = JacLLM?._default_llm_instance;
    if (_cache is not None) {
        return _cache;
    }
    import from jaclang.byllm.llm { Model }
    import from jaclang.byllm.config_loader { get_byllm_config }
    import from jaclang.byllm.exceptions { ConfigurationError }
    config = get_byllm_config();
    model_config = config.get_model_config();
    call_params_config = config.get_call_params_config();
    local_config = config.get_local_config();

    configured = model_config.get("default_model", "");
    env_override = os.environ.get("BYLLM_DEFAULT_MODEL", "");
    chosen = env_override or configured;
    if not chosen {
        has_cloud_key = any(
            bool(os.environ.get(k))
            for k in (
                "OPENAI_API_KEY",
                "ANTHROPIC_API_KEY",
                "GEMINI_API_KEY",
                "GOOGLE_API_KEY",
                "MISTRAL_API_KEY",
                "GROQ_API_KEY",
                "TOGETHER_API_KEY",
                "DEEPSEEK_API_KEY"
            )
        );
        if has_cloud_key {
            chosen = "openai/gpt-4o-mini";
        } else {
            try {
                import llama_cpp;
                local_alias = local_config.get("default_alias", "gemma-4-e4b");
                chosen = f"local:{local_alias}";
            } except ImportError {
                raise ConfigurationError(
                    "byLLM has no model configured and no provider API key "
                    "is set. Pick one of:\n"
                    "  - Set OPENAI_API_KEY / ANTHROPIC_API_KEY / GEMINI_API_KEY / etc.\n"
                    "  - Run a local model via Ollama (recommended for "
                    "local-first deployments): install Ollama, then set "
                    "[byllm.model].default_model = \"ollama/<model>\" "
                    "in jac.toml.\n"
                    "  - Use byLLM's bundled in-process runtime: "
                    "pip install 'byllm[local]'  then "
                    "default_model = \"local:gemma-4-e4b\"."
                );
            }
        }
    }

    merged_config: dict = dict(model_config);
    if chosen.startswith("local:") {
        for (k, v) in local_config.items() {
            merged_config[k] = v;
        }
    }

    instance = Model(
        model_name=chosen, config=merged_config, call_params=call_params_config
    );
    JacLLM._default_llm_instance = instance;
    return instance;
}

impl JacLLM.add_mtir_to_map(scope: str, mtir: Info) -> None {
    if (JacRuntime.program is None) {
        raise AttributeError('JacRuntime.program is not initialized');
    }
    JacRuntime.program.mtir_map[scope] = mtir;
}

impl JacLLM.get_mtir_from_map(scope: str) -> (Info | None) {
    if (JacRuntime.program is None) {
        raise AttributeError('JacRuntime.program is not initialized');
    }
    if (scope not in JacRuntime.program.mtir_map) {
        raise KeyError(f"MTIR not found for scope {scope}");
    }
    return JacRuntime.program.mtir_map[scope];
}

impl JacContext.create_j_context(
    user_root: (str | None),
    base_path_dir: (str | None) = None,
    full_target_path: (str | None) = None
) -> ExecutionContext {
    _sp = _scale_provider();
    if _sp is not None {
        _scaled = _sp.create_j_context(user_root, base_path_dir, full_target_path);
        if _scaled is not None {
            return _scaled;
        }
    }
    import from jaclang.runtimelib.context { ExecutionContext }
    ctx = ExecutionContext(
        base_path_dir=base_path_dir, full_target_path=full_target_path
    );
    if (user_root is not None) {
        ctx.set_user_root(user_root);
    }
    return ctx;
}

impl JacContext.attach_program(jac_program: JacProgram) -> None {
    JacRuntime.program = jac_program;
}

impl JacModule.load_module(
    module_name: str, module: types.ModuleType, force: bool = False
) -> None {
    if ((module_name not in JacRuntime.loaded_modules) or force) {
        JacRuntime.loaded_modules[module_name] = module;
        sys.modules[module_name] = module;
    }
}

impl JacIntrospection.list_modules -> list[str] {
    return `list(JacRuntime.loaded_modules.keys());
}

impl JacIntrospection._list_members_of(
    module_name: str, archetype_cls: type
) -> list[str] {
    module = JacRuntime.loaded_modules.get(module_name);
    if module {
        members = [];
        for (name, `obj) in inspect.getmembers(module) {
            if (
                isinstance(`obj, `type)
                and issubclass(`obj, archetype_cls)
                and (`obj.__module__ == module_name)
            ) {
                members.append(name);
            }
        }
        return members;
    }
    return [];
}

impl JacIntrospection.list_walkers(module_name: str) -> list[str] {
    return JacIntrospection._list_members_of(module_name, WalkerArchetype);
}

impl JacIntrospection.list_nodes(module_name: str) -> list[str] {
    return JacIntrospection._list_members_of(module_name, NodeArchetype);
}

impl JacIntrospection.list_edges(module_name: str) -> list[str] {
    return JacIntrospection._list_members_of(module_name, EdgeArchetype);
}

impl JacModule.create_archetype_from_source(
    source_code: str,
    module_name: (str | None) = None,
    base_path: (str | None) = None,
    cachable: bool = False,
    keep_temporary_files: bool = False
) -> (types.ModuleType | None) {
    if not base_path {
        base_path = JacRuntime.get_base_path_dir() or os.getcwd();
    }
    if (base_path and not os.path.exists(base_path)) {
        os.makedirs(base_path);
    }
    if not module_name {
        module_name = f"_dynamic_module_{len(JacRuntime.loaded_modules)}";
    }
    import tempfile;
    with tempfile.NamedTemporaryFile(
        mode='w', suffix='.jac', prefix=(module_name + '_'), dir=base_path, delete=False
    ) as tmp_file {
        tmp_file_path = tmp_file.name;
        tmp_file.write(source_code);
    }
    try {
        tmp_file_basename = os.path.basename(tmp_file_path);
        (tmp_module_name, _) = os.path.splitext(tmp_file_basename);
        result = JacRuntimeInterface.jac_import(
            target=tmp_module_name,
            base_path=base_path,
            override_name=module_name,
            lng='jac'
        );
        module = result[0] if result else None;
        if module {
            JacRuntime.loaded_modules[module_name] = module;
        }
        return module;
    } except Exception as e {
        logger.error(f"Error importing dynamic module '{module_name}':{e}");
        return None;
    } finally {
        if (not keep_temporary_files and os.path.exists(tmp_file_path)) {
            os.remove(tmp_file_path);
        }
    }
}

impl JacModule.update_walker(
    module_name: str, items: (dict[(str, str | str | None)] | None)
) -> tuple[(types.ModuleType, ...)] {
    if (module_name in JacRuntime.loaded_modules) {
        try {
            old_module = JacRuntime.loaded_modules[module_name];
            result = JacRuntimeInterface.jac_import(
                target=module_name,
                base_path=(JacRuntime.get_base_path_dir() or os.getcwd()),
                items=items,
                reload_module=True,
                lng='jac'
            );
            if items {
                ret_items = [];
                for (idx, item_name) in enumerate(items.keys()) {
                    if (hasattr(old_module, item_name) and (idx < len(result))) {
                        new_attr = result[idx];
                        ret_items.append(new_attr);
                        setattr(old_module, item_name, new_attr);
                    }
                }
                return `tuple(ret_items);
            }
            return (old_module, );
        } except Exception as e {
            logger.error(f"Failed to update module {module_name}: {e}");
        }
    } else {
        logger.warning(f"Module {module_name} not found in loadedmodules.");
    }
    return ();
}

impl JacIntrospection.spawn_node(
    node_name: str, attributes: (dict | None) = None, module_name: str = '__main__'
) -> NodeArchetype {
    node_class = JacRuntimeInterface.get_archetype(module_name, node_name);
    if (isinstance(node_class, `type) and issubclass(node_class, NodeArchetype)) {
        if (attributes is None) {
            attributes = {};
        }
        node_instance = node_class(**attributes);
        return node_instance;
    } else {
        raise ValueError(f"Node {node_name} not found.");
    }
}

impl JacIntrospection.spawn_walker(
    walker_name: str, attributes: (dict | None) = None, module_name: str = '__main__'
) -> WalkerArchetype {
    walker_class = JacRuntimeInterface.get_archetype(module_name, walker_name);
    if (
        isinstance(walker_class, `type) and issubclass(walker_class, WalkerArchetype)
    ) {
        if (attributes is None) {
            attributes = {};
        }
        walker_instance = walker_class(**attributes);
        return walker_instance;
    } else {
        raise ValueError(f"Walker {walker_name} not found.");
    }
}

impl JacIntrospection.get_archetype(
    module_name: str, archetype_name: str
) -> (Archetype | None) {
    module = JacRuntime.loaded_modules.get(module_name);
    if module {
        return getattr(module, archetype_name, None);
    }
    return None;
}

impl JacContext.thread_run(func: Callable, *args: object) -> Future {
    _executor = JacRuntime.pool;
    return _executor.submit(func, *args);
}

impl JacContext.thread_wait(future: any) -> None {
    return future.result();
}

impl JacConfig.on_config_loaded(config: dict[(str, any)]) -> None {
    ;
}

impl JacConfig.validate_config(config: dict[(str, any)]) -> list[str] {
    return [];
}

impl JacPersistence.get_user_manager(base_path: str) -> UserManager {
    _sp = _scale_provider();
    if _sp is not None {
        _scaled = _sp.get_user_manager(base_path);
        if _scaled is not None {
            return _scaled;
        }
    }
    import from jaclang.runtimelib.server { UserManager }
    return UserManager(base_path=base_path);
}

impl JacPersistence.store(
    base_path: str = './storage', create_dirs: bool = True
) -> any {
    _sp = _scale_provider();
    if _sp is not None {
        return _sp.store(base_path, create_dirs);
    }
    import from jaclang.runtimelib.storage { LocalStorage }
    return LocalStorage(base_path=base_path, create_dirs=create_dirs);
}

impl JacPersistence.get_persistent_memory(config: dict) -> any {
    provider = _persistent_memory_provider[0];
    if provider is not None {
        return provider(config);
    }
    return None;
}

impl JacPersistence.set_persistent_memory_provider(provider: Callable | None) -> None {
    _persistent_memory_provider[0] = provider;
}

impl JacRuntime.get_compiler(cls: any) -> JacCompiler {
    if (cls.compiler is None) {
        import from jaclang.jac0core.compiler { JacCompiler }
        cls.compiler = JacCompiler();
    }
    return cls.compiler;
}

impl JacRuntime.get_program(cls: any) -> JacProgram {
    if (cls.program is None) {
        import from jaclang.jac0core.program { JacProgram }
        cls.program = JacProgram();
    }
    return cls.program;
}

impl JacRuntime.get_shared_root -> Root {
    resolver = _shared_root_resolver[0];
    if resolver is None {
        return JacRuntimeInterface.get_context().get_root();
    }
    root_id = _shared_root_resolver[1];
    if not isinstance(root_id, str) {
        root_id = resolver();
        if not isinstance(root_id, str) {
            raise RuntimeError(
                "Shared root unavailable: the registered shared-root resolver "
                "returned no root id."
            );
        }
        _shared_root_resolver[1] = root_id;
    }
    shared_anchor = JacRuntimeInterface.get_context().mem.get(UUID(root_id));
    shared = shared_anchor.archetype if shared_anchor else None;
    if not isinstance(shared, Root) {
        raise RuntimeError(
            f"Shared root unavailable: id {root_id} did not resolve to a Root node."
        );
    }

    if shared.__jac__.access.all == AccessLevel.NO_ACCESS {
        JacRuntimeInterface.perm_grant(shared, AccessLevel.CONNECT);
    }
    return shared;
}

impl JacRuntime.set_shared_root_resolver(
    resolver: (Callable[([], (str | None))] | None)
) -> None {
    _shared_root_resolver[0] = resolver;
    _shared_root_resolver[1] = None;
}

impl JacRuntime.get_base_path_dir -> (str | None) {
    return _default_base_path_dir[0];
}

impl JacRuntime.get_full_target_path -> (str | None) {
    return _default_full_target_path[0];
}

impl JacRuntime.set_base_path(base_path: (str | None)) -> None {
    if (base_path is None) {
        _default_base_path_dir[0] = None;
    } else {
        _default_base_path_dir[0] = base_path
            if os.path.isdir(base_path)
            else os.path.dirname(base_path);
    }
}

impl JacRuntime.set_full_target_path(target_path: (str | None)) -> None {
    _default_full_target_path[0] = target_path;
}

impl JacRuntime.set_context(context: ExecutionContext) -> None {
    JacRuntime.exec_ctx = context;
}

impl JacRuntime.push_request_context(context: ExecutionContext) -> any {
    return _request_context.set(context);
}

impl JacRuntime.reset_request_context(token: any) -> None {
    _request_context.reset(token);
}
