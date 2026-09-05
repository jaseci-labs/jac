glob JS_GLOBALS: dict[str, str] = {
         "console": "print()",
         "Math": "Jac builtins (abs, round, min, max, pow, etc.)",
         "JSON": "Jac serialization primitives",
         "Array": "list",
         "Object": "dict",
         "Map": "dict",
         "Set": "set",
         "Promise": "async/await",
         "setTimeout": "async patterns",
         "setInterval": "async patterns",
         "clearTimeout": "async patterns",
         "clearInterval": "async patterns",
         "fetch": "Jac HTTP primitives",
         "document": "Jac DOM abstractions",
         "window": "Jac platform abstractions",
         "Buffer": "bytes",
         "Symbol": "Jac types",
         "WeakMap": "dict",
         "WeakSet": "set",
         "RegExp": "str methods or re module",
         "Infinity": "float('inf')",
         "NaN": "float('nan')"
     },
     JS_METHODS: dict[str, str] = {
         "push": ".append()",
         "forEach": "for loop",
         "indexOf": ".index() or 'in' operator",
         "lastIndexOf": ".index() with reverse",
         "splice": "slice assignment",
         "unshift": ".insert(0, val)",
         "shift": ".pop(0)",
         "includes": "'in' operator",
         "findIndex": "enumerate() with condition",
         "find": "next() with generator",
         "every": "all()",
         "some": "any()",
         "flat": "list flattening",
         "flatMap": "list comprehension",
         "fill": "list multiplication or comprehension",
         "from": "list()",
         "isArray": "isinstance(x, list)",
         "charAt": "string indexing s[i]",
         "charCodeAt": "ord()",
         "fromCharCode": "chr()",
         "substring": "string slicing s[a:b]",
         "substr": "string slicing s[a:a+n]",
         "slice": "slicing [a:b]",
         "padStart": ".rjust() or .zfill()",
         "padEnd": ".ljust()",
         "trimStart": ".lstrip()",
         "trimEnd": ".rstrip()",
         "trim": ".strip()",
         "repeat": "'str * n'",
         "replaceAll": ".replace()",
         "toFixed": "format() or round()",
         "toPrecision": "format()",
         "toString": "str()",
         "parseInt": "int()",
         "parseFloat": "float()",
         "hasOwnProperty": "hasattr() or 'in' operator",
         "assign": "dict unpacking {**a, **b}",
         "freeze": "frozenset or tuple",
         "stringify": "str() or json.dumps()",
         "parse": "json.loads()"
     },
     JS_KEYWORDS: dict[str, str] = {
         "undefined": "None",
         "typeof": "type()",
         "void": "None"
     },
     JS_PROPERTIES: dict[str, str] = {
         "length": "len()",
         "prototype": "Jac inheritance",
         "constructor": "type() or __init__",
         "__proto__": "Jac inheritance"
     },
     _NATIVE_SKIP_HELP: str = (
         "`skip` is an object-spatial walker statement; native lowers it only "
         "inside a walker `with` event ability (a body that returns no value). "
         "In a value-returning function, use an explicit `return` to exit early."
     ),
     _NATIVE_DECORATOR_HELP: str = (
         "Native lowers decorators only on module-level, non-generator "
         "functions, and only when each decorator is a plain name resolving "
         "to a native function (applied at module glob-init). Method, "
         "archetype, and dynamically-computed decorators would silently run "
         "the undecorated body; remove the decorator or move the definition "
         "to a @sv/Python context."
     ),
     _NATIVE_UNPACK_HELP: str = (
         "Unpacking arguments at a native call site is not lowered yet; "
         "pass the elements explicitly or move the call to a @sv/Python "
         "context."
     );


impl classify_native_import(item: UniNode) -> tuple[((str | None), bool)] {
    import from jaclang.compiler.frontend.codeinfo { native_erased_import_names }
    mod_name: (str | None) = None;
    if isinstance(item, ModulePath) and item.path {
        parts = [];
        for pseg in item.path {
            parts.append(pseg.value if isinstance(pseg, Name) else str(pseg));
        }
        mod_name = ".".join(parts);
    } elif isinstance(item, ModuleItem) {
        _owner = item.parent;
        _from_loc = _owner.from_loc if isinstance(_owner, Import) else None;
        if _from_loc is not None {
            mod_name = _from_loc.dot_path_str;
            if isinstance(item.name, Name)
                and native_erased_import_names(mod_name, [item.name.value]) {
                return (mod_name, True);
            }
        }
    }
    return (mod_name, mod_name is not None and mod_name in NATIVE_SUPPORTED_STDLIB);
}

