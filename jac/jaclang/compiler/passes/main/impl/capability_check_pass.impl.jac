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
     );


impl classify_native_import(item: uni.UniNode) -> tuple {
    mod_name: (str | None) = None;
    if isinstance(item, uni.ModulePath) and item.path {
        parts = [];
        for pseg in item.path {
            parts.append(pseg.value if isinstance(pseg, uni.Name) else str(pseg));
        }
        mod_name = ".".join(parts);
    }
    return (mod_name, mod_name is not None and mod_name in NATIVE_SUPPORTED_STDLIB);
}

impl import_bound_name(item: uni.UniNode) -> (str | None) {
    if not isinstance(item, uni.ModulePath) {
        return None;
    }
    if item.alias is not None and isinstance(item.alias, uni.Name) {
        return item.alias.value;
    }
    if item.path {
        first = item.path[0];
        return first.value if isinstance(first, uni.Name) else None;
    }
    return None;
}

impl name_in_type_position(name_nd: uni.UniNode) -> bool {
    if name_nd.find_parent_of_type(uni.SubTag) is not None {
        return True;
    }
    sig = name_nd.find_parent_of_type(uni.FuncSignature);
    if sig is not None and sig.return_type is not None {
        cur = name_nd;
        while cur is not None {
            if cur is sig.return_type {
                return True;
            }
            cur = cur.parent;
        }
    }
    return False;
}

impl static_fstring_spec_text(spec: uni.UniNode) -> (str | None) {
    if isinstance(spec, uni.String) {
        return spec.lit_value;
    }
    if isinstance(spec, uni.MultiString) {
        parts: list[str] = [];
        for s in spec.strings {
            if not isinstance(s, uni.String) {
                return None;
            }
            parts.append(s.lit_value);
        }
        return "".join(parts);
    }
    if isinstance(spec, uni.FString) {
        parts2: list[str] = [];
        for p in spec.parts {
            if not isinstance(p, uni.String) {
                return None;
            }
            parts2.append(p.lit_value);
        }
        return "".join(parts2);
    }
    return None;
}

impl native_capability_violations(mod: uni.Module) -> list {
    import from jaclang.jac0core.passes.module_codegen_pass { ModuleCodegenPass }
    import from jaclang.jac0core.constant { CodeContext, Tokens as Tok }
    import ast as ast3;
    out: list = [];
    _stdlib_help: (str | None) = None;

    _native_stmts: list = list(
        ModuleCodegenPass.iter_context_stmts(mod, CodeContext.NATIVE)
    );
    _runtime_used: set = set();
    _type_used: set = set();
    for _stmt in _native_stmts {
        if isinstance(_stmt, uni.Import) {
            continue;
        }
        for _nm in _stmt.get_all_sub_nodes(typ=uni.Name) {
            if _nm._py_ctx_func != ast3.Load {
                continue;
            }
            if _nm.find_parent_of_type(uni.Import) is not None {
                continue;
            }
            if name_in_type_position(_nm) {
                _type_used.add(_nm.value);
            } else {
                _runtime_used.add(_nm.value);
            }
        }
    }

    for stmt in _native_stmts {
        if isinstance(stmt, uni.Import) {
            if stmt.clib_decls or not stmt.items {
                continue;
            }
            for item in stmt.items {
                (mod_name, _ok) = classify_native_import(item);
                if mod_name is not None and not _ok {
                    import from jaclang.jac0core.codeinfo { is_bundled_native_module }
                    if is_bundled_native_module(mod_name) {
                        continue;
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
                            f"(`import from \"lib\" {{...}}`); and other native "
                            f"(.na.jac) modules (`import from mod {{...}}`). Move "
                            f"Python-dependent code to a @sv/Python context."
                        );
                    }
                    out.append((item, "Python module import", mod_name, _stdlib_help));
                }
            }
            continue;
        }

