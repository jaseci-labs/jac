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
     ),
     _NATIVE_OBJMODEL_DYNNAME_HELP: str = (
         "The attribute name is a runtime value, so it cannot be resolved "
         "to a struct slot at compile time. Native reflection lowers only "
         "string-literal names naming a declared `has` field "
         "(getattr/setattr/hasattr become plain field operations); dynamic "
         "attribute names will never be supported natively. Use direct "
         "field access, a dict, or move the code to a @sv/Python context."
     ),
     _NATIVE_OBJMODEL_DELATTR_HELP: str = (
         "Unbinding an instance attribute at runtime cannot be represented "
         "in a native archetype: fields are fixed struct slots that always "
         "exist. Model absence explicitly instead -- declare the field "
         "optional (`has x: int | None;`) and assign `None`, or use a "
         "sentinel value."
     ),
     _NATIVE_OBJMODEL_NAMESPACE_HELP: str = (
         "Native code has no per-instance or per-module namespace dict to "
         "reflect over: fields live in fixed struct slots and locals live "
         "in registers. Access fields directly, or move introspective code "
         "to a @sv/Python context."
     ),
     _NATIVE_OBJMODEL_TYPE_HELP: str = (
         "Fabricating a class at runtime (`type(name, bases, ns)`) needs a "
         "dynamic object model; native archetype layouts are fixed at "
         "compile time. Declare the archetype statically, or move the code "
         "to a @sv/Python context."
     ),
     _NATIVE_OBJMODEL_CLASS_ASSIGN_HELP: str = (
         "An object's class fixes its struct layout and method dispatch at "
         "compile time, so `__class__` cannot be reassigned at runtime. "
         "Construct a new instance of the target archetype instead."
     ),
     _NATIVE_OBJMODEL_PATCH_HELP: str = (
         "Assigning to an attribute of a class object rewires method "
         "dispatch or fabricates class state at runtime; native methods "
         "are direct (or vtable) calls resolved at compile time. Declare "
         "the behavior statically on the archetype (`def` / `static has`), "
         "or move the dynamic code to a @sv/Python context."
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

impl reflection_literal_attr_name(nd: uni.UniNode) -> (str | None) {
    if isinstance(nd, uni.String) {
        lv = nd.lit_value;
        return lv if isinstance(lv, str) else None;
    }
    if isinstance(nd, uni.MultiString) {
        parts: list[str] = [];
        for s in nd.strings {
            if not isinstance(s, uni.String) or not isinstance(s.lit_value, str) {
                return None;
            }
            parts.append(s.lit_value);
        }
        return "".join(parts);
    }
    return None;
}

impl archetype_decl_of(nd: uni.UniNode) -> (uni.Archetype | None) {
    if not isinstance(nd, uni.Name) or nd.sym is None or not nd.sym.defn {
        return None;
    }
    cand = nd.sym.defn[0].name_of;
    return cand if isinstance(cand, uni.Archetype) else None;
}

impl arch_static_field_names(arch: uni.Archetype) -> set {
    import from jaclang.jac0core.passes.module_codegen_pass { ModuleCodegenPass }
    names: set = set();
    work: list = [arch];
    seen: set = set();
    while work {
        cur = work.pop();
        if id(cur) in seen {
            continue;
        }
        seen.add(id(cur));
        for stmt in (ModuleCodegenPass.unwrap_body(cur) or []) {
            if isinstance(stmt, uni.ArchHas) and stmt.is_static {
                for hv in stmt.vars {
                    names.add(hv.name.value);
                }
            }
        }
        for base in (cur.base_classes or []) {
            base_arch = archetype_decl_of(base);
            if base_arch is not None {
                work.append(base_arch);
            }
        }
    }
    return names;
}

impl objmodel_call_violation(nd: uni.FuncCall) -> (tuple | None) {
    target = nd.target;
    if not isinstance(target, uni.Name) {
        return None;
    }
    fname = target.value;
    params_l = list(nd.params or []);
    _has_kw = any([isinstance(p, uni.KWPair) for p in params_l]);
    if nd.call_kind == "builtin" {
        if fname == "delattr" {
            return (nd, "builtin call", fname, _NATIVE_OBJMODEL_DELATTR_HELP);
        }
        if fname in ("setattr", "getattr", "hasattr") {
            if _has_kw
            or (
                len(params_l) >= 2 and reflection_literal_attr_name(params_l[1]) is None
            ) {
                return (nd, "builtin call", fname, _NATIVE_OBJMODEL_DYNNAME_HELP);
            }
            return None;
        }
        if fname == "vars" {
            return (nd, "builtin call", fname, _NATIVE_OBJMODEL_NAMESPACE_HELP);
        }
        if fname == "type" {
            _pos = [
                p
                for p in params_l
                if not isinstance(p, uni.KWPair)
            ];
            if len(_pos) >= 2 {
                return (nd, "builtin call", fname, _NATIVE_OBJMODEL_TYPE_HELP);
            }
        }
        return None;
    }
    if fname in ("globals", "locals") {
        _gl_sym = target.sym;
        _gl_stub = (
            _gl_sym is None
            or not _gl_sym.defn
            or str(_gl_sym.defn[0].loc.mod_path).endswith(".pyi")
        );
        if _gl_stub {
            return (nd, "builtin call", fname, _NATIVE_OBJMODEL_NAMESPACE_HELP);
        }
    }
    return None;
}

impl objmodel_trailer_violation(nd: uni.AtomTrailer) -> (tuple | None) {
    import ast as ast3;
    if not nd.is_attr or not isinstance(nd.right, uni.Name) {
        return None;
    }
    attr = nd.right.value;
    if attr == "__dict__" {
        return (nd, "attribute access", attr, _NATIVE_OBJMODEL_NAMESPACE_HELP);
    }
    _is_store = nd.right._py_ctx_func == ast3.Store;
    if not _is_store {
        return None;
    }
    if attr == "__class__" {
        return (nd, "attribute assignment", attr, _NATIVE_OBJMODEL_CLASS_ASSIGN_HELP);
    }
    _cls = archetype_decl_of(nd.target);
    if _cls is not None and attr not in arch_static_field_names(_cls) {
        _cls_name = _cls.name.value if _cls.name is not None else "?";
        return (
            nd,
            "class attribute assignment",
            f"{_cls_name}.{attr}",
            _NATIVE_OBJMODEL_PATCH_HELP
        );
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

    import os;
    _base_dir = os.path.dirname(os.path.abspath(mod.loc.mod_path))
        if (mod?.loc and mod.loc.mod_path)
        else '.';
    for stmt in _native_stmts {
        if isinstance(stmt, uni.Import) {
            if stmt.clib_decls or not stmt.items {
                continue;
            }
            for item in stmt.items {
                (mod_name, _ok) = classify_native_import(item);
                if mod_name is not None and not _ok {
                    import from jaclang.jac0core.codeinfo {
                        is_bundled_native_module,
                        resolve_native_module
                    }
                    if is_bundled_native_module(mod_name) {
                        continue;
                    }
                    _plain_bare = (
                        not stmt.is_absorb
                        and isinstance(item, uni.ModulePath)
                        and item.alias is None
                        and len(item.path) == 1
                    );
                    if (stmt.is_absorb or _plain_bare)
                    and resolve_native_module(mod_name, _base_dir)[1] is not None {
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
                            f"(`import from \"lib\" {{...}}`); and other Jac "
                            f"modules on the native pathway (`import mod` or "
                            f"`import from mod {{...}}`, unaliased). Move "
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
            if isinstance(nd, NATIVE_REJECT_NODES) {
                kind = "expression" if isinstance(nd, uni.Expr) else "statement";
                out.append((nd, kind, type(nd).__name__, None));
                continue;
            }

            if isinstance(nd, uni.FuncCall) {
                _omv = objmodel_call_violation(nd);
                if _omv is not None {
                    out.append((_omv[0], _omv[1], _omv[2], _omv[3], E5093));
                    continue;
                }
            }

            if isinstance(nd, uni.AtomTrailer) {
                _omt = objmodel_trailer_violation(nd);
                if _omt is not None {
                    out.append((_omt[0], _omt[1], _omt[2], _omt[3], E5093));
                    continue;
                }
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
                _vp_name = f"{nd.unpack.value}{nd.name.value if nd.name else ''}";
                _vp_encl = nd.find_parent_of_type(uni.Ability);
                if _vp_encl is None {
                    _vp_impl = nd.find_parent_of_type(uni.ImplDef);
                    if _vp_impl is not None
                    and isinstance(_vp_impl.decl_link, uni.Ability) {
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
                if nd.find_parent_of_type(uni.LambdaExpr) is not None {
                    out.append((nd, "variadic parameter", _vp_name, None));
                    continue;
                }
                if (
                    _vp_encl is not None
                    and _vp_encl.name_ref is not None
                    and _vp_encl.name_ref.sym_name in ("init", "__init__")
                    and isinstance(_vp_encl.parent, uni.Archetype)
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

            if isinstance(nd, uni.UnaryExpr)
            and isinstance(nd.op, uni.Token)
            and nd.op.name == Tok.STAR_POW
            and isinstance(nd.parent, uni.FuncCall)
            and nd in (nd.parent.params or []) {
                out.append(
                    (nd, "call argument unpacking", nd.op.value, _NATIVE_UNPACK_HELP)
                );
                continue;
            }

            if isinstance(nd, uni.KWPair)
            and nd.key is None
            and isinstance(nd.parent, uni.FuncCall) {
                out.append((nd, "call argument unpacking", "**", _NATIVE_UNPACK_HELP));
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

            if isinstance(nd, uni.FormattedValue) {
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

            if isinstance(nd, uni.AtomTrailer)
            and nd.is_attr
            and isinstance(nd.right, uni.Name)
            and (nd.target.type is not None)
            and nd.target.type.is_any_type() {
                _fld = nd.right.value;
                if (
                    _fld == "environ"
                    and isinstance(nd.target, uni.Name)
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

            if isinstance(nd, uni.EdgeRefTrailer) and nd.chain {
                _chain = nd.chain;
                _ci = 0 if isinstance(_chain[0], uni.EdgeOpRef) else 1;
                _hops = 0;
                while (_ci < len(_chain)) and isinstance(_chain[_ci], uni.EdgeOpRef) {
                    _hops += 1;
                    _ci += 1;
                    if (_ci < len(_chain))
                    and isinstance(_chain[_ci], uni.FilterCompr)
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
    normalized: list = [];
    for v in out {
        normalized.append(v if len(v) == 5 else (v[0], v[1], v[2], v[3], E5090));
    }
    return normalized;
}

impl NativeCapabilityCheckPass.postinit -> None {
    super.postinit();
}

impl NativeCapabilityCheckPass.transform(ir_in: uni.Module) -> uni.Module {
    for (_vnode, _vkind, _vname, _vhelp, _vcode) in native_capability_violations(
        ir_in
    ) {
        self.emit(
            _vcode, node_override=_vnode, kind=_vkind, name=_vname, help_text=_vhelp
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