impl import_bound_name(item: UniNode) -> (str | None) {
    if isinstance(item, ModuleItem) {
        if item.alias is not None and isinstance(item.alias, Name) {
            return item.alias.value;
        }
        return item.name.value if isinstance(item.name, Name) else None;
    }
    if not isinstance(item, ModulePath) {
        return None;
    }
    if item.alias is not None and isinstance(item.alias, Name) {
        return item.alias.value;
    }
    if item.path {
        first = item.path[0];
        return first.value if isinstance(first, Name) else None;
    }
    return None;
}

impl from_import_jac_source(imp: Import) -> (str | None) {
    import os;
    if imp.from_loc is None {
        return None;
    }
    _path: (str | None) = None;
    try {
        _resolved = imp.from_loc.resolve_relative_path();
        _path = _resolved if isinstance(_resolved, str) else None;
    } except Exception {
        _path = None;
    }
    if _path is not None and _path.endswith('.jac') and os.path.exists(_path) {
        return _path;
    }
    return None;
}

impl node_within(name_nd: UniNode, top: (UniNode | None)) -> bool {
    if top is None {
        return False;
    }
    cur: (UniNode | None) = name_nd;
    while cur is not None {
        if cur is top {
            return True;
        }
        cur = cur.parent;
    }
    return False;
}

impl base_expr_is_erased(base: UniNode) -> bool {
    import from jaclang.compiler.frontend.codeinfo { NATIVE_ERASED_BASES }
    _tail: UniNode = base.right if isinstance(base, AtomTrailer) else base;
    return isinstance(_tail, Name) and _tail.value in NATIVE_ERASED_BASES;
}

impl name_in_type_position(name_nd: UniNode) -> bool {
    if name_nd.find_parent_of_type(SubTag) is not None {
        return True;
    }
    sig = name_nd.find_parent_of_type(FuncSignature);
    if sig is not None and node_within(name_nd, sig.return_type) {
        return True;
    }
    for _decl in [
        name_nd.find_parent_of_type(Archetype),
        name_nd.find_parent_of_type(Enum)
    ] {
        if _decl is None {
            continue;
        }
        for _base in (_decl.base_classes or []) {
            if node_within(name_nd, _base) and base_expr_is_erased(_base) {
                return True;
            }
        }
    }
    return False;
}

impl static_fstring_spec_text(spec: UniNode) -> (str | None) {
    if isinstance(spec, String) {
        _lit = spec.lit_value;
        return _lit if isinstance(_lit, str) else None;
    }
    if isinstance(spec, MultiString) {
        parts: list[str] = [];
        for s in spec.strings {
            if not isinstance(s, String) {
                return None;
            }
            _slit = s.lit_value;
            if not isinstance(_slit, str) {
                return None;
            }
            parts.append(_slit);
        }
        return "".join(parts);
    }
    if isinstance(spec, FString) {
        parts2: list[str] = [];
        for p in spec.parts {
            if not isinstance(p, String) {
                return None;
            }
            _plit = p.lit_value;
            if not isinstance(_plit, str) {
                return None;
            }
            parts2.append(_plit);
        }
        return "".join(parts2);
    }
    return None;
}

impl call_has_kwargs_sink(call: FuncCall) -> bool {
    tgt = call.target;
    sym = None;
    if isinstance(tgt, Name) {
        sym = tgt.sym;
    } elif isinstance(tgt, AtomTrailer) and isinstance(tgt.right, Name) {
        sym = tgt.right.sym;
    }
    if sym is None or sym.decl is None {
        return False;
    }
    owner = sym.decl.name_of;
    if not isinstance(owner, Ability)
        or not isinstance(owner.signature, FuncSignature) {
        return False;
    }
    return owner.signature.kwargs is not None;
}