        work: list = [stmt];
        while work {
            nd = work.pop();
            if isinstance(nd, NATIVE_REJECT_MATCH_PATTERNS) {
                out.append((nd, "match pattern", type(nd).__name__, None));
                continue;
            }
            if isinstance(nd, NATIVE_REJECT_NODES) {
                kind = "expression" if isinstance(nd, uni.Expr) else "statement";
                out.append((nd, kind, type(nd).__name__, None));
                continue;
            }

            if isinstance(nd, uni.CtrlStmt)
            and isinstance(nd.ctrl, uni.Token)
            and (nd.ctrl.name == Tok.KW_SKIP) {
                _encl = nd.find_parent_of_type(uni.Ability);
                _in_event = (_encl is not None)
                and isinstance(_encl.signature, uni.EventSignature);
                if (_encl is None) {
                    _encl_impl = nd.find_parent_of_type(uni.ImplDef);
                    _in_event = (_encl_impl is not None)
                    and isinstance(_encl_impl.spec, uni.EventSignature);
                }
                if not _in_event {
                    out.append((nd, "statement", "SkipStmt", _NATIVE_SKIP_HELP));
                }
                continue;
            }

            if isinstance(nd, (uni.Ability, uni.ArchSpec, uni.ImplDef))
            and nd.decorators {
                _dec_static_fn = (
                    isinstance(nd, uni.Ability)
                    and not isinstance(nd.parent, uni.Archetype)
                    and nd.find_parent_of_type(uni.Ability) is None
                    and not nd.get_all_sub_nodes(typ=uni.YieldExpr)
                );
                if _dec_static_fn {
                    for _dexpr in nd.decorators {
                        if not isinstance(_dexpr, uni.Name) {
                            _dec_static_fn = False;
                            break;
                        }
                    }
                }
                if not _dec_static_fn {
                    _dec_owner = "?";
                    if isinstance(nd, uni.Ability) and nd.name_ref {
                        _dec_owner = nd.name_ref.sym_name;
                    } elif isinstance(nd, uni.Archetype) and nd.name {
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

            if isinstance(nd, uni.ParamVar) and nd.unpack is not None {
                out.append(
                    (
                        nd,
                        "variadic parameter",
                        f"{nd.unpack.value}{nd.name.value if nd.name else ''}",
                        None
                    )
                );
                continue;
            }

            if isinstance(nd, uni.Ability)
            and not isinstance(nd.signature, (uni.FuncSignature, uni.EventSignature))
            and isinstance(nd.parent, uni.Archetype) {
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

            if isinstance(nd, uni.BinaryExpr)
            and isinstance(nd.op, uni.Token)
            and nd.op.name == Tok.WALRUS_EQ
            and not isinstance(nd.left, uni.Name) {
                out.append((nd, "binary operator", "WALRUS_EQ", None));
                continue;
            }

            if isinstance(nd, uni.CompareExpr) and len(nd.ops) > 1 {
                _plain_ops = (Tok.EE, Tok.NE, Tok.LT, Tok.GT, Tok.LTE, Tok.GTE);
                for _o in nd.ops {
                    _oname = _o.name if isinstance(_o, uni.Token) else str(_o);
                    if _oname not in _plain_ops {
                        out.append((nd, "chained comparison operator", _oname, None));
                        break;
                    }
                }
            }

            if isinstance(nd, uni.FormattedValue) {
                _conv = nd.conversion if nd.conversion is not None else -1;
                if _conv not in (-1, 115) {
                    out.append(
                        (
                            nd,
                            "f-string conversion",
                            ("!r" if _conv == 114 else "!a"),
                            None
                        )
                    );
                    continue;
                }
                if nd.format_spec is not None
                and static_fstring_spec_text(nd.format_spec) is None {
                    out.append((nd, "f-string format spec", "<dynamic spec>", None));
                    continue;
                }
            }

            if isinstance(nd, uni.AtomTrailer)
            and nd.is_attr
            and isinstance(nd.right, uni.Name)
            and (nd.target.type is not None)
            and nd.target.type.is_any_type() {
                _fld = nd.right.value;
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

            if isinstance(nd, uni.EdgeRefTrailer) and nd.chain {
                _chain = nd.chain;
                _ci = 0 if isinstance(_chain[0], uni.EdgeOpRef) else 1;
                _shape_ok = (_ci < len(_chain))
                and isinstance(_chain[_ci], uni.EdgeOpRef);
                if _shape_ok {
                    _ci += 1;
                    if (_ci < len(_chain))
                    and isinstance(_chain[_ci], uni.FilterCompr)
                    and (_chain[_ci].f_type is not None)
                    and (not _chain[_ci].compares) {
                        _ci += 1;
                    }
                    _shape_ok = _ci == len(_chain);
                }
                if not _shape_ok {
                    out.append(
                        (
                            nd,
                            "expression",
                            "EdgeRefTrailer",
                            (
                                "native lowers only a single-hop edge reference "
                                "(`[origin -->]` / `[here ->:Edge:->]`) with an "
                                "optional trailing node-type filter (`[?:Node]`). "
                                "Multi-hop chains (`[here -->-->]`) and value-compare "
                                "filters (`[?:Node(x > 1)]`) are not yet supported; "
                                "split the traversal into single hops or move it to "
                                "@sv."
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

impl NativeCapabilityCheckPass.postinit -> None {
    super.postinit();
}

impl NativeCapabilityCheckPass.transform(ir_in: uni.Module) -> uni.Module {
    for (_vnode, _vkind, _vname, _vhelp) in native_capability_violations(ir_in) {
        self.emit(
            E5090, node_override=_vnode, kind=_vkind, name=_vname, help_text=_vhelp
        );
    }
    ir_in.gen.native_viols_reported = True;
    return ir_in;
}

impl PortabilityWarnPass.postinit -> None {
    super.postinit();
}

impl PortabilityWarnPass.transform(ir_in: uni.Module) -> uni.Module {
    self._check_js_globals(ir_in);
    self._check_js_methods(ir_in);
    self._check_js_keywords(ir_in);
    self._check_js_properties(ir_in);
    return ir_in;
}

impl PortabilityWarnPass._check_js_globals(mod: uni.Module) -> None {
    import ast as ast3;
    all_names = mod.get_all_sub_nodes(typ=uni.Name);
    for name_nd in all_names {
        if name_nd._py_ctx_func != ast3.Load {
            continue;
        }

        if name_nd.sym is not None {
            continue;
        }

        if name_nd.find_parent_of_type(uni.Import) is not None {
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

impl PortabilityWarnPass._check_js_methods(mod: uni.Module) -> None {
    all_trailers = mod.get_all_sub_nodes(typ=uni.AtomTrailer);
    for trailer in all_trailers {
        if not trailer.is_attr {
            continue;
        }

        if not isinstance(trailer.right, uni.Name) {
            continue;
        }
        method_name = trailer.right.value;
        if method_name not in JS_METHODS {
            continue;
        }

        parent = trailer.parent;
        is_method_call = isinstance(parent, uni.FuncCall) and parent.target is trailer;

        if is_method_call {
            self.emit(
                W6002,
                node_override=trailer.right,
                method=method_name,
                alternative=JS_METHODS[method_name]
            );
        }
    }
}

impl PortabilityWarnPass._check_js_keywords(mod: uni.Module) -> None {
    import ast as ast3;
    all_names = mod.get_all_sub_nodes(typ=uni.Name);
    for name_nd in all_names {
        if name_nd._py_ctx_func != ast3.Load {
            continue;
        }

        if name_nd.sym is not None {
            continue;
        }

        if name_nd.find_parent_of_type(uni.Import) is not None {
            continue;
        }

        parent = name_nd.parent;
        if isinstance(parent, uni.AtomTrailer)
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

impl PortabilityWarnPass._check_js_properties(mod: uni.Module) -> None {
    all_trailers = mod.get_all_sub_nodes(typ=uni.AtomTrailer);
    for trailer in all_trailers {
        if not trailer.is_attr {
            continue;
        }
        if not isinstance(trailer.right, uni.Name) {
            continue;
        }
        prop_name = trailer.right.value;
        if prop_name not in JS_PROPERTIES {
            continue;
        }

        parent = trailer.parent;
        is_call = isinstance(parent, uni.FuncCall) and parent.target is trailer;
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
