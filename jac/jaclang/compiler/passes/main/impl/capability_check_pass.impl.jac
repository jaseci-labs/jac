"""Implementation of the capability / portability authority (Phase 9)."""

# JS-specific globals and their Jac alternatives
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
     # JS-idiomatic methods and their Jac alternatives
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
     # JS-specific keywords/identifiers that may appear as bare names
     JS_KEYWORDS: dict[str, str] = {
         "undefined": "None",
         "typeof": "type()",
         "void": "None"
     },
     # JS-specific property accesses and their alternatives
     JS_PROPERTIES: dict[str, str] = {
         "length": "len()",
         "prototype": "Jac inheritance",
         "constructor": "type() or __init__",
         "__proto__": "Jac inheritance"
     },
     # Help text for the native `skip`-outside-event-ability rejection.
     _NATIVE_SKIP_HELP: str = (
         "`skip` is an object-spatial walker statement; native lowers it only "
         "inside a walker `with` event ability (a body that returns no value). "
         "In a value-returning function, use an explicit `return` to exit early."
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

impl native_capability_violations(mod: uni.Module) -> list {
    import from jaclang.jac0core.passes.module_codegen_pass { ModuleCodegenPass }
    import from jaclang.jac0core.constant { CodeContext, Tokens as Tok }
    import ast as ast3;
    out: list = [];
    _stdlib_help: (str | None) = None;
    # Partition native-context Load references of each name into TYPE-annotation
    # positions vs RUNTIME-value positions. A foreign Python import is tolerated
    # iff its bound name is referenced ONLY in type positions (issue #6930, A3):
    # it merely names a foreign type (whose field lowers to an opaque slot), is
    # never lowered to a runtime value, and so cannot lower to garbage. A name
    # with any runtime use stays rejected (the #6357 hazard), and an entirely
    # UNused import stays rejected too (its bound name is in neither set), which
    # preserves the existing rejection of, e.g., an unused `import os.path`.
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
    # One NATIVE-context iteration covers both violation families. NOTE:
    # NATIVE_DISQUALIFIER_NODES is deliberately NOT swept here - it is the
    # AUTO-PROMOTION eligibility table, conservatively broader than what
    # explicit na {} / .na.jac code can lower (LambdaExpr and the OSP forms
    # are auto-promote disqualifiers but natively supported).
    # Genuinely-unsupported node kinds remain the emitter fallbacks' job
    # until a dedicated explicit-native rejection table is derived from
    # them.
    for stmt in _native_stmts {
        # Non-allowlisted Python imports in native context (issue #6357):
        # the import would be dropped and member access would lower to
        # garbage, so reject it loudly. Clib imports
        # (`import from "lib" {...}`) and native module imports carry
        # from_loc / clib_decls and are legal.
        if isinstance(stmt, uni.Import) {
            if stmt.clib_decls or not stmt.items {
                continue;
            }
            for item in stmt.items {
                (mod_name, _ok) = classify_native_import(item);
                if mod_name is not None and not _ok {
                    # Type-only foreign import: the bound name only names a
                    # foreign type in annotations and is never lowered to a
                    # runtime value, so the import is harmless. It lets a field
                    # of that foreign type ride Tier-1 untouched (the field
                    # lowers to an opaque slot in the backend) (issue #6930, A3).
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
        # Structural match patterns anywhere in the statement subtree.
        # Flagged subtrees are not descended into, so one construct yields
        # one violation, not a cascade.
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
            # `skip` is an object-spatial walker statement (Return-family): the
            # native backend lowers it only where the body returns no value --
            # a walker `with` event ability. In a value-returning function it
            # would have to return-void from a typed function, which native
            # cannot do, so it is unsupported there. Detected structurally here
            # (not only at codegen) so `jac check` and `jac nacompile` agree
            # (issue #6636). `break`/`continue` are ordinary loop control and
            # are unaffected.
            if isinstance(nd, uni.CtrlStmt)
            and isinstance(nd.ctrl, uni.Token)
            and (nd.ctrl.name == Tok.KW_SKIP) {
                # The event-ability test must also accept the decl/impl-split
                # form: when the ability body lives in an annex, the `skip` is
                # enclosed by an `impl Walker.ability with X entry` ImplDef
                # (whose `spec` carries the EventSignature), not an inline
                # Ability. Native lowers it identically; only the value-returning
                # function case stays unsupported (issue #6794).
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
            # Attribute read off an UNTYPED (`any`) receiver. Native cannot
            # pick a struct field layout for an `any` value: an untyped graph
            # traversal (`[here -->]` / `[... ->:Edge:->]`) types its element
            # as `any` (an edge can connect any node types), and a boxed `any`
            # has no statically-known fields. The backend E5090s every such
            # read at codegen; detect it structurally so `jac check` and
            # `jac nacompile` agree (issues #6646 / #6657). The receiver type is
            # a checker fact (`Expr.type`), available pre-codegen.
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
            # Native lowers only a SINGLE-HOP edge reference whose chain reduces
            # to `[origin?, EdgeOpRef, FilterCompr(no value-compare)?]`. Multi-hop
            # chains (`[here -->-->]`) and value-compare node filters
            # (`[?:Area(x > 1)]`) are not lowered; the backend E5090s them so a
            # two-hop traversal is not silently truncated to one. Replicate the
            # chain reduction here STRUCTURALLY (no `here`/tag/lowering state) so
            # `jac check` and `jac nacompile` agree. Origin lowering, edge/node
            # type tags, and kernel registration stay codegen backstops.
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

impl module_native_compat(mod: uni.Module) -> bool {
    # Annex bodies are merged into mod's own tree; sub-node queries below cover
    # them, so a single-module scan suffices.
    scan_mods = [mod];
    has_entry = False;
    for mc in mod.get_all_sub_nodes(typ=uni.ModuleCode) {
        for k in mc.kid {
            if isinstance(k, uni.Token) and k.value == "entry" {
                has_entry = True;
                break;
            }
        }
        if has_entry {
            break;
        }
    }
    if not has_entry {
        return False;
    }
    for m in scan_mods {
        for nd_type in NATIVE_DISQUALIFIER_NODES {
            if m.get_all_sub_nodes(typ=nd_type) {
                return False;
            }
        }
        for arch in m.get_all_sub_nodes(typ=uni.Archetype) {
            # Any OSP archetype (node/edge/walker) disqualifies; plain
            # obj/class archetypes (arch_kind None) are native-lowerable.
            if arch.arch_kind is not None {
                return False;
            }
        }
        for ab in m.get_all_sub_nodes(typ=uni.Ability) {
            if ab.is_async or isinstance(ab.signature, uni.EventSignature) {
                return False;
            }
        }
    }
    return True;
}

impl CapabilityCheckPass.postinit -> None {
    super.postinit();
}

impl CapabilityCheckPass.transform(ir_in: uni.Module) -> uni.Module {
    ir_in.gen.native_compat = module_native_compat(ir_in);
    return ir_in;
}

impl NativeCapabilityCheckPass.postinit -> None {
    super.postinit();
}

"""Emit each native-capability violation as E5090, reusing the single
`native_capability_violations` authority the native backend emits from. Called
on the main module only (the same scope NaIRGenPass sweeps), so `jac check` and
`jac nacompile` report an identical violation set."""
impl NativeCapabilityCheckPass.transform(ir_in: uni.Module) -> uni.Module {
    for (_vnode, _vkind, _vname, _vhelp) in native_capability_violations(ir_in) {
        self.emit(
            E5090, node_override=_vnode, kind=_vkind, name=_vname, help_text=_vhelp
        );
    }
    return ir_in;
}

impl PortabilityWarnPass.postinit -> None {
    super.postinit();
}

"""Run all portability checks via bulk sub-node queries (no tree traversal)."""
impl PortabilityWarnPass.transform(ir_in: uni.Module) -> uni.Module {
    # Annex bodies are merged into ir_in's own tree, so these bulk sub-node
    # queries cover head and annex content in one sweep.
    self._check_js_globals(ir_in);
    self._check_js_methods(ir_in);
    self._check_js_keywords(ir_in);
    self._check_js_properties(ir_in);
    return ir_in;
}

"""Detect usage of JS-specific global objects (console, Math, JSON, etc.)."""
impl PortabilityWarnPass._check_js_globals(mod: uni.Module) -> None {
    import ast as ast3;
    all_names = mod.get_all_sub_nodes(typ=uni.Name);
    for name_nd in all_names {
        # Only check name usage (Load context), not definitions
        if name_nd._py_ctx_func != ast3.Load {
            continue;
        }
        # Skip if the name resolved to a user-defined symbol
        if name_nd.sym is not None {
            continue;
        }
        # Skip names inside import statements
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

"""Detect usage of JS-idiomatic method calls (.push, .forEach, .indexOf, etc.)."""
impl PortabilityWarnPass._check_js_methods(mod: uni.Module) -> None {
    all_trailers = mod.get_all_sub_nodes(typ=uni.AtomTrailer);
    for trailer in all_trailers {
        if not trailer.is_attr {
            continue;
        }
        # Check if the right side is a Name that matches a JS method
        if not isinstance(trailer.right, uni.Name) {
            continue;
        }
        method_name = trailer.right.value;
        if method_name not in JS_METHODS {
            continue;
        }
        # Check if this attribute access is the target of a function call
        # (i.e., it's actually being called as a method)
        parent = trailer.parent;
        is_method_call = isinstance(parent, uni.FuncCall) and parent.target is trailer;
        # Only warn if actually called as a method
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

"""Detect usage of JS-specific keywords used as identifiers (undefined, typeof, etc.)."""
impl PortabilityWarnPass._check_js_keywords(mod: uni.Module) -> None {
    import ast as ast3;
    all_names = mod.get_all_sub_nodes(typ=uni.Name);
    for name_nd in all_names {
        if name_nd._py_ctx_func != ast3.Load {
            continue;
        }
        # Skip if the name resolved to a user-defined symbol
        if name_nd.sym is not None {
            continue;
        }
        # Skip names inside import statements
        if name_nd.find_parent_of_type(uni.Import) is not None {
            continue;
        }
        # Skip attribute access right-hand side (x.undefined is fine as a field name)
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

"""Detect usage of JS-specific property access (.length instead of len(), etc.)."""
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
        # Make sure this is a property access, not a method call
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