impl native_capability_violations(
    mod: Module
) -> list[tuple[(UniNode, str, str, (str | None))]] {
    import from jaclang.compiler.frontend.constant {
        CodeContext,
        ExprCtx,
        Tokens as Tok
    }
    out: list[tuple[(UniNode, str, str, (str | None))]] = [];
    _stdlib_help: (str | None) = None;

    _native_stmts: list[ElementStmt] = ModuleCodegenPass.iter_context_stmts(
        mod, CodeContext.NATIVE
    );
    _runtime_used: set = set();
    _type_used: set = set();
    for _stmt in _native_stmts {
        if isinstance(_stmt, Import) {
            continue;
        }
        for _nm in _stmt.get_all_sub_nodes(typ=Name) {
            if _nm.expr_ctx != ExprCtx.LOAD {
                continue;
            }
            if _nm.find_parent_of_type(Import) is not None {
                continue;
            }
            if name_in_type_position(_nm) {
                _type_used.add(_nm.value);
            } else {
                _runtime_used.add(_nm.value);
            }
        }
    }

    import os;
    _base_dir = os.path.dirname(os.path.abspath(mod.loc.mod_path))
        if (mod?.loc and mod.loc.mod_path)
        else '.';
    for stmt in ModuleCodegenPass.iter_module_imports(mod, CodeContext.NATIVE)
        + ModuleCodegenPass.iter_nested_imports(mod, CodeContext.NATIVE) {
        if stmt.clib_decls or not stmt.items {
            continue;
        }
        _from_jac: (str | None) = None;
        _from_jac_known: bool = False;
        for item in stmt.items {
            (mod_name, _ok) = classify_native_import(item);
            if mod_name is not None and not _ok {
                import from jaclang.compiler.frontend.codeinfo {
                    is_bundled_native_module,
                    resolve_native_module
                }
                if is_bundled_native_module(mod_name) {
                    continue;
                }
                _plain_bare = (
                    not stmt.is_absorb
                    and isinstance(item, ModulePath)
                    and item.alias is None
                    and item.path is not None
                    and len(item.path) == 1
                );
                if (stmt.is_absorb or _plain_bare)
                    and resolve_native_module(mod_name, _base_dir)[1] is not None {
                    continue;
                }
                if isinstance(item, ModuleItem) {
                    if not _from_jac_known {
                        _from_jac = from_import_jac_source(stmt);
                        _from_jac_known = True;
                    }
                    if _from_jac is not None {
                        continue;
                    }
                }

                _bound = import_bound_name(item);
                if (
                    _bound is not None
                    and _bound in _type_used
                    and _bound not in _runtime_used
                ) {
                    continue;
                }
                if _stdlib_help is None {
                    _supported_list = ", ".join(
                        f"`import {m}`" for m in sorted(NATIVE_SUPPORTED_STDLIB)
                    );
                    _stdlib_help = (
                        f"Native compilation supports these stdlib imports: "
                        f"{_supported_list}; C-library imports "
                        f"(`import from \"lib\" {{...}}`); and other Jac "
                        f"modules on the native pathway (`import mod` or "
                        f"`import from mod {{...}}`, unaliased). Move "
                        f"Python-dependent code to a @sv/Python context."
                    );
                }
                out.append((item, "Python module import", mod_name, _stdlib_help));
            }
        }
    }

    for stmt in _native_stmts {
        if isinstance(stmt, Import) {
            continue;
        }

        work: list[UniNode] = [stmt];
        while work {
            nd = work.pop();
            if isinstance(nd, Import) {
                continue;
            }
            if isinstance(nd, NATIVE_REJECT_NODES) {
                kind = "expression" if isinstance(nd, Expr) else "statement";
                out.append((nd, kind, type(nd).__name__, None));
                continue;
            }
            if isinstance(nd, Assignment) {
                _targets = (
                    nd.target
                    if isinstance(nd.target, (list, tuple))
                    else [nd.target]
                );
                for _target in _targets {
                    if isinstance(_target, (TupleVal, ListVal)) {
                        for _star in _target.get_all_sub_nodes(typ=UnaryExpr) {
                            if (
                                isinstance(_star, UnaryExpr)
                                and isinstance(_star.op, Token)
                                and _star.op.name == Tok.STAR_MUL.value
                            ) {
                                out.append(
                                    (
                                        _target,
                                        "starred unpack target",
                                        "*",
                                        (
                                            "Starred tuple/list assignment targets are "
                                            "not lowered natively yet; move the "
                                            "statement to a non-native context."
                                        )
                                    )
                                );
                                break;
                            }
                        }
                    }
                }
            }


            if isinstance(nd, CtrlStmt)
                and isinstance(nd.ctrl, Token)
                and (nd.ctrl.name == Tok.KW_SKIP) {
                _encl = nd.find_parent_of_type(Ability);
                _in_event = (_encl is not None)
                    and isinstance(_encl.signature, EventSignature);
                if (_encl is None) {
                    _encl_impl = nd.find_parent_of_type(ImplDef);
                    _in_event = (_encl_impl is not None)
                        and isinstance(_encl_impl.spec, EventSignature);
                }
                if not _in_event {
                    out.append((nd, "statement", "SkipStmt", _NATIVE_SKIP_HELP));
                }
                continue;
            }

            if isinstance(nd, (Ability, ArchSpec, ImplDef)) and nd.decorators {
                _dec_static_fn = (
                    isinstance(nd, Ability)
                    and not isinstance(nd.parent, Archetype)
                    and nd.find_parent_of_type(Ability) is None
                    and not nd.get_all_sub_nodes(typ=YieldExpr)
                );
                if _dec_static_fn {
                    for _dexpr in nd.decorators {
                        if not isinstance(_dexpr, Name) {
                            _dec_static_fn = False;
                            break;
                        }
                    }
                }
                if not _dec_static_fn {
                    _dec_owner = "?";
                    if isinstance(nd, Ability) and nd.name_ref {
                        _dec_owner = nd.name_ref.sym_name;
                    } elif isinstance(nd, Archetype) and nd.name {
                        _dec_owner = nd.name.value;
                    }
                    out.append(
                        (
                            nd.decorators[0],
                            "decorator",
                            f"on {_dec_owner}",
                            _NATIVE_DECORATOR_HELP
                        )
                    );
                }
            }

            if isinstance(nd, ParamVar) and nd.unpack is not None {
                _vp_name = f"{nd.unpack.value}{nd.name.value if nd.name else ''}";
                _vp_encl = nd.find_parent_of_type(Ability);
                if _vp_encl is None {
                    _vp_impl = nd.find_parent_of_type(ImplDef);
                    if _vp_impl is not None
                        and isinstance(_vp_impl.decl_link, Ability) {
                        _vp_encl = _vp_impl.decl_link;
                    }
                }
                if nd.type_tag is None {
                    out.append(
                        (
                            nd,
                            "variadic parameter",
                            _vp_name,
                            (
                                "Annotate the variadic parameter (e.g. "
                                "`*args: int`, `*args: any`) so the native "
                                "pack type is known."
                            )
                        )
                    );
                    continue;
                }
                if nd.find_parent_of_type(LambdaExpr) is not None {
                    out.append((nd, "variadic parameter", _vp_name, None));
                    continue;
                }
                if (
                    _vp_encl is not None
                    and _vp_encl.name_ref is not None
                    and _vp_encl.name_ref.sym_name in ("init", "__init__")
                    and isinstance(_vp_encl.parent, Archetype)
                ) {
                    out.append(
                        (
                            nd,
                            "variadic parameter",
                            _vp_name,
                            (
                                "Native constructors are lowered as field "
                                "initializers; give `init` a fixed "
                                "parameter list."
                            )
                        )
                    );
                    continue;
                }
                if (
                    _vp_encl is not None
                    and _vp_encl.access is not None
                    and _vp_encl.access.tag.name == Tok.KW_PUB
                ) {
                    out.append(
                        (
                            nd,
                            "variadic parameter",
                            _vp_name,
                            (
                                "The interop bridge cannot marshal a "
                                "parameter pack; expose a fixed-arity "
                                "`def:pub` wrapper that calls the variadic "
                                "function instead."
                            )
                        )
                    );
                    continue;
                }
            }

            if isinstance(nd, UnaryExpr)
                and isinstance(nd.op, Token)
                and nd.op.name == Tok.STAR_POW
                and isinstance(nd.parent, FuncCall)
                and nd in (nd.parent.params or [])
                and not call_has_kwargs_sink(nd.parent) {
                out.append(
                    (nd, "call argument unpacking", nd.op.value, _NATIVE_UNPACK_HELP)
                );
                continue;
            }

            if isinstance(nd, KWPair)
                and nd.key is None
                and isinstance(nd.parent, FuncCall)
                and not call_has_kwargs_sink(nd.parent) {
                out.append((nd, "call argument unpacking", "**", _NATIVE_UNPACK_HELP));
                continue;
            }

            if isinstance(nd, Ability)
                and not isinstance(nd.signature, (FuncSignature, EventSignature))
                and isinstance(nd.parent, Archetype) {
                _sig_kind = (
                    type(nd.signature).__name__
                        if nd.signature is not None
                        else "no-signature"
                );
                _m_name = nd.name_ref.sym_name if nd.name_ref else "?";
                _arch_name = nd.parent.name.value if nd.parent.name else "?";
                out.append(
                    (
                        nd,
                        "archetype method",
                        f"{_arch_name}.{_m_name} ({_sig_kind})",
                        None
                    )
                );
                continue;
            }

            if isinstance(nd, FormattedValue) {
                _conv = nd.conversion if nd.conversion is not None else -1;
                if _conv == 97 {
                    out.append(
                        (
                            nd,
                            "f-string conversion",
                            "!a",
                            (
                                "ascii() escaping is not implemented natively; "
                                "use !r or move the statement to @sv"
                            )
                        )
                    );
                    continue;
                }
            }

            if isinstance(nd, AtomTrailer)
                and nd.is_attr
                and isinstance(nd.right, Name)
                and (nd.target.type is not None)
                and nd.target.type.is_any_type() {
                _fld = nd.right.value;
                if (
                    _fld == "environ"
                    and isinstance(nd.target, Name)
                    and nd.target.value == "os"
                ) {
                    continue;
                }
                out.append(
                    (
                        nd,
                        "attribute access",
                        _fld,
                        (
                            f"'{_fld}' is read off an untyped (`any`) receiver with "
                            f"no statically-known archetype (an edge can connect any "
                            f"node types, so a bare `[... -->]` / `[... ->:Edge:->]` "
                            f"neighbour is `any`). Add a node-type filter so the "
                            f"element resolves to an archetype, e.g. "
                            f"`[... -->[?:NodeType]]`, then read `.{_fld}` off it."
                        )
                    )
                );
                continue;
            }

            if isinstance(nd, EdgeRefTrailer) and nd.chain {
                _chain = nd.chain;
                _ci = 0 if isinstance(_chain[0], EdgeOpRef) else 1;
                _hops = 0;
                while (_ci < len(_chain)) and isinstance(_chain[_ci], EdgeOpRef) {
                    _hops += 1;
                    _ci += 1;
                    if (_ci < len(_chain))
                        and isinstance(_chain[_ci], FilterCompr)
                        and (_chain[_ci].f_type is not None) {
                        _ci += 1;
                    }
                }
                _shape_ok = (_hops > 0) and (_ci == len(_chain));
                if not _shape_ok {
                    out.append(
                        (
                            nd,
                            "expression",
                            "EdgeRefTrailer",
                            (
                                "native lowers edge references as one or more hops "
                                "(`[origin --> ...]` / `[here ->:Edge:-> ...]`), each "
                                "with an optional node-type filter (`[?:Node]`, "
                                "optionally with field predicates `[?:Node, x > 1]`). "
                                "A compare-only filter inside a chain needs a type "
                                "filter naming the element archetype first; other "
                                "shapes are not yet supported - restructure the "
                                "traversal or move it to @sv."
                            )
                        )
                    );
                    continue;
                }
            }
            for k in nd.kid {
                work.append(k);
            }
        }
    }
    return out;
}

impl native_capability_demotion_owner(viol_node: UniNode) -> (Ability | None) {
    _owner: (Ability | None) = viol_node if isinstance(viol_node, Ability) else None;
    _cur: UniNode = viol_node;
    while True {
        _nxt = _cur.find_parent_of_type(Ability);
        if _nxt is None {
            _impl = _cur.find_parent_of_type(ImplDef);
            if (
                _impl is not None
                and isinstance(_impl.decl_link, Ability)
                and _impl.decl_link is not _cur
            ) {
                _nxt = _impl.decl_link;
            }
        }
        if _nxt is None {
            break;
        }
        _owner = _nxt;
        _cur = _nxt;
    }
    if _owner is None {
        return None;
    }
    _sig = _owner.signature;
    _method_owner = _owner.method_owner;
    if _method_owner is not None {
        if not isinstance(_method_owner, Archetype) {
            return None;
        }
        if isinstance(_sig, EventSignature) {
            return _owner;
        }
        if _owner.accessor_kind {
            return _owner;
        }
        if not isinstance(_sig, FuncSignature) {
            return None;
        }
        return _owner;
    }
    if isinstance(_sig, FuncSignature) and isinstance(_owner.parent, Module) {
        return _owner;
    }
    return None;
}

impl partition_native_capability_violations(
    viols: list[tuple[(UniNode, str, str, (str | None))]]
) -> tuple[
    (
        list[tuple[(UniNode, str, str, (str | None))]],
        dict[int, list[tuple[(UniNode, str, str, (str | None))]]]
    )
] {
    _fatal: list[tuple[(UniNode, str, str, (str | None))]] = [];
    _demotable: dict[int, list[tuple[(UniNode, str, str, (str | None))]]] = {};
    for _v in viols {
        _owner = native_capability_demotion_owner(_v[0]);
        if _owner is None {
            (_vnode, _vkind, _vname, _vhelp) = _v;
            _note = (
                "No owning method or function can absorb this construct as a "
                "native seam, so the whole module refuses to lower."
            );
            _fatal.append(
                (_vnode, _vkind, _vname, f"{_vhelp} {_note}" if _vhelp else _note, )
            );
        } else {
            _key = id(_owner);
            if _key not in _demotable {
                _demotable[_key] = [];
            }
            _demotable[_key].append(_v);
        }
    }
    return (_fatal, _demotable, );
}

impl NativeCapabilityCheckPass.postinit -> None {
    super.postinit();
}

impl NativeCapabilityCheckPass._run_impl(ir_in: Module) -> Module {
    (_fatal_viols, _demotable) = partition_native_capability_violations(
        native_capability_violations(ir_in)
    );
    if _fatal_viols {
        _report: list[tuple[(UniNode, str, str, (str | None))]] = list(_fatal_viols);
        for _unit_viols in _demotable.values() {
            _report.extend(_unit_viols);
        }
        for (_vnode, _vkind, _vname, _vhelp) in _report {
            if _vhelp is None {
                self.emit(E5090, node_override=_vnode, kind=_vkind, name=_vname);
            } else {
                self.emit(
                    E5090,
                    node_override=_vnode,
                    kind=_vkind,
                    name=_vname,
                    help_text=_vhelp
                );
            }
        }
    }
    ir_in.native_viols_reported = True;
    return ir_in;
}

impl ClientCapabilityCheckPass.postinit -> None {
    super.postinit();
}

impl ClientCapabilityCheckPass._run_impl(ir_in: Module) -> Module {
    if not ir_in.client_viols_reported {
        for (_vnode, _vkind) in client_capability_violations(ir_in) {
            self.emit(E5096, node_override=_vnode, kind=_vkind);
        }
        ir_in.client_viols_reported = True;
    }
    return ir_in;
}


impl PortabilityWarnPass.postinit -> None {
    super.postinit();
}

impl PortabilityWarnPass._run_impl(ir_in: Module) -> Module {
    self._check_js_globals(ir_in);
    self._check_js_methods(ir_in);
    self._check_js_keywords(ir_in);
    self._check_js_properties(ir_in);
    return ir_in;
}

impl PortabilityWarnPass._check_js_globals(mod: Module) -> None {
    import from jaclang.compiler.frontend.constant { ExprCtx }
    all_names = mod.get_all_sub_nodes(typ=Name);
    for name_nd in all_names {
        if name_nd.expr_ctx != ExprCtx.LOAD {
            continue;
        }

        if name_nd.sym is not None {
            continue;
        }

        if name_nd.find_parent_of_type(Import) is not None {
            continue;
        }
        if name_nd.value in JS_GLOBALS {
            self.emit(
                W6001,
                node_override=name_nd,
                name=name_nd.value,
                alternative=JS_GLOBALS[name_nd.value]
            );
        }
    }
}

impl PortabilityWarnPass._check_js_methods(mod: Module) -> None {
    all_trailers = mod.get_all_sub_nodes(typ=AtomTrailer);
    for trailer in all_trailers {
        if not trailer.is_attr {
            continue;
        }

        if not isinstance(trailer.right, Name) {
            continue;
        }
        method_name = trailer.right.value;
        if method_name not in JS_METHODS {
            continue;
        }

        parent = trailer.parent;
        if not isinstance(parent, FuncCall) or parent.target is not trailer {
            continue;
        }

        if trailer.right.sym is not None {
            continue;
        }
        if method_name == "find" and not self._find_call_is_js_style(parent) {
            continue;
        }
        self.emit(
            W6002,
            node_override=trailer.right,
            method=method_name,
            alternative=JS_METHODS[method_name]
        );
    }
}

impl PortabilityWarnPass._find_call_is_js_style(call: FuncCall) -> bool {
    params = call.params;
    if params is None or len(params) != 1 {
        return False;
    }
    arg = params[0];
    if isinstance(arg, LambdaExpr) {
        return True;
    }
    if isinstance(arg, Name) and arg.sym is not None {
        return arg.sym.sym_type in (SymbolType.ABILITY, SymbolType.METHOD);
    }
    return False;
}

impl PortabilityWarnPass._check_js_keywords(mod: Module) -> None {
    import from jaclang.compiler.frontend.constant { ExprCtx }
    all_names = mod.get_all_sub_nodes(typ=Name);
    for name_nd in all_names {
        if name_nd.expr_ctx != ExprCtx.LOAD {
            continue;
        }

        if name_nd.sym is not None {
            continue;
        }

        if name_nd.find_parent_of_type(Import) is not None {
            continue;
        }

        parent = name_nd.parent;
        if isinstance(parent, AtomTrailer)
            and parent.is_attr
            and parent.right is name_nd {
            continue;
        }
        if name_nd.value in JS_KEYWORDS {
            self.emit(
                W6003,
                node_override=name_nd,
                name=name_nd.value,
                alternative=JS_KEYWORDS[name_nd.value]
            );
        }
    }
}

impl PortabilityWarnPass._check_js_properties(mod: Module) -> None {
    all_trailers = mod.get_all_sub_nodes(typ=AtomTrailer);
    for trailer in all_trailers {
        if not trailer.is_attr {
            continue;
        }
        if not isinstance(trailer.right, Name) {
            continue;
        }
        prop_name = trailer.right.value;
        if prop_name not in JS_PROPERTIES {
            continue;
        }

        if trailer.right.sym is not None {
            continue;
        }

        parent = trailer.parent;
        is_call = isinstance(parent, FuncCall) and parent.target is trailer;
        if not is_call {
            self.emit(
                W6004,
                node_override=trailer.right,
                prop=prop_name,
                alternative=JS_PROPERTIES[prop_name]
            );
        }
    }
}

impl PortabilityWarnPass.transform(ir_in: Module) -> Module {
    self.ir_out = ir_in;
    ir_in spawn self;
    out = self.ir_out;
    assert isinstance(out, Module);
    return out;
}

impl PortabilityWarnPass.run_walk with Module entry {
    self.ir_out = self._run_impl(here);
}

impl NativeCapabilityCheckPass.transform(ir_in: Module) -> Module {
    self.ir_out = ir_in;
    ir_in spawn self;
    out = self.ir_out;
    assert isinstance(out, Module);
    return out;
}

impl NativeCapabilityCheckPass.run_walk with Module entry {
    self.ir_out = self._run_impl(here);
}

impl ClientCapabilityCheckPass.transform(ir_in: Module) -> Module {
    self.ir_out = ir_in;
    ir_in spawn self;
    out = self.ir_out;
    assert isinstance(out, Module);
    return out;
}

impl ClientCapabilityCheckPass.run_walk with Module entry {
    self.ir_out = self._run_impl(here);
}
