"""Implementation for pyast_gen_pass constructs."""

"""Get the set of builtin names, cached after first successful access."""
@classmethod
impl PyastGenPass._get_builtin_names(cls: Any) -> set[str] {
    if (cls._builtin_names is None) {
        try {
            import jaclang.runtimelib.builtin as builtin_mod;
            cls._builtin_names = `set(builtin_mod.__all__);
        } except (ImportError, AttributeError) {
            return `set();
        }
    }
    return cls._builtin_names;
}

"""Read __all__ from typing_ambient.pyi, cached after first access."""
@classmethod
impl PyastGenPass._get_ambient_typing_names(cls: Any) -> set[str] {
    if (cls._ambient_typing_names is not None) {
        return cls._ambient_typing_names;
    }
    import os;
    import ast as py_ast;
    stub_path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.dirname(__file__))),
        "compiler",
        "type_system",
        "typing_ambient.pyi"
    );
    try {
        with open(stub_path, encoding="utf-8") as f {
            tree = py_ast.parse(f.read());
        }
        for node in tree.body {
            if (
                isinstance(node, py_ast.Assign)
                and len(node.targets) == 1
                and isinstance(node.targets[0], py_ast.Name)
                and node.targets[0].id == "__all__"
                and isinstance(node.value, (py_ast.List, py_ast.Tuple))
            ) {
                names: set[str] = `set();
                for elt in node.value.elts {
                    if (
                        isinstance(elt, py_ast.Constant) and isinstance(elt.value, str)
                    ) {
                        names.add(elt.value);
                    }
                }
                cls._ambient_typing_names = names;
                return names;
            }
        }
    } except (OSError, SyntaxError) {
        pass;
    }
    cls._ambient_typing_names = `set();
    return cls._ambient_typing_names;
}

impl PyastGenPass.postinit -> None {
    # Initialize by-postinit fields
    self.debuginfo = {'jac_mods': []};
    self.jaclib_imports = `set();
    self.builtin_imports = `set();
    self.typing_imports = `set();
    self.child_passes = self._init_child_passes(PyastGenPass);
    self.preamble = [
        self.sync(
            ast3.ImportFrom(
                module='__future__',
                names=[
                    self.sync(
                        ast3.alias(name='annotations', asname=None), jac_node=self.ir_in
                    )
                ],
                level=0
            ),
            jac_node=self.ir_in
        )
    ];
    self.jsx_processor = PyJsxProcessor(self);
    # Call parent postinit to run the transformation
    super.postinit();
}

"""Enter node."""
impl PyastGenPass.enter_node(nd: uni.UniNode) -> None {
    if isinstance(nd, uni.NativeBlock) {
        self._gen_native_interop_stubs(nd);
        self.prune();
        return;
    }
    if (
        isinstance(nd, uni.ClientBlock)
        or (
            isinstance(nd, uni.ContextAwareNode)
            and (nd.code_context == CodeContext.CLIENT)
            and ((nd.parent is None) or isinstance(nd.parent, uni.Module))
        )
    ) {
        self.prune();
        return;
    }
    # Skip native C library imports — they have no Python equivalent
    if (
        isinstance(nd, uni.Import)
        and nd.code_context == CodeContext.NATIVE
        and (not nd.items)
    ) {
        self.prune();
        return;
    }
    if nd.gen.py_ast {
        self.prune();
        return;
    }
    super.enter_node(nd);
}

"""Exit node."""
impl PyastGenPass.exit_node(nd: uni.UniNode) -> None {
    if isinstance(nd, (uni.ClientBlock, uni.NativeBlock)) {
        return;
    }
    if (
        isinstance(nd, uni.ContextAwareNode)
        and (nd.code_context == CodeContext.CLIENT)
        and ((nd.parent is None) or isinstance(nd.parent, uni.Module))
    ) {
        return;
    }
    # Skip native C library imports — they have no Python equivalent
    if (
        isinstance(nd, uni.Import)
        and nd.code_context == CodeContext.NATIVE
        and (not nd.items)
    ) {
        return;
    }
    super.exit_node(nd);
}

"""Generate Python stubs for native interop at the NativeBlock position.

        For native_exports (native functions called from Python):
          Generates a Python stub function that calls the native function via
ctypes.
        For native_imports (Python functions called from native):
          Generates a registration statement that stores the Python function
          in the interop callback table.
        """
impl PyastGenPass._gen_native_interop_stubs(nd: uni.NativeBlock) -> None {
    manifest = self.ir_in.gen.interop_manifest;
    if (not manifest or not manifest.bindings) {
        return;
    }
    import from jaclang.jac0core.interop_bridge { JAC_TO_CTYPES_STR }
    parts: list[str] = [];
    for binding in manifest.native_exports {
        params = ', '.join(binding.param_names);
        ret_ct = JAC_TO_CTYPES_STR.get(binding.ret_type, 'ctypes.c_int64');
        arg_cts = ', '.join(
            JAC_TO_CTYPES_STR.get(pt, 'ctypes.c_int64') for pt in binding.param_types
        );
        parts.append(
            f"def {binding.name}({params}):\n" + f"    import ctypes\n" + f"    _addr = __jac_native_engine__" + f".get_function_address('{binding.name}')\n" + f"    _fn = ctypes.CFUNCTYPE({ret_ct}, {arg_cts})(_addr)\n" + f"    return _fn({params})"
        );
    }
    for binding in manifest.native_imports {
        parts.append(f"__jac_interop_py_funcs__['{binding.name}'] = {binding.name}");
    }
    if parts {
        src = '\n'.join(parts);
        parsed = ast3.parse(src);
        nd.gen.py_ast = `list(parsed.body);
    }
}

"""Generate Python HTTP client stubs for sv-to-sv microservice imports."""
impl PyastGenPass._generate_sv_to_sv_stubs(nd: uni.Import) -> bool {
    manifest = self.ir_in.gen.interop_manifest;
    if (not manifest) {
        return False;
    }
    if (not nd.from_loc or not nd.from_loc.path) {
        return False;
    }
    module_name_parts = [
        p.value
        for p in nd.from_loc.path
        if p?.value
    ];
    module_name = '.'.join(module_name_parts) if module_name_parts else None;
    if not module_name {
        return False;
    }
    sv_to_sv_names: set = set();
    for b in manifest.server_exports_to_server {
        if b.source_module == module_name {
            sv_to_sv_names.add(b.name);
        }
    }
    if not sv_to_sv_names {
        return False;
    }
    boundary_types = manifest.boundary_types;
    # Also record this consumer -> provider edge at import time so the
    # consumer's server startup can discover every provider it needs
    # before serving traffic (see sv_client._consumer_providers and
    # JacAPIServer._ensure_sv_siblings).
    parts: list[str] = [
        "from jaclang.runtimelib import sv_client as __jac_sv_client",
        "__jac_sv_client._declare_consumer_provider(__name__, '" + module_name + "')"
    ];
    for item in nd.items {
        if not isinstance(item, uni.ModuleItem) {
            continue;
        }
        item_name = getattr(item.name, 'value', str(item.name));
        local_name = item.alias.sym_name if item.alias else item_name;
        if item_name in boundary_types {
            info = boundary_types[item_name];
            parts.append(self._gen_py_boundary_stub_class(local_name, info));
            continue;
        }
        if item_name not in sv_to_sv_names {
            continue;
        }
        binding = None;
        for b in manifest.server_exports_to_server {
            if b.name == item_name and b.source_module == module_name {
                binding = b;
                break;
            }
        }
        if binding is None {
            continue;
        }
        if binding.kind == 'walker' {
            parts.append(
                self._gen_py_sv_walker_stub(
                    local_name, item_name, module_name, binding, boundary_types
                )
            );
            continue;
        }
        parts.append(
            self._gen_py_sv_func_stub(
                local_name, item_name, module_name, binding, boundary_types
            )
        );
    }
    if (len(parts) <= 1) {
        return False;
    }
    src = '\n\n'.join(parts);
    parsed = ast3.parse(src);
    nd.gen.py_ast = `list(parsed.body);
    return True;
}

"""Build a Python source string for an sv-to-sv function stub."""
impl PyastGenPass._gen_py_sv_func_stub(
    local_name: str,
    func_name: str,
    module_name: str,
    binding: InteropBinding,
    boundary_types: dict[str, BoundaryTypeInfo]
) -> str {
    params = ', '.join(binding.param_names) if binding.param_names else '';
    args_kvs: list[str] = [];
    for i in range(len(binding.param_names)) {
        pname = binding.param_names[i];
        ptype = binding.param_types[i] if i < len(binding.param_types) else '';
        if (ptype in boundary_types and boundary_types[ptype].kind != "enum") {
            args_kvs.append(
                "'" + pname + "': (" + pname + "._to_wire() if hasattr(" + pname + ", '_to_wire') else " + pname + ")"
            );
        } else {
            args_kvs.append("'" + pname + "': " + pname);
        }
    }
    args_dict = '{' + ', '.join(args_kvs) + '}';
    ret_type = binding.ret_type;
    raw_call = (
        "__jac_sv_client.call('" + module_name + "', '" + func_name + "', " + args_dict + ")"
    );
    if (ret_type in boundary_types and boundary_types[ret_type].kind != "enum") {
        ret_expr = ret_type + '._from_wire(' + raw_call + ')';
    } else {
        ret_expr = raw_call;
    }
    return 'def ' + local_name + '(' + params + '):\n    return ' + ret_expr;
}

"""Build a Python source string for an sv-to-sv walker stub class."""
impl PyastGenPass._gen_py_sv_walker_stub(
    local_name: str,
    walker_name: str,
    module_name: str,
    binding: InteropBinding,
    boundary_types: dict[str, BoundaryTypeInfo]
) -> str {
    field_names = list(binding.param_names);
    field_types = list(binding.param_types);
    fields_repr_pieces: list[str] = [];
    for fname in field_names {
        fields_repr_pieces.append("'" + fname + "'");
    }
    fields_repr = '[' + ', '.join(fields_repr_pieces) + ']';
    boundary_pairs: list[str] = [];
    for i in range(len(field_names)) {
        ptype = field_types[i] if i < len(field_types) else '';
        if (ptype in boundary_types and boundary_types[ptype].kind != "enum") {
            boundary_pairs.append("'" + field_names[i] + "': " + ptype);
        }
    }
    boundary_map = '{' + ', '.join(boundary_pairs) + '}';
    args_kvs: list[str] = [];
    for i in range(len(field_names)) {
        pname = field_names[i];
        ptype = field_types[i] if i < len(field_types) else '';
        if (ptype in boundary_types and boundary_types[ptype].kind != "enum") {
            args_kvs.append(
                "'" + pname + "': (" + pname + "._to_wire() if hasattr(" + pname + ", '_to_wire') else " + pname + ")"
            );
        } else {
            args_kvs.append("'" + pname + "': " + pname);
        }
    }
    args_dict = '{' + ', '.join(args_kvs) + '}';
    init_params = ', '.join(
        ['cls'] + [field_names[i] + '=None' for i in range(len(field_names))]
    );
    lines: list[str] = [];
    lines.append('class ' + local_name + ':');
    lines.append('    __jac_fields__ = ' + fields_repr);
    lines.append('    __jac_walker_name__ = ' + "'" + walker_name + "'");
    lines.append('    __jac_provider_module__ = ' + "'" + module_name + "'");
    lines.append('    __jac_boundary_types__ = ' + boundary_map);
    lines.append('    def __new__(' + init_params + '):');
    lines.append('        kwargs = ' + args_dict);
    if field_names {
        lines.append(
            '        kwargs = {k: v for k, v in kwargs.items() if v is not None}'
        );
    }
    # Inside a class body, identifiers with 2+ leading underscores get
    # name-mangled to _<ClassName>__name. Look the runtime up via
    # `globals()[...]` so the mangled spelling never bites us.
    lines.append(
        '        return globals()["__jac_sv_client"].spawn_walker(' + "'" + module_name + "', '" + walker_name + "', kwargs, cls)"
    );
    # __new__ already populated the instance via spawn_walker -> _from_wire.
    # Python still invokes __init__ on a returned cls-instance, so we need a
    # no-op that swallows whatever kwargs the call site passed.
    lines.append('    def __init__(self, *args, **kwargs):');
    lines.append('        pass');
    lines.append('    def _to_wire(self):');
    lines.append(
        '        return {f: getattr(self, f, None) for f in self.__jac_fields__}'
    );
    lines.append('    @classmethod');
    lines.append('    def _from_wire(cls, d):');
    lines.append('        if d is None:');
    lines.append('            return None');
    lines.append('        if isinstance(d, list):');
    lines.append('            return [cls._from_wire(i) for i in d]');
    lines.append('        if not isinstance(d, dict):');
    lines.append('            return d');
    lines.append('        inst = object.__new__(cls)');
    lines.append('        for k, v in d.items():');
    lines.append('            if k in cls.__jac_boundary_types__ and v is not None:');
    lines.append('                v = cls.__jac_boundary_types__[k]._from_wire(v)');
    lines.append('            setattr(inst, k, v)');
    lines.append('        if not hasattr(inst, "reports"):');
    lines.append('            inst.reports = []');
    lines.append('        return inst');
    return '\n'.join(lines);
}

"""Build a Python source string for a boundary type stub class."""
impl PyastGenPass._gen_py_boundary_stub_class(
    class_name: str, info: BoundaryTypeInfo
) -> str {
    field_names: list[str] = [];
    for f in info.fields {
        field_names.append(f[0]);
    }
    fields_pieces: list[str] = [];
    for fname in field_names {
        fields_pieces.append("'" + fname + "'");
    }
    fields_repr = '[' + ', '.join(fields_pieces) + ']';
    lines: list[str] = [];
    lines.append('class ' + class_name + ':');
    lines.append('    __jac_fields__ = ' + fields_repr);
    lines.append('    def __init__(self, **kw):');
    lines.append('        for k, v in kw.items():');
    lines.append('            setattr(self, k, v)');
    lines.append('    def _to_wire(self):');
    lines.append(
        '        return {f: getattr(self, f, None) for f in self.__jac_fields__}'
    );
    lines.append('    @classmethod');
    lines.append('    def _from_wire(cls, d):');
    lines.append('        if d is None:');
    lines.append('            return None');
    lines.append('        if isinstance(d, list):');
    lines.append('            return [cls._from_wire(i) for i in d]');
    lines.append('        if not isinstance(d, dict):');
    lines.append('            return d');
    lines.append('        inst = cls.__new__(cls)');
    lines.append('        for k, v in d.items():');
    lines.append('            setattr(inst, k, v)');
    lines.append('        return inst');
    return '\n'.join(lines);
}

"""Return the object from jaclib as ast node based on the import config."""
impl PyastGenPass.jaclib_obj(obj_name: str) -> ast3.Name {
    self.jaclib_imports.add(obj_name);
    return self.sync(ast3.Name(id=obj_name, ctx=ast3.Load()));
}

"""Return a builtin name and track it for importing.

        Note: Some names like 'Enum' are provided by other imports (e.g.,
needs_enum)
        and should not be added to builtin_imports.
        """
impl PyastGenPass.builtin_name(name: str) -> ast3.Name {
    if (name not in ['Enum', 'IntEnum', 'StrEnum']) {
        self.builtin_imports.add(name);
    }
    return self.sync(ast3.Name(id=name, ctx=ast3.Load()));
}

"""True if `target` is (or transitively wraps) an edge-ref trailer whose
codegen produces a `Jac.refs(...)` call we can fuse a `slc=` kwarg into.

Recurses through inner AtomTrailers when the right-hand side is a FilterCompr
(those fuse with the EdgeRefTrailer on this same pass), so chains like
`[-->][?:Lead]` still expose the underlying refs() call to the outer slice."""
impl PyastGenPass._is_edge_ref_target(target: uni.UniNode) -> bool {
    if isinstance(target, uni.EdgeRefTrailer) {
        return not target.edges_only and not target.is_async;
    }
    if (
        isinstance(target, uni.AtomTrailer)
        and isinstance(target.right, uni.FilterCompr)
    ) {
        return self._is_edge_ref_target(target.target);
    }
    return False;
}

"""Append an import statement to the preamble once."""
impl PyastGenPass._add_preamble_once(key: str, nd: ast3.AST) -> None {
    if (key in self.already_added) {
        return;
    }
    self.preamble.append(self.sync(nd, jac_node=self.ir_out));
    self.already_added.append(key);
}

"""Ensure typing is imported only once."""
impl PyastGenPass.needs_typing -> None {
    self._add_preamble_once(
        self.needs_typing.__name__,
        ast3.Import(names=[self.sync(ast3.alias(name='typing'), jac_node=self.ir_out)])
    );
}

"""Ensure plain `Enum` and `auto` are imported (compat shim for callers
predating typed-base enums; new callers should use needs_enum_kind)."""
impl PyastGenPass.needs_enum -> None {
    self.needs_enum_kind("Enum");
}

"""Ensure a specific enum kind (Enum, IntEnum, StrEnum, ...) is imported once.

Each kind is imported under its own dedup key so a module that uses both
`enum X { ... }` and `enum Y: int { ... }` ends up with two import lines
(`from enum import Enum, auto` and `from enum import IntEnum`) rather than
a fragile combined one. `auto` is always imported alongside the requested
kind because enum bodies may reference `auto()` regardless of which Enum
flavor wraps them.
"""
impl PyastGenPass.needs_enum_kind(kind: str) -> None {
    self._add_preamble_once(
        f"needs_enum_kind:{kind}",
        ast3.ImportFrom(
            module='enum',
            names=[
                self.sync(ast3.alias(name=kind, asname=None)),
                self.sync(ast3.alias(name='auto', asname=None))
            ],
            level=0
        )
    );
}

"""Ensure concurrent Future is imported only once."""
impl PyastGenPass.needs_future -> None {
    self._add_preamble_once(
        self.needs_future.__name__,
        ast3.ImportFrom(
            module='concurrent.futures',
            names=[self.sync(ast3.alias(name='Future', asname=None))],
            level=0
        )
    );
}

"""Generate a deterministic temporary name for synthesized definitions."""
impl PyastGenPass._next_temp_name(prefix: str) -> str {
    self._temp_name_counter += 1;
    return f"__jac_{prefix}_{self._temp_name_counter}";
}

"""Convert Jac identifiers to Python runtime identifiers."""
impl PyastGenPass._py_name(nd: uni.AstSymbolNode) -> str {
    if (isinstance(nd, uni.SpecialVarRef) and (nd.name == Tok.KW_INIT)) {
        return '__init__';
    }
    if (isinstance(nd, uni.Name) and (nd.name == Tok.KW_INIT)) {
        return '__init__';
    }
    return nd.sym_name;
}

"""Convert a synthesized function definition into an executable expression.

        Instead of using make_block_lambda at runtime, we hoist the function
        definition to be emitted before the current statement, then return
        a reference to the function name.
        """
impl PyastGenPass._function_expr_from_def(
    func_def: (ast3.FunctionDef | ast3.AsyncFunctionDef),
    jac_node: uni.UniNode,
    filename_hint: str
) -> ast3.Name {
    ast3.fix_missing_locations(func_def);
    self._hoisted_funcs.append(func_def);
    return self.sync(ast3.Name(id=func_def.name, ctx=ast3.Load()), jac_node=jac_node);
}

"""Create a semstring decorator for the given semantic strings.

        Example:
            @_.sem(
                "Returns the weather for a given city.", {
                    "city" : "Name of the city to get the weather for.",
                }
            )
            def get_weather(city: str) {}

        This the second parameter (dict) will also used in the class `has`
variables
        enum values etc.
        """
impl PyastGenPass._get_sem_decorator(nd: uni.UniNode) -> (ast3.Call | None) {
    semstr: str = '';
    inner_semstr: dict[(str, str)] = {};
    if isinstance(nd, uni.Archetype) {
        semstr = nd.semstr;
        arch_ast_body: list[uni.UniNode] = [];
        if isinstance(nd.body, `list) {
            arch_ast_body = nd.body;
        } elif (isinstance(nd.body, uni.ImplDef) and isinstance(nd.body.body, `list)) {
            arch_ast_body = nd.body.body;
        }
        for stmt in arch_ast_body {
            if isinstance(stmt, uni.ArchHas) {
                for has_var in stmt.vars {
                    if has_var.semstr {
                        inner_semstr[has_var.sym_name] = has_var.semstr;
                    }
                }
            }
        }
    } elif isinstance(nd, uni.Enum) {
        semstr = nd.semstr;
        enum_ast_body: list[uni.UniNode] = [];
        if isinstance(nd.body, `list) {
            enum_ast_body = nd.body;
        } elif (isinstance(nd.body, uni.ImplDef) and isinstance(nd.body.body, `list)) {
            enum_ast_body = nd.body.body;
        }
        for stmt in enum_ast_body {
            if (
                isinstance(stmt, uni.Assignment)
                and isinstance(stmt.target[0], uni.AstSymbolNode)
            ) {
                name = stmt.target[0].sym_name;
                val_semstr = stmt.target[0].semstr;
                inner_semstr[name] = val_semstr;
            }
        }
    } elif isinstance(nd, uni.Ability) {
        semstr = nd.semstr;
        inner_semstr = {
            param.sym_name: param.semstr
            for param in nd.signature.params
            if param.semstr
        }
            if isinstance(nd.signature, uni.FuncSignature)
            else {};
    }
    if (
        not semstr and (not inner_semstr or all(not v for v in inner_semstr.values()))
    ) {
        return None;
    }
    return self.sync(
        ast3.Call(
            func=self.jaclib_obj('sem'),
            args=[
                self.sync(ast3.Constant(value=semstr)),
                self.sync(
                    ast3.Dict(
                        keys=[self.sync(ast3.Constant(value=k)) for k in inner_semstr],
                        values=[
                            self.sync(ast3.Constant(value=v))
                            for v in inner_semstr.values()
                        ]
                    )
                )
            ],
            keywords=[]
        )
    );
}

"""Safe accessor for a node's generated py_ast.

Raises an ICE with source location instead of a bare IndexError
when py_ast is unexpectedly empty.
"""
impl PyastGenPass.py_ast_val(nd: uni.UniNode) -> ast3.AST {
    if not nd.gen.py_ast {
        loc = nd.loc;
        raise self.ice(
            f"Empty py_ast on {type(nd).__name__} "
            f"at {loc.mod_path}:{loc.first_line}:{loc.col_start}"
        );
    }
    return nd.gen.py_ast[0];
}

"""Sync ast locations."""
impl PyastGenPass.sync(
    py_node: T, jac_node: (uni.UniNode | None) = None, deep: bool = False
) -> T {
    if not jac_node {
        jac_node = self.cur_node;
    }
    for i in ast3.walk(py_node) if deep else [py_node] {
        if isinstance(i, ast3.AST) {
            i.lineno = jac_node.loc.first_line;
            i.col_offset = jac_node.loc.col_start;
            i.end_lineno = jac_node.loc.last_line
                if (
                    jac_node.loc.last_line
                    and (jac_node.loc.last_line > jac_node.loc.first_line)
                )
                else jac_node.loc.first_line;
            i.end_col_offset = jac_node.loc.col_end
                if (
                    jac_node.loc.col_end
                    and (jac_node.loc.col_end > jac_node.loc.col_start)
                )
                else jac_node.loc.col_start;
            i.jac_link: list[ast3.AST] = [jac_node];
        }
    }
    return py_node;
}

"""Sync ast locations."""
impl PyastGenPass.pyinline_sync(py_nodes: list[ast3.AST]) -> list[ast3.AST] {
    for nd in py_nodes {
        for i in ast3.walk(nd) {
            if isinstance(i, ast3.AST) {
                if (i?.lineno and (i.lineno is not None)) {
                    i.lineno += self.cur_node.loc.first_line;
                }
                if (i?.end_lineno and (i.end_lineno is not None)) {
                    i.end_lineno += self.cur_node.loc.first_line;
                }
                i.jac_link: ast3.AST = [self.cur_node];
            }
        }
    }
    return py_nodes;
}

"""Resolve switch case pattern."""
impl PyastGenPass.resolve_switch_pattern(
    pattern: uni.MatchPattern, target: uni.Expr
) -> ast3.expr {
    if isinstance(pattern, uni.MatchValue) {
        return self.sync(
            ast3.Compare(
                left=cast(ast3.expr, self.py_ast_val(target)),
                ops=[self.sync(ast3.Eq())],
                comparators=[cast(ast3.expr, self.py_ast_val(pattern.value))]
            )
        );
    } elif isinstance(pattern, uni.MatchOr) {
        return self.sync(
            ast3.BoolOp(
                op=self.sync(ast3.Or()),
                values=[
                    self.resolve_switch_pattern(pat, target) for pat in pattern.patterns
                ]
            )
        );
    } elif isinstance(pattern, uni.MatchSingleton) {
        return self.sync(
            ast3.Compare(
                left=cast(ast3.expr, self.py_ast_val(target)),
                ops=[self.sync(ast3.Is())],
                comparators=[cast(ast3.expr, self.py_ast_val(pattern.value))]
            )
        );
    } else {
        raise self.ice('Unsupported switch pattern type');
    }
}

"""Resolve switch statement."""
impl PyastGenPass.resolve_switch_stmt(nd: uni.SwitchStmt) -> list[ast3.AST] {
    var_executed = self.sync(ast3.Name(id='__executed', ctx=ast3.Store()));
    assign_var = self.sync(
        ast3.Assign(targets=[var_executed], value=self.sync(ast3.Constant(value=False)))
    );
    ast_nodes: list[ast3.AST] = [];
    test_expr: ast3.expr;
    executed_assign = self.sync(
        ast3.Assign(targets=[var_executed], value=self.sync(ast3.Constant(value=True)))
    );
    for `case in nd.cases {
        if (`case.pattern is None) {
            ast_nodes.extend((self.resolve_stmt_block(`case.body) + [executed_assign]));
        } else {
            test_expr = self.sync(
                ast3.BoolOp(
                    op=self.sync(ast3.Or()),
                    values=[
                        self.resolve_switch_pattern(`case.pattern, nd.target),
                        self.sync(ast3.Name(id='__executed', ctx=ast3.Load()))
                    ]
                )
            );
            if_stmt = self.sync(
                ast3.If(
                    `test=test_expr,
                    body=cast(
                        `list[ast3.stmt],
                        (self.resolve_stmt_block(`case.body) + [executed_assign])
                    ),
                    orelse=[]
                )
            );
            ast_nodes.append(if_stmt);
        }
    }
    while_cond = self.sync(
        ast3.UnaryOp(
            op=self.sync(ast3.Not()),
            operand=self.sync(ast3.Name(id='__executed', ctx=ast3.Load()))
        )
    );
    return [
        assign_var,
        self.sync(
            ast3.While(
                `test=while_cond, body=cast(`list[ast3.stmt], ast_nodes), orelse=[]
            )
        )
    ];
}

"""Unwind codeblock."""
impl PyastGenPass.resolve_stmt_block(
    nd: Sequence[uni.CodeBlockStmt] | Sequence[uni.EnumBlockStmt] | None,
    doc: (uni.String | None) = None
) -> list[ast3.AST] {
    items = `list(nd) if nd else [];
    valid_stmts = [
        i
        for i in items
        if not isinstance(i, uni.Semi)
    ];
    ret: list[ast3.AST] = [self.sync(ast3.Pass())]
        if (isinstance(nd, Sequence) and not valid_stmts)
        else self._flatten_ast_list(
            [
                x.gen.py_ast
                    if not isinstance(x, uni.SwitchStmt)
                    else self.resolve_switch_stmt(x)
                for x in valid_stmts
                if not isinstance(x, uni.ImplDef)
            ]
        )
            if (nd is not None)
            else [self.sync(ast3.Pass())];
    if doc {
        ret = [
            self.sync(
                ast3.Expr(value=cast(ast3.expr, self.py_ast_val(doc))), jac_node=doc
            ),
            *ret
        ];
    }
    return ret;
}

"""Sync ast locations."""
impl PyastGenPass.sync_many(py_nodes: list[T], jac_node: uni.UniNode) -> list[T] {
    for py_node in py_nodes {
        self.sync(py_node, jac_node);
    }
    return py_nodes;
}

"""Convert list to attribute."""
impl PyastGenPass.list_to_attrib(
    attribute_list: list[str], sync_node_list: Sequence[uni.UniNode]
) -> ast3.AST {
    attr_node: (ast3.Name | ast3.Attribute) = self.sync(
        ast3.Name(id=attribute_list[0], ctx=ast3.Load()), sync_node_list[0]
    );
    for (attr, sync_node) in zip(
        attribute_list[1:], sync_node_list[1:], strict=False
    ) {
        attr_node = self.sync(
            ast3.Attribute(value=attr_node, attr=attr, ctx=ast3.Load()), sync_node
        );
    }
    return attr_node;
}

impl PyastGenPass.exit_sub_tag(nd: uni.SubTag[uni.T]) -> None {
    nd.gen.py_ast = nd.tag.gen.py_ast;
}

impl PyastGenPass.exit_module(nd: uni.Module) -> None {
    for child_pass in self.child_passes {
        self.jaclib_imports.update(child_pass.jaclib_imports);
        self.builtin_imports.update(child_pass.builtin_imports);
        self.typing_imports.update(child_pass.typing_imports);
    }
    is_builtin_module = (
        nd.loc.mod_path.endswith(('builtin.jac', 'builtin.py'))
        and ('runtimelib' in nd.loc.mod_path)
    );
    if (self.builtin_imports and not is_builtin_module) {
        self.preamble.append(
            self.sync(
                ast3.ImportFrom(
                    module='jaclang.runtimelib.builtin',
                    names=[
                        self.sync(ast3.alias(name=name, asname=None))
                        for name in sorted(self.builtin_imports)
                    ],
                    level=0
                ),
                jac_node=self.ir_out
            )
        );
    }
    if self.typing_imports {
        self.preamble.append(
            self.sync(
                ast3.ImportFrom(
                    module='typing',
                    names=[
                        self.sync(ast3.alias(name=name, asname=None))
                        for name in sorted(self.typing_imports)
                    ],
                    level=0
                ),
                jac_node=self.ir_out
            )
        );
    }
    mod_path_norm = nd.loc.mod_path.replace('\\', '/');
    is_jaclib_module = mod_path_norm.endswith(('/jaclang/lib.jac', '/jaclang/lib.py'));
    if (self.jaclib_imports and not is_jaclib_module) {
        self.preamble.append(
            self.sync(
                ast3.ImportFrom(
                    module='jaclang.jac0core.jaclib',
                    names=[
                        self.sync(ast3.alias(name=name, asname=None))
                        for name in sorted(self.jaclib_imports)
                    ],
                    level=0
                ),
                jac_node=self.ir_out
            )
        );
    }
    merged_body = self._merge_module_bodies(nd);
    body_items: list[ast3.AST | list[ast3.AST] | None] = [];
    if nd.doc {
        doc_stmt = self.sync(
            ast3.Expr(value=cast(ast3.expr, self.py_ast_val(nd.doc))), jac_node=nd.doc
        );
        body_items.append(doc_stmt);
    }
    body_items.extend(self.preamble);
    body_items.extend(item.gen.py_ast for item in merged_body);
    new_body = self._flatten_ast_list(body_items);
    nd.gen.py_ast = [
        self.sync(
            ast3.Module(body=[cast(ast3.stmt, s) for s in new_body], type_ignores=[])
        )
    ];
    nd.gen.py = ast3.unparse(self.py_ast_val(nd));
}

impl PyastGenPass.exit_type_param(nd: uni.TypeParam) -> None {
    bound_ast = cast(ast3.expr, self.py_ast_val(nd.bound)) if nd.bound else None;
    type_var = self.sync(ast3.TypeVar(name=nd.name.value, bound=bound_ast));
    nd.gen.py_ast = [type_var];
}

impl PyastGenPass.exit_type_alias(nd: uni.TypeAlias) -> None {
    type_param_asts: list[ast3.type_param] = [];
    for tp in nd.type_params {
        if tp.gen.py_ast {
            type_param_asts.append(cast(ast3.type_param, self.py_ast_val(tp)));
        }
    }
    value_ast = cast(ast3.expr, self.py_ast_val(nd.value));
    type_alias = self.sync(
        ast3.TypeAlias(
            name=self.sync(ast3.Name(id=nd.name.sym_name, ctx=ast3.Store())),
            type_params=type_param_asts,
            value=value_ast
        )
    );
    nd.gen.py_ast = [type_alias];
}

impl PyastGenPass.exit_global_vars(nd: uni.GlobalVars) -> None {
    if nd.doc {
        doc = self.sync(
            ast3.Expr(value=cast(ast3.expr, self.py_ast_val(nd.doc))), jac_node=nd.doc
        );
        assigns_ast: list[ast3.AST] = self._flatten_ast_list(
            [a.gen.py_ast for a in nd.assignments]
        );
        if isinstance(doc, ast3.AST) {
            nd.gen.py_ast = [doc] + assigns_ast;
        } else {
            raise self.ice();
        }
    } else {
        nd.gen.py_ast = self._flatten_ast_list([a.gen.py_ast for a in nd.assignments]);
    }
}

impl PyastGenPass.exit_test(nd: uni.Test) -> None {
    test_name = nd.name.sym_name;
    func = self.sync(
        ast3.FunctionDef(
            name=test_name,
            args=self.sync(
                ast3.arguments(
                    posonlyargs=[],
                    args=[
                        self.sync(ast3.arg(arg=Con.JAC_CHECK.value, annotation=None))
                    ],
                    kwonlyargs=[],
                    vararg=None,
                    kwarg=None,
                    kw_defaults=[],
                    defaults=[]
                )
            ),
            body=[
                cast(ast3.stmt, stmt)
                for stmt in self.resolve_stmt_block(nd.body, doc=nd.doc)
            ],
            decorator_list=[cast(ast3.expr, self.py_ast_val(i)) for i in nd.decorators]
                if nd.decorators
                else [],
            returns=self.sync(ast3.Constant(value=None)),
            type_comment=None,
            type_params=[]
        )
    );
    # Build jac_test decorator, passing description if available
    jac_test_keywords: list = [];
    if nd.description {
        jac_test_keywords.append(
            self.sync(
                ast3.keyword(
                    arg='description',
                    value=self.sync(ast3.Constant(value=nd.description.lit_value))
                )
            )
        );
    }
    func.decorator_list.append(
        self.sync(
            ast3.Call(
                func=self.jaclib_obj('jac_test'), args=[], keywords=jac_test_keywords
            )
        )
    );
    if nd.loc.mod_path.endswith('.test.jac') {
        func.decorator_list.append(
            self.sync(
                ast3.Call(
                    func=self.jaclib_obj('impl_patch_filename'),
                    args=[],
                    keywords=[
                        self.sync(
                            ast3.keyword(
                                arg='file_loc',
                                value=self.sync(ast3.Constant(value=nd.loc.mod_path))
                            )
                        )
                    ]
                )
            )
        );
    }
    nd.gen.py_ast = [func];
}

impl PyastGenPass.exit_module_code(nd: uni.ModuleCode) -> None {
    nd.gen.py_ast = self.resolve_stmt_block(nd.body, doc=nd.doc);
    if nd.name {
        nd.gen.py_ast = [
            self.sync(
                ast3.If(
                    `test=self.sync(
                        ast3.Compare(
                            left=self.sync(ast3.Name(id='__name__', ctx=ast3.Load())),
                            ops=[self.sync(ast3.Eq())],
                            comparators=[
                                self.sync(ast3.Constant(value=nd.name.sym_name))
                            ]
                        )
                    ),
                    body=[cast(ast3.stmt, i) for i in nd.gen.py_ast],
                    orelse=[]
                )
            )
        ];
    }
}

"""Handle ClientBlock - already set to empty in enter_node."""
impl PyastGenPass.exit_client_block(nd: uni.ClientBlock) -> None {
    ;
}

"""Handle ServerBlock - unwrap its children to module level."""
impl PyastGenPass.exit_server_block(nd: uni.ServerBlock) -> None {
    nd.gen.py_ast = self._flatten_ast_list([item.gen.py_ast for item in nd.body]);
}

"""Handle NativeBlock - already pruned in enter_node."""
impl PyastGenPass.exit_native_block(nd: uni.NativeBlock) -> None {
    ;
}

impl PyastGenPass.exit_py_inline_code(nd: uni.PyInlineCode) -> None {
    if nd.doc {
        doc = self.sync(
            ast3.Expr(value=cast(ast3.expr, self.py_ast_val(nd.doc))), jac_node=nd.doc
        );
        if isinstance(doc, ast3.AST) {
            nd.gen.py_ast = self.pyinline_sync([doc, *ast3.parse(nd.code.value).body]);
        } else {
            raise self.ice();
        }
    } else {
        nd.gen.py_ast = self.pyinline_sync(
            [*ast3.parse(textwrap.dedent(nd.code.value)).body]
        );
    }
}

"""Exit import node."""
impl PyastGenPass.exit_import(nd: uni.Import) -> None {
    if (nd.from_loc and nd.from_loc.path) {
        module_parts = [
            p.value
            for p in nd.from_loc.path
            if p?.value
        ];
        if (module_parts == ['__future__']) {
            nd.gen.py_ast = [];
            return;
        }
    }
    # sv-to-sv microservice import: replace import with HTTP client stubs.
    # Only triggered when the user explicitly wrote `sv import from ...`
    # (we detect this via the sv token, not code_context which defaults
    # to SERVER for all nodes).
    src_token = nd._source_context_token();
    if (
        nd.from_loc
        and nd.items
        and src_token is not None
        and src_token.name == Tok.KW_SERVER
        and self._generate_sv_to_sv_stubs(nd)
    ) {
        return;
    }
    py_nodes: list[ast3.AST] = [];
    if nd.doc {
        py_nodes.append(
            self.sync(
                ast3.Expr(value=cast(ast3.expr, self.py_ast_val(nd.doc))),
                jac_node=nd.doc
            )
        );
    }
    if nd.is_absorb {
        source = nd.items[0];
        if not isinstance(source, uni.ModulePath) {
            raise self.ice();
        }
        module_name_parts = [p.value for p in source.path] if source.path else [];
        module_name = '.'.join(module_name_parts) if module_name_parts else None;
        py_nodes.append(
            self.sync(
                py_node=ast3.ImportFrom(
                    module=module_name,
                    names=[self.sync(ast3.alias(name='*'), nd)],
                    level=source.level
                ),
                jac_node=nd
            )
        );
    } elif not nd.from_loc {
        # For plain imports (import X as Y), ModuleItem may not be in the
        # traversed kid list, so collect from ModulePath nodes directly.
        mod_paths = [
            k
            for k in nd.kid
            if isinstance(k, uni.ModulePath)
        ];
        names_list = [cast(ast3.alias, x) for p in mod_paths for x in p.gen.py_ast]
            if mod_paths
            else [cast(ast3.alias, x) for item in nd.items for x in item.gen.py_ast];
        py_nodes.append(self.sync(ast3.Import(names=names_list)));
    } else {
        module_name_parts = [p.value for p in nd.from_loc.path]
            if nd.from_loc.path
            else [];
        module_name = '.'.join(module_name_parts) if module_name_parts else None;
        py_nodes.append(
            self.sync(
                ast3.ImportFrom(
                    module=module_name,
                    names=[
                        cast(ast3.alias, i) for item in nd.items
                        for i in item.gen.py_ast
                    ],
                    level=nd.from_loc.level
                )
            )
        );
    }
    if nd.is_typed {
        self.typing_imports.add('TYPE_CHECKING');
        body_stmts = [
            stmt
            for stmt in py_nodes
            if isinstance(stmt, ast3.stmt)
        ];
        if body_stmts {
            wrapped = self.sync(
                ast3.If(
                    test=self.sync(ast3.Name(id='TYPE_CHECKING', ctx=ast3.Load())),
                    body=body_stmts,
                    orelse=[]
                )
            );
            py_nodes = [wrapped];
        }
    }
    nd.gen.py_ast = py_nodes;
}

impl PyastGenPass.exit_module_path(nd: uni.ModulePath) -> None {
    if (nd.path and (len(nd.path) == 1) and isinstance(nd.path[0], uni.String)) {
        import_node = nd.parent_of_type(uni.Import);
        if (import_node and (import_node.code_context != CodeContext.CLIENT)) {
            self.emit(E5001, node_override=nd, path=str(nd.path[0].lit_value));
        }
    }
    nd.gen.py_ast = [
        self.sync(
            ast3.alias(
                name=str(nd.dot_path_str),
                asname=nd.alias.sym_name if nd.alias else None
            )
        )
    ];
}

impl PyastGenPass.exit_module_item(nd: uni.ModuleItem) -> None {
    if (isinstance(nd.name, uni.Token) and (nd.name.value in ['default', '*'])) {
        import_node = nd.from_parent;
        if (import_node.code_context != CodeContext.CLIENT) {
            import_type = 'Default' if (nd.name.value == 'default') else 'Namespace';
            self.emit(
                E5002,
                node_override=nd,
                import_type=import_type,
                name=str(nd.name.value)
            );
            nd.gen.py_ast = [];
            return;
        }
    }
    nd.gen.py_ast = [
        self.sync(
            ast3.alias(
                name=(
                    nd.name.sym_name if isinstance(nd.name, uni.Name) else nd.name.value
                ),
                asname=nd.alias.sym_name if nd.alias else None
            )
        )
    ];
}

impl PyastGenPass.enter_archetype(nd: uni.Archetype) -> None {
    if isinstance(nd.body, uni.ImplDef) {
        self.traverse(nd.body);
    }
}

impl PyastGenPass.exit_archetype(nd: uni.Archetype) -> None {
    inner: Sequence[uni.CodeBlockStmt] | Sequence[uni.EnumBlockStmt] | None = None;
    if isinstance(nd.body, uni.ImplDef) {
        inner = nd.body.body if not isinstance(nd.body.body, uni.Expr) else None;
    } elif not isinstance(nd.body, uni.Expr) {
        inner = nd.body;
    }
    body: list[ast3.AST] = self.resolve_stmt_block(inner, doc=nd.doc);
    if (not body and not isinstance(nd.body, uni.Expr)) {
        self.emit(E5003, node_override=nd);
        body = [self.sync(ast3.Pass(), nd)];
    }
    if nd.is_async {
        body.insert(
            0,
            self.sync(
                ast3.Assign(
                    targets=[
                        self.sync(ast3.Name(id='__jac_async__', ctx=ast3.Store()))
                    ],
                    value=self.sync(ast3.Constant(value=nd.is_async))
                )
            )
        );
    }
    decorators = [cast(ast3.expr, self.py_ast_val(i)) for i in nd.decorators]
        if nd.decorators
        else [];
    if (sem_decorator := self._get_sem_decorator(nd)) {
        decorators.append(sem_decorator);
    }
    base_classes = [cast(ast3.expr, self.py_ast_val(i)) for i in nd.base_classes];
    if (nd.arch_type.name != Tok.KW_CLASS) {
        base_classes.append(self.jaclib_obj(nd.arch_type.value.capitalize()));
    }
    type_param_asts: list[ast3.type_param] = [];
    if nd.type_params {
        for tp in nd.type_params {
            if tp.gen.py_ast {
                type_param_asts.append(cast(ast3.type_param, self.py_ast_val(tp)));
            }
        }
    }
    class_def = self.sync(
        ast3.ClassDef(
            name=nd.name.sym_name,
            bases=[cast(ast3.expr, i) for i in base_classes],
            keywords=[],
            body=[cast(ast3.stmt, i) for i in body],
            decorator_list=[cast(ast3.expr, i) for i in decorators],
            type_params=type_param_asts
        )
    );
    nd.gen.py_ast = [class_def];
}

impl PyastGenPass.enter_enum(nd: uni.Enum) -> None {
    if isinstance(nd.body, uni.ImplDef) {
        self.traverse(nd.body);
    }
}

impl PyastGenPass.exit_enum(nd: uni.Enum) -> None {
    inner: Sequence[uni.CodeBlockStmt] | Sequence[uni.EnumBlockStmt] | None = None;
    if isinstance(nd.body, uni.ImplDef) {
        inner = nd.body.body if not isinstance(nd.body.body, uni.Expr) else None;
    } elif not isinstance(nd.body, uni.Expr) {
        inner = nd.body;
    }
    body = self.resolve_stmt_block(inner, doc=nd.doc);
    decorators = [cast(ast3.expr, self.py_ast_val(i)) for i in nd.decorators]
        if nd.decorators
        else [];
    if (sem_decorator := self._get_sem_decorator(nd)) {
        decorators.append(sem_decorator);
    }
    # Resolve typed-base shorthand `enum X: T`. `int` and `str` map to the
    # idiomatic `IntEnum` / `StrEnum` shortcut classes; anything else uses
    # the Python mixin pattern `class X(T, Enum)` so members are instances
    # of T (no `.value` needed at call sites).
    trailing_kind: str = "Enum";
    extra_bases: list = [];
    if nd.value_type {
        if isinstance(nd.value_type, uni.Name) and nd.value_type.value == "int" {
            trailing_kind = "IntEnum";
        } elif isinstance(nd.value_type, uni.Name) and nd.value_type.value == "str" {
            trailing_kind = "StrEnum";
        } else {
            extra_bases.append(self.py_ast_val(nd.value_type));
        }
    }
    self.needs_enum_kind(trailing_kind);
    base_classes = extra_bases + [
        cast(ast3.expr, self.py_ast_val(i)) for i in nd.base_classes
    ];
    base_classes.append(self.builtin_name(trailing_kind));
    class_def = self.sync(
        ast3.ClassDef(
            name=nd.name.sym_name,
            bases=[cast(ast3.expr, i) for i in base_classes],
            keywords=[],
            body=[cast(ast3.stmt, i) for i in body],
            decorator_list=[cast(ast3.expr, i) for i in decorators],
            type_params=[]
        )
    );
    nd.gen.py_ast = [class_def];
}

impl PyastGenPass.enter_ability(nd: uni.Ability) -> None {
    if isinstance(nd.body, uni.ImplDef) {
        self.traverse(nd.body);
    }
}

"""Reusable method to codegen call_llm(model, caller, args)."""
impl PyastGenPass._invoke_llm_call(
    model: ast3.expr, caller: ast3.expr, args: ast3.Dict
) -> ast3.Call {
    mtir_ast = self.sync(
        ast3.Call(
            func=self.jaclib_obj('get_mtir'),
            args=[],
            keywords=[
                self.sync(ast3.keyword(arg='caller', value=caller)),
                self.sync(ast3.keyword(arg='args', value=args)),
                self.sync(
                    ast3.keyword(
                        arg='call_params',
                        value=self.sync(
                            ast3.Attribute(
                                value=model, attr='call_params', ctx=ast3.Load()
                            )
                        )
                    )
                )
            ]
        )
    );
    return self.sync(
        ast3.Call(
            func=self.jaclib_obj('call_llm'),
            args=[],
            keywords=[
                self.sync(ast3.keyword(arg='model', value=model)),
                self.sync(ast3.keyword(arg='mt_run', value=mtir_ast))
            ]
        )
    );
}

"""Generate the by LLM body."""
impl PyastGenPass.gen_llm_body(nd: uni.Ability) -> list[ast3.stmt] {
    assert isinstance(nd.signature, uni.FuncSignature);
    model_expr: ast3.expr;
    if (
        nd.signature.return_type
        and isinstance(nd.signature.return_type, uni.BinaryExpr)
        and isinstance(nd.signature.return_type.op, uni.Token)
        and (nd.signature.return_type.op.name == Tok.KW_BY)
    ) {
        model_expr = cast(ast3.expr, self.py_ast_val(nd.signature.return_type.right));
    } elif isinstance(nd.body, uni.Expr) {
        model_expr = cast(ast3.expr, self.py_ast_val(nd.body));
    } else {
        raise self.ice('gen_llm_body called without model expression');
    }
    caller: ast3.expr;
    if nd.method_owner {
        owner = self.sync(
            ast3.Name(
                id='self' if not nd.is_static else nd.method_owner.sym_name,
                ctx=ast3.Load()
            ),
            jac_node=nd.method_owner
        );
        caller = self.sync(
            ast3.Attribute(
                value=owner, attr=self._py_name(nd.name_ref), ctx=ast3.Load()
            ),
            jac_node=nd.method_owner
        );
    } else {
        caller = self.sync(ast3.Name(self._py_name(nd.name_ref), ctx=ast3.Load()));
    }
    args = self.sync(
        ast3.Dict(
            keys=[
                self.sync(ast3.Constant(value=param.name.sym_name))
                for param in nd.signature.params
            ],
            values=[
                self.sync(ast3.Name(param.name.sym_name, ctx=ast3.Load()))
                for param in nd.signature.params
            ]
        )
    );
    llm_call = self._invoke_llm_call(model=model_expr, caller=caller, args=args);
    statements: list[ast3.stmt] = [];
    if nd.doc {
        statements.append(
            self.sync(
                ast3.Expr(
                    value=self.sync(
                        ast3.Constant(value=nd.doc.lit_value), jac_node=nd.doc
                    )
                )
            )
        );
    }
    statements.append(self.sync(ast3.Return(value=llm_call)));
    return statements;
}

impl PyastGenPass.exit_ability(nd: uni.Ability) -> None {
    func_type = ast3.AsyncFunctionDef if nd.is_async else ast3.FunctionDef;
    has_by_in_return = (
        isinstance(nd.signature, uni.FuncSignature)
        and nd.signature.return_type
        and isinstance(nd.signature.return_type, uni.BinaryExpr)
        and isinstance(nd.signature.return_type.op, uni.Token)
        and (nd.signature.return_type.op.name == Tok.KW_BY)
    );
    body = self.gen_llm_body(nd)
        if (
            isinstance(nd.body, uni.Expr)
            or (isinstance(nd.body, uni.ImplDef) and isinstance(nd.body.body, uni.Expr))
            or has_by_in_return
        )
        else [
            self.sync(
                ast3.Expr(value=cast(ast3.expr, self.py_ast_val(nd.doc))),
                jac_node=nd.doc
            ),
            self.sync(ast3.Pass(), nd.body)
        ]
            if (nd.doc and nd.is_abstract)
            else [self.sync(ast3.Pass(), nd.body)]
                if nd.is_abstract
                else self.resolve_stmt_block(
                    nd.body.body
                        if (
                            isinstance(nd.body, uni.ImplDef)
                            and not isinstance(nd.body.body, uni.Expr)
                        )
                        else nd.body if not isinstance(nd.body, uni.Expr) else None,
                    doc=nd.doc
                );
    if (nd.is_abstract and nd.body) {
        self.emit(E5004, node_override=nd, name=str(nd.sym_name));
    }
    decorator_list = [cast(ast3.expr, self.py_ast_val(i)) for i in nd.decorators]
        if nd.decorators
        else [];
    if (sem_decorator := self._get_sem_decorator(nd)) {
        decorator_list.append(sem_decorator);
    }
    if isinstance(nd.signature, uni.EventSignature) {
        decorator_list.append(
            self.jaclib_obj(
                'on_entry' if (nd.signature.event.name == Tok.KW_ENTRY) else 'on_exit'
            )
        );
    }
    if isinstance(nd.body, uni.ImplDef) {
        decorator_list.append(
            self.sync(
                ast3.Call(
                    func=self.jaclib_obj('impl_patch_filename'),
                    args=[self.sync(ast3.Constant(value=nd.body.loc.mod_path))],
                    keywords=[]
                )
            )
        );
    }
    if nd.is_abstract {
        decorator_list.append(self.builtin_name('abstractmethod'));
    }
    if nd.is_override {
        decorator_list.append(self.builtin_name('override'));
    }
    if nd.is_static {
        decorator_list.insert(
            0, self.sync(ast3.Name(id='staticmethod', ctx=ast3.Load()))
        );
    }
    if nd.is_classmethod {
        # Only add @classmethod for `class def` syntax, not for existing @classmethod decorator
        decorator_list.insert(
            0, self.sync(ast3.Name(id='classmethod', ctx=ast3.Load()))
        );
    }
    if (not body and not isinstance(nd.body, uni.Expr)) {
        self.emit(E5005, node_override=nd);
        body = [self.sync(ast3.Pass(), nd)];
    }
    ast_returns: ast3.expr = self.sync(ast3.Constant(value=None));
    if (isinstance(nd.signature, uni.FuncSignature) and nd.signature.return_type) {
        if (
            isinstance(nd.signature.return_type, uni.BinaryExpr)
            and isinstance(nd.signature.return_type.op, uni.Token)
            and (nd.signature.return_type.op.name == Tok.KW_BY)
        ) {
            ast_returns = cast(
                ast3.expr, self.py_ast_val(nd.signature.return_type.left)
            );
        } else {
            ast_returns = cast(ast3.expr, self.py_ast_val(nd.signature.return_type));
        }
    }
    func_def = self.sync(
        func_type(
            name=self._py_name(nd.name_ref),
            args=cast(ast3.arguments, self.py_ast_val(nd.signature))
                if nd.signature
                else self.sync(
                    ast3.arguments(
                        posonlyargs=[],
                        args=[self.sync(ast3.arg(arg='self', annotation=None))]
                            if nd.is_method
                            and not nd.is_static
                            and not nd.is_classmethod
                            else [],
                        vararg=None,
                        kwonlyargs=[],
                        kw_defaults=[],
                        kwarg=None,
                        defaults=[]
                    )
                ),
            body=[cast(ast3.stmt, i) for i in body],
            decorator_list=[cast(ast3.expr, i) for i in decorator_list],
            returns=ast_returns,
            type_params=[]
        )
    );
    nd.gen.py_ast = [func_def];
}

impl PyastGenPass.exit_impl_def(nd: uni.ImplDef) -> None {
    ;
}

impl PyastGenPass.exit_sem_def(nd: uni.SemDef) -> None {
    ;
}

impl PyastGenPass.exit_func_signature(nd: uni.FuncSignature) -> None {
    posonlyargs = [self.py_ast_val(i) for i in nd.posonly_params];
    vararg = self.py_ast_val(nd.varargs) if nd.varargs else None;
    kwarg = self.py_ast_val(nd.kwargs) if nd.kwargs else None;
    params = [self.sync(ast3.arg(arg='cls', annotation=None))]
        if (
            (abl := nd.parent)
            and isinstance(abl, uni.Ability)
            and abl.is_method
            and abl.is_classmethod
            and not nd.is_in_py_class
        )
        else [self.sync(ast3.arg(arg='self', annotation=None))]
            if (
                (abl := nd.parent)
                and isinstance(abl, uni.Ability)
                and abl.is_method
                and not nd.is_static
                and not abl.is_cls_method
                and not nd.is_in_py_class
            )
            else [];
    if posonlyargs {
        posonlyargs = params + posonlyargs;
        params = [cast(ast3.arg, self.py_ast_val(i)) for i in nd.params];
    } else {
        params = params + [cast(ast3.arg, self.py_ast_val(i)) for i in nd.params];
    }
    defaults = [];
    for i in [*nd.posonly_params, *nd.params] {
        if i.value {
            defaults.append(cast(ast3.expr, self.py_ast_val(i.value)));
        }
    }
    kwonly_args = [cast(ast3.arg, self.py_ast_val(i)) for i in nd.kwonlyargs];
    kw_defaults: list[(ast3.expr | None)] = [];
    for i in nd.kwonlyargs {
        if i.value {
            kw_defaults.append(cast(ast3.expr, self.py_ast_val(i.value)));
        } else {
            kw_defaults.append(None);
        }
    }
    nd.gen.py_ast = [
        self.sync(
            ast3.arguments(
                posonlyargs=[cast(ast3.arg, param) for param in posonlyargs],
                args=[cast(ast3.arg, param) for param in params],
                kwonlyargs=kwonly_args,
                vararg=cast(ast3.arg, vararg) if vararg else None,
                kwarg=cast(ast3.arg, kwarg) if kwarg else None,
                kw_defaults=kw_defaults,
                defaults=[cast(ast3.expr, `default) for `default in defaults]
            )
        )
    ];
}

impl PyastGenPass.exit_event_signature(nd: uni.EventSignature) -> None {
    arch_kw = Con.HERE.value if nd.from_walker else Con.VISITOR.value;
    annotation = None;
    if nd.arch_tag_info {
        py_ast = cast(ast3.expr, self.py_ast_val(nd.arch_tag_info));
        if (
            isinstance(py_ast, ast3.Tuple)
            and isinstance(nd.arch_tag_info, uni.TupleVal)
        ) {
            if (len(py_ast.elts) > 1) {
                annotation = py_ast.elts[0];
                for elem in py_ast.elts[1:] {
                    annotation = self.sync(
                        ast3.BinOp(
                            left=annotation, op=self.sync(ast3.BitOr()), right=elem
                        )
                    );
                }
            } elif (len(py_ast.elts) == 1) {
                annotation = py_ast.elts[0];
            }
        } else {
            annotation = py_ast;
        }
    }
    if annotation {
        for n in ast3.walk(annotation) {
            if (isinstance(n, ast3.Name) and (n.id == 'Root')) {
                self.jaclib_imports.add('Root');
            }
        }
    }
    arch_arg = self.sync(
        ast3.arg(arg=f"{arch_kw}", annotation=annotation),
        jac_node=nd.arch_tag_info or nd
    );
    nd.gen.py_ast = [
        self.sync(
            ast3.arguments(
                posonlyargs=[],
                args=[self.sync(ast3.arg(arg='self', annotation=None)), arch_arg]
                    if ((abl := nd.find_parent_of_type(uni.Ability)) and abl.is_method)
                    else [arch_arg],
                kwonlyargs=[],
                vararg=None,
                kwarg=None,
                kw_defaults=[],
                defaults=[]
            )
        )
    ];
}

impl PyastGenPass.exit_param_var(nd: uni.ParamVar) -> None {
    if isinstance(self.py_ast_val(nd.name), ast3.Name) {
        name = self.py_ast_val(nd.name).id;
        nd.gen.py_ast = [
            self.sync(
                ast3.arg(
                    arg=name,
                    annotation=cast(ast3.expr, self.py_ast_val(nd.type_tag))
                        if nd.type_tag
                        else None
                )
            )
        ];
    }
}

impl PyastGenPass.exit_arch_has(nd: uni.ArchHas) -> None {
    vars_py: list[ast3.AST] = self._flatten_ast_list([v.gen.py_ast for v in nd.vars]);
    if nd.doc {
        doc = self.sync(
            ast3.Expr(value=cast(ast3.expr, self.py_ast_val(nd.doc))), jac_node=nd.doc
        );
        if isinstance(doc, ast3.AST) {
            nd.gen.py_ast = [doc] + vars_py;
        } else {
            raise self.ice();
        }
    } else {
        nd.gen.py_ast = vars_py;
    }
}

impl PyastGenPass.exit_has_var(nd: uni.HasVar) -> None {
    annotation = self.py_ast_val(nd.type_tag) if nd.type_tag else None;
    is_static_var = (
        (haspar := nd.find_parent_of_type(uni.ArchHas)) and haspar and haspar.is_static
    );
    is_in_class = (
        (archpar := nd.find_parent_of_type(uni.Archetype))
        and archpar
        and (archpar.arch_type.name == Tok.KW_CLASS)
    );
    value = None;
    if is_in_class {
        value = cast(ast3.expr, self.py_ast_val(nd.value)) if nd.value else None;
    } elif is_static_var {
        annotation = self.sync(
            ast3.Subscript(
                value=self.builtin_name('ClassVar'),
                slice=cast(ast3.expr, annotation),
                ctx=ast3.Load()
            )
        );
        value = cast(ast3.expr, self.py_ast_val(nd.value)) if nd.value else None;
    } elif nd.defer {
        value = self.sync(
            ast3.Call(
                func=self.jaclib_obj('field'),
                args=[],
                keywords=[
                    self.sync(
                        ast3.keyword(
                            arg='init', value=self.sync(ast3.Constant(value=False))
                        )
                    )
                ]
            )
        );
    } elif nd.value {
        if isinstance(self.py_ast_val(nd.value), ast3.Constant) {
            value = cast(ast3.expr, self.py_ast_val(nd.value));
        } else {
            value = self.sync(
                ast3.Call(
                    func=self.jaclib_obj('field'),
                    args=[],
                    keywords=[
                        self.sync(
                            ast3.keyword(
                                arg='factory',
                                value=self.sync(
                                    ast3.Lambda(
                                        args=self.sync(
                                            ast3.arguments(
                                                posonlyargs=[],
                                                args=[],
                                                kwonlyargs=[],
                                                vararg=None,
                                                kwarg=None,
                                                kw_defaults=[],
                                                defaults=[]
                                            )
                                        ),
                                        body=cast(ast3.expr, self.py_ast_val(nd.value))
                                    )
                                )
                            )
                        )
                    ]
                )
            );
        }
    }
    nd.gen.py_ast = [
        self.sync(
            ast3.AnnAssign(
                target=cast(
                    ast3.Name | ast3.Attribute | ast3.Subscript,
                    self.py_ast_val(nd.name)
                ),
                annotation=cast(ast3.expr, annotation)
                    if annotation
                    else ast3.Constant(value=None),
                value=value,
                simple=int(isinstance(nd.name, uni.Name))
            )
        )
    ];
}

impl PyastGenPass.exit_typed_ctx_block(nd: uni.TypedCtxBlock) -> None {
    loc = self.sync(
        ast3.Name(id=Con.HERE.value, ctx=ast3.Load())
            if nd.from_walker
            else ast3.Name(id=Con.VISITOR.value, ctx=ast3.Load())
    );
    nd.gen.py_ast = [
        self.sync(
            ast3.If(
                `test=self.sync(
                    ast3.Call(
                        func=self.sync(ast3.Name(id='isinstance', ctx=ast3.Load())),
                        args=[loc, cast(ast3.expr, self.py_ast_val(nd.type_ctx))],
                        keywords=[]
                    )
                ),
                body=cast(`list[ast3.stmt], self.resolve_stmt_block(nd.body)),
                orelse=[]
            )
        )
    ];
}

impl PyastGenPass.exit_if_stmt(nd: uni.IfStmt) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.If(
                `test=cast(ast3.expr, self.py_ast_val(nd.condition)),
                body=cast(`list[ast3.stmt], self.resolve_stmt_block(nd.body)),
                orelse=cast(`list[ast3.stmt], nd.else_body.gen.py_ast)
                    if nd.else_body
                    else []
            )
        )
    ];
}

impl PyastGenPass.exit_else_if(nd: uni.ElseIf) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.If(
                `test=cast(ast3.expr, self.py_ast_val(nd.condition)),
                body=cast(`list[ast3.stmt], self.resolve_stmt_block(nd.body)),
                orelse=cast(`list[ast3.stmt], nd.else_body.gen.py_ast)
                    if nd.else_body
                    else []
            )
        )
    ];
}

impl PyastGenPass.exit_else_stmt(nd: uni.ElseStmt) -> None {
    nd.gen.py_ast = self.resolve_stmt_block(nd.body);
}

impl PyastGenPass.exit_expr_stmt(nd: uni.ExprStmt) -> None {
    hoisted = self._hoisted_funcs[:];
    self._hoisted_funcs.clear();
    expr_stmt = self.sync(ast3.Expr(value=cast(ast3.expr, self.py_ast_val(nd.expr))))
        if not nd.in_fstring
        else self.sync(
            ast3.FormattedValue(
                value=cast(ast3.expr, self.py_ast_val(nd.expr)),
                conversion=-1,
                format_spec=None
            )
        );
    nd.gen.py_ast = [*hoisted, expr_stmt];
}

impl PyastGenPass.exit_concurrent_expr(nd: uni.ConcurrentExpr) -> None {
    func = '';
    if nd.tok {
        match nd.tok.value {
            case 'flow':
                func = 'thread_run';

            case 'wait':
                func = 'thread_wait';

        }
    }
    if func {
        lambda_ex = [
            self.sync(
                ast3.Lambda(
                    args=self.sync(
                        ast3.arguments(
                            posonlyargs=[],
                            args=[],
                            kwonlyargs=[],
                            kw_defaults=[],
                            defaults=[]
                        )
                    ),
                    body=cast(ast3.expr, self.py_ast_val(nd.target))
                )
            )
        ];
        nd.gen.py_ast = [
            self.sync(
                ast3.Call(
                    func=self.jaclib_obj(func),
                    args=cast(
                        `list[ast3.expr],
                        lambda_ex
                            if (func == 'thread_run')
                            else [self.py_ast_val(nd.target)]
                    ),
                    keywords=[]
                )
            )
        ];
    }
}

impl PyastGenPass.exit_try_stmt(nd: uni.TryStmt) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.Try(
                body=cast(`list[ast3.stmt], self.resolve_stmt_block(nd.body)),
                handlers=[
                    cast(ast3.ExceptHandler, self.py_ast_val(i)) for i in nd.excepts
                ],
                orelse=[cast(ast3.stmt, i) for i in nd.else_body.gen.py_ast]
                    if nd.else_body
                    else [],
                finalbody=[cast(ast3.stmt, i) for i in nd.finally_body.gen.py_ast]
                    if nd.finally_body
                    else []
            )
        )
    ];
}

impl PyastGenPass.exit_except(nd: uni.Except) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.ExceptHandler(
                `type=cast(ast3.expr, self.py_ast_val(nd.ex_type))
                    if nd.ex_type
                    else None,
                name=nd.name.sym_name if nd.name else None,
                body=[
                    cast(ast3.stmt, stmt) for stmt in self.resolve_stmt_block(nd.body)
                ]
            )
        )
    ];
}

impl PyastGenPass.exit_finally_stmt(nd: uni.FinallyStmt) -> None {
    nd.gen.py_ast = self.resolve_stmt_block(nd.body);
}

impl PyastGenPass.exit_iter_for_stmt(nd: uni.IterForStmt) -> None {
    py_nodes: list[ast3.AST] = [];
    body = self.resolve_stmt_block(nd.body);
    if (
        isinstance(body, `list)
        and isinstance(self.py_ast_val(nd.count_by), ast3.AST)
        and isinstance(self.py_ast_val(nd.iter), ast3.AST)
    ) {
        body += [self.py_ast_val(nd.count_by)];
    } else {
        raise self.ice();
    }
    py_nodes.append(self.py_ast_val(nd.iter));
    py_nodes.append(
        self.sync(
            ast3.While(
                `test=cast(ast3.expr, self.py_ast_val(nd.condition)),
                body=[cast(ast3.stmt, stmt) for stmt in body],
                orelse=[cast(ast3.stmt, stmt) for stmt in nd.else_body.gen.py_ast]
                    if nd.else_body
                    else []
            )
        )
    );
    nd.gen.py_ast = py_nodes;
}

impl PyastGenPass.exit_in_for_stmt(nd: uni.InForStmt) -> None {
    for_node = ast3.AsyncFor if nd.is_async else ast3.For;
    nd.gen.py_ast = [
        self.sync(
            for_node(
                target=cast(ast3.expr, self.py_ast_val(nd.target)),
                iter=cast(ast3.expr, self.py_ast_val(nd.collection)),
                body=[
                    cast(ast3.stmt, stmt) for stmt in self.resolve_stmt_block(nd.body)
                ],
                orelse=[cast(ast3.stmt, stmt) for stmt in nd.else_body.gen.py_ast]
                    if nd.else_body
                    else []
            )
        )
    ];
}

impl PyastGenPass.exit_while_stmt(nd: uni.WhileStmt) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.While(
                `test=cast(ast3.expr, self.py_ast_val(nd.condition)),
                body=[
                    cast(ast3.stmt, stmt) for stmt in self.resolve_stmt_block(nd.body)
                ],
                orelse=[cast(ast3.stmt, stmt) for stmt in nd.else_body.gen.py_ast]
                    if nd.else_body
                    else []
            )
        )
    ];
}

impl PyastGenPass.exit_with_stmt(nd: uni.WithStmt) -> None {
    with_node = ast3.AsyncWith if nd.is_async else ast3.With;
    nd.gen.py_ast = [
        self.sync(
            with_node(
                items=[cast(ast3.withitem, self.py_ast_val(item)) for item in nd.exprs],
                body=[
                    cast(ast3.stmt, stmt) for stmt in self.resolve_stmt_block(nd.body)
                ]
            )
        )
    ];
}

impl PyastGenPass.exit_expr_as_item(nd: uni.ExprAsItem) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.withitem(
                context_expr=cast(ast3.expr, self.py_ast_val(nd.expr)),
                optional_vars=cast(ast3.expr, self.py_ast_val(nd.alias))
                    if nd.alias
                    else None
            )
        )
    ];
}

impl PyastGenPass.exit_raise_stmt(nd: uni.RaiseStmt) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.Raise(
                exc=cast(ast3.expr, self.py_ast_val(nd.cause)) if nd.cause else None,
                cause=cast(ast3.expr, self.py_ast_val(nd.from_target))
                    if nd.from_target
                    else None
            )
        )
    ];
}

impl PyastGenPass.exit_assert_stmt(nd: uni.AssertStmt) -> None {
    if isinstance(nd.parent, uni.Test) {
        self.assert_helper(nd);
    } else {
        nd.gen.py_ast = [
            self.sync(
                ast3.Assert(
                    `test=cast(ast3.expr, self.py_ast_val(nd.condition)),
                    msg=cast(ast3.expr, self.py_ast_val(nd.error_msg))
                        if nd.error_msg
                        else None
                )
            )
        ];
    }
}

"""Sub objects.

        target: ExprType,
        """
impl PyastGenPass.assert_helper(nd: uni.AssertStmt) -> None {
    @dataclass
    class CheckNodeIsinstanceCallResult {
        with entry {
            isit: bool = False;
            inst: (ast3.AST | None) = None;
            clss: (ast3.AST | None) = None;
        }
    }
    def check_node_isinstance_call(nd: uni.FuncCall) -> CheckNodeIsinstanceCallResult {
        if not (
            (len(nd.params) == 2)
            and isinstance(nd.params[0], uni.Expr)
            and isinstance(nd.params[1], uni.Expr)
        ) {
            return CheckNodeIsinstanceCallResult();
        }
        func = self.py_ast_val(nd.target);
        if not (isinstance(func, ast3.Name) and (func.id == 'isinstance')) {
            return CheckNodeIsinstanceCallResult();
        }
        return CheckNodeIsinstanceCallResult(
            True, self.py_ast_val(nd.params[0]), self.py_ast_val(nd.params[1])
        );
    }
    assert_func_name = 'assertTrue';
    assert_args_list = nd.condition.gen.py_ast;
    if (
        isinstance(nd.condition, uni.CompareExpr)
        and isinstance(self.py_ast_val(nd.condition), ast3.Compare)
        and (len(nd.condition.ops) == 1)
    ) {
        expr: uni.CompareExpr = nd.condition;
        opty: uni.Token = expr.ops[0];
        optype2fn = {
            Tok.EE.name: 'assertEqual',
            Tok.NE.name: 'assertNotEqual',
            Tok.LT.name: 'assertLess',
            Tok.LTE.name: 'assertLessEqual',
            Tok.GT.name: 'assertGreater',
            Tok.GTE.name: 'assertGreaterEqual',
            Tok.KW_IN.name: 'assertIn',
            Tok.KW_NIN.name: 'assertNotIn',
            Tok.KW_IS.name: 'assertIs',
            Tok.KW_ISN.name: 'assertIsNot'
        };
        if (opty.name in optype2fn) {
            assert_func_name = optype2fn[opty.name];
            assert_args_list = [
                self.py_ast_val(expr.left),
                self.py_ast_val(expr.rights[0])
            ];
            if ((opty.name == Tok.KW_IS) and isinstance(expr.rights[0], uni.Null)) {
                assert_func_name = 'assertIsNone';
                assert_args_list.pop();
            } elif (
                (opty.name == Tok.KW_ISN) and isinstance(expr.rights[0], uni.Null)
            ) {
                assert_func_name = 'assertIsNotNone';
                assert_args_list.pop();
            }
        }
    } elif (
        isinstance(nd.condition, uni.FuncCall)
        and isinstance(self.py_ast_val(nd.condition), ast3.Call)
    ) {
        res = check_node_isinstance_call(nd.condition);
        if res.isit {
            assert isinstance(res.inst, ast3.AST);
            assert isinstance(res.clss, ast3.AST);
            assert_func_name = 'assertIsInstance';
            assert_args_list = [res.inst, res.clss];
        }
    } elif (
        isinstance(nd.condition, uni.UnaryExpr)
        and isinstance(nd.condition, uni.UnaryExpr)
        and isinstance(nd.condition.operand, uni.FuncCall)
        and isinstance(nd.condition.operand, uni.UnaryExpr)
    ) {
        res = check_node_isinstance_call(nd.condition.operand);
        if res.isit {
            assert isinstance(res.inst, ast3.AST);
            assert isinstance(res.clss, ast3.AST);
            assert_func_name = 'assertIsNotInstance';
            assert_args_list = [res.inst, res.clss];
        }
    }
    assert_func_expr: ast3.Attribute = self.sync(
        ast3.Attribute(
            value=self.sync(ast3.Name(id=Con.JAC_CHECK.value, ctx=ast3.Load())),
            attr=assert_func_name,
            ctx=ast3.Load()
        )
    );
    assert_call_expr: ast3.Call = self.sync(
        ast3.Call(
            func=assert_func_expr,
            args=[cast(ast3.expr, arg) for arg in assert_args_list],
            keywords=[]
        )
    );
    nd.gen.py_ast = [self.sync(ast3.Expr(assert_call_expr))];
}

impl PyastGenPass.exit_ctrl_stmt(nd: uni.CtrlStmt) -> None {
    if (nd.ctrl.name == Tok.KW_BREAK) {
        nd.gen.py_ast = [self.sync(ast3.Break())];
    } elif (nd.ctrl.name == Tok.KW_CONTINUE) {
        if (iter_for_parent := self.find_parent_of_type(nd, uni.IterForStmt)) {
            count_by = iter_for_parent.count_by;
            nd.gen.py_ast = [self.py_ast_val(count_by), self.sync(ast3.Continue())];
        } else {
            nd.gen.py_ast = [self.sync(ast3.Continue())];
        }
    } elif (nd.ctrl.name == Tok.KW_SKIP) {
        nd.gen.py_ast = [self.sync(ast3.Return(value=None))];
    }
}

impl PyastGenPass.exit_delete_stmt(nd: uni.DeleteStmt) -> None {
    """Set the given ctx (Load, Del) to AST node(s).""";
    def set_ctx(targets: (ast3.AST | list[ast3.AST]), ctx: type) -> list[ast3.AST] {
        if not isinstance(targets, `list) {
            targets = [targets];
        } elif isinstance(targets[0], (ast3.List, ast3.Tuple)) {
            targets = [
                i
                for i in targets[0].elts
                if isinstance(i, ast3.AST)
            ];
        }
        result = [];
        for target in targets {
            if target?.ctx {
                target = copy.copy(target);
                target.ctx = ctx();
            }
            result.append(target);
        }
        return result;
    }
    destroy_expr = ast3.Expr(
        value=self.sync(
            ast3.Call(
                func=self.jaclib_obj('destroy'),
                args=[
                    self.sync(
                        ast3.List(
                            elts=cast(
                                `list[ast3.expr], set_ctx(nd.py_ast_targets, ast3.Load)
                            ),
                            ctx=ast3.Load()
                        )
                    )
                ],
                keywords=[]
            )
        )
    );
    delete_stmt = self.sync(
        ast3.Delete(
            targets=cast(`list[ast3.expr], set_ctx(nd.py_ast_targets, ast3.Del))
        )
    );
    nd.gen.py_ast = [self.sync(destroy_expr), self.sync(delete_stmt)];
}

impl PyastGenPass.exit_report_stmt(nd: uni.ReportStmt) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.Expr(
                value=self.sync(
                    self.sync(
                        ast3.Call(
                            func=self.jaclib_obj('log_report'),
                            args=cast(`list[ast3.expr], nd.expr.gen.py_ast),
                            keywords=[]
                        )
                    )
                )
            )
        )
    ];
}

impl PyastGenPass.exit_return_stmt(nd: uni.ReturnStmt) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.Return(
                value=cast(ast3.expr, self.py_ast_val(nd.expr)) if nd.expr else None
            )
        )
    ];
}

impl PyastGenPass.exit_yield_expr(nd: uni.YieldExpr) -> None {
    if not nd.with_from {
        nd.gen.py_ast = [
            self.sync(
                ast3.Yield(
                    value=cast(ast3.expr, self.py_ast_val(nd.expr)) if nd.expr else None
                )
            )
        ];
    } else {
        nd.gen.py_ast = [
            self.sync(
                ast3.YieldFrom(
                    value=cast(ast3.expr, self.py_ast_val(nd.expr))
                        if nd.expr
                        else self.sync(ast3.Constant(value=None))
                )
            )
        ];
    }
}

impl PyastGenPass.exit_visit_stmt(nd: uni.VisitStmt) -> None {
    loc = self.sync(
        ast3.Name(id='self', ctx=ast3.Load())
            if nd.from_walker
            else ast3.Name(id=Con.VISITOR.value, ctx=ast3.Load())
    );
    visit_call = self.sync(
        ast3.Call(
            func=self.jaclib_obj('visit'),
            args=cast(`list[ast3.expr], [loc, self.py_ast_val(nd.target)]),
            keywords=[]
        )
    );
    if (nd.insert_loc is not None) {
        visit_call.keywords.append(
            self.sync(
                ast3.keyword(
                    arg='insert_loc',
                    value=cast(ast3.expr, self.py_ast_val(nd.insert_loc))
                )
            )
        );
    }
    nd.gen.py_ast = [
        self.sync(
            ast3.If(
                `test=self.sync(
                    ast3.UnaryOp(op=self.sync(ast3.Not()), operand=visit_call)
                ),
                body=cast(`list[ast3.stmt], nd.else_body.gen.py_ast),
                orelse=[]
            )
        )
            if nd.else_body
            else self.sync(ast3.Expr(value=visit_call))
    ];
}

impl PyastGenPass.exit_disengage_stmt(nd: uni.DisengageStmt) -> None {
    loc = self.sync(
        ast3.Name(id='self', ctx=ast3.Load())
            if nd.from_walker
            else ast3.Name(id=Con.VISITOR.value, ctx=ast3.Load())
    );
    nd.gen.py_ast = [
        self.sync(
            ast3.Expr(
                self.sync(
                    ast3.Call(
                        func=self.jaclib_obj('disengage'), args=[loc], keywords=[]
                    )
                )
            )
        ),
        self.sync(ast3.Return())
    ];
}

impl PyastGenPass.exit_await_expr(nd: uni.AwaitExpr) -> None {
    nd.gen.py_ast = [
        self.sync(ast3.Await(value=cast(ast3.expr, self.py_ast_val(nd.target))))
    ];
}

impl PyastGenPass.exit_global_stmt(nd: uni.GlobalStmt) -> None {
    py_nodes = [];
    for x in nd.target {
        py_nodes.append(self.sync(ast3.Global(names=[x.sym_name]), jac_node=x));
    }
    nd.gen.py_ast = [*py_nodes];
}

impl PyastGenPass.exit_non_local_stmt(nd: uni.NonLocalStmt) -> None {
    py_nodes = [];
    for x in nd.target {
        py_nodes.append(self.sync(ast3.Nonlocal(names=[x.sym_name]), jac_node=x));
    }
    nd.gen.py_ast = [*py_nodes];
}

impl PyastGenPass.exit_assignment(nd: uni.Assignment) -> None {
    value = self.py_ast_val(nd.value)
        if nd.value
        else self.sync(
            ast3.Call(
                func=self.sync(ast3.Name(id='auto', ctx=ast3.Load())),
                args=[],
                keywords=[]
            )
        )
            if nd.is_enum_stmt
            else None if nd.type_tag else self.ice();
    targets_ast = [cast(ast3.expr, self.py_ast_val(t)) for t in nd.target];
    hoisted = self._hoisted_funcs[:];
    self._hoisted_funcs.clear();
    if nd.type_tag {
        assignment_stmt: ast3.AnnAssign | ast3.Assign | ast3.AugAssign = self.sync(
            ast3.AnnAssign(
                target=cast(ast3.Name, targets_ast[0]),
                annotation=cast(ast3.expr, self.py_ast_val(nd.type_tag)),
                value=cast(ast3.expr, self.py_ast_val(nd.value)) if nd.value else None,
                simple=int(isinstance(targets_ast[0], ast3.Name))
            )
        );
    } elif nd.aug_op {
        assignment_stmt = self.sync(
            ast3.AugAssign(
                target=cast(ast3.Name, targets_ast[0]),
                op=cast(ast3.operator, self.py_ast_val(nd.aug_op)),
                value=cast(ast3.expr, value)
                    if isinstance(value, ast3.expr)
                    else ast3.Constant(value=None)
            )
        );
    } else {
        assignment_stmt = self.sync(
            ast3.Assign(
                targets=cast(`list[ast3.expr], targets_ast),
                value=cast(ast3.expr, value)
                    if isinstance(value, ast3.expr)
                    else ast3.Constant(value=None)
            )
        );
    }
    nd.gen.py_ast = [*hoisted, assignment_stmt];
}

impl PyastGenPass.exit_binary_expr(nd: uni.BinaryExpr) -> None {
    if isinstance(nd.op, uni.ConnectOp) {
        left = self.py_ast_val(nd.right)
            if (nd.op.edge_dir == EdgeDir.IN)
            else self.py_ast_val(nd.left);
        right = self.py_ast_val(nd.left)
            if (nd.op.edge_dir == EdgeDir.IN)
            else self.py_ast_val(nd.right);
        keywords = [
            self.sync(ast3.keyword(arg='left', value=cast(ast3.expr, left))),
            self.sync(ast3.keyword(arg='right', value=cast(ast3.expr, right)))
        ];
        if nd.op.conn_type {
            keywords.append(
                self.sync(
                    ast3.keyword(
                        arg='edge',
                        value=cast(ast3.expr, self.py_ast_val(nd.op.conn_type))
                    )
                )
            );
        }
        if (nd.op.edge_dir == EdgeDir.ANY) {
            keywords.append(
                self.sync(
                    ast3.keyword(
                        arg='undir', value=self.sync(ast3.Constant(value=True))
                    )
                )
            );
        }
        if nd.op.conn_assign {
            keywords.append(
                self.sync(
                    ast3.keyword(
                        arg='conn_assign',
                        value=cast(ast3.expr, self.py_ast_val(nd.op.conn_assign))
                    )
                )
            );
        }
        nd.gen.py_ast = [
            self.sync(
                ast3.Call(func=self.jaclib_obj('connect'), args=[], keywords=keywords)
            )
        ];
    } elif isinstance(nd.op, uni.DisconnectOp) {
        keywords = [
            self.sync(
                ast3.keyword(
                    arg='left', value=cast(ast3.expr, self.py_ast_val(nd.left))
                )
            ),
            self.sync(
                ast3.keyword(
                    arg='right', value=cast(ast3.expr, self.py_ast_val(nd.right))
                )
            )
        ];
        if (nd.op.edge_spec.edge_dir != EdgeDir.OUT) {
            keywords.append(
                self.sync(
                    ast3.keyword(
                        arg='EdgeDir',
                        value=self.sync(
                            ast3.Attribute(
                                value=self.jaclib_obj('EdgeDir'),
                                attr=nd.op.edge_spec.edge_dir.name,
                                ctx=ast3.Load()
                            )
                        )
                    )
                )
            );
        }
        if nd.op.edge_spec.filter_cond {
            keywords.append(
                self.sync(
                    ast3.keyword(
                        arg='filter_on',
                        value=cast(
                            ast3.expr, self.py_ast_val(nd.op.edge_spec.filter_cond)
                        )
                    )
                )
            );
        }
        nd.gen.py_ast = [
            self.sync(
                ast3.Call(
                    func=self.jaclib_obj('disconnect'), args=[], keywords=keywords
                )
            )
        ];
    } elif (nd.op.name in [Tok.KW_AND.value, Tok.KW_OR.value]) {
        nd.gen.py_ast = [
            self.sync(
                ast3.BoolOp(
                    op=cast(ast3.boolop, self.py_ast_val(nd.op)),
                    values=[
                        cast(ast3.expr, self.py_ast_val(nd.left)),
                        cast(ast3.expr, self.py_ast_val(nd.right))
                    ]
                )
            )
        ];
    } elif (
        (nd.op.name in [Tok.WALRUS_EQ])
        and isinstance(self.py_ast_val(nd.left), ast3.Name)
    ) {
        self.py_ast_val(nd.left).ctx = ast3.Store();
        nd.gen.py_ast = [
            self.sync(
                ast3.NamedExpr(
                    target=cast(ast3.Name, self.py_ast_val(nd.left)),
                    value=cast(ast3.expr, self.py_ast_val(nd.right))
                )
            )
        ];
    } elif (nd.op.gen.py_ast and isinstance(self.py_ast_val(nd.op), ast3.AST)) {
        nd.gen.py_ast = [
            self.sync(
                ast3.BinOp(
                    left=cast(ast3.expr, self.py_ast_val(nd.left)),
                    right=cast(ast3.expr, self.py_ast_val(nd.right)),
                    op=cast(ast3.operator, self.py_ast_val(nd.op))
                )
            )
        ];
    } else {
        nd.gen.py_ast = self.translate_jac_bin_op(nd);
    }
}

impl PyastGenPass.translate_jac_bin_op(nd: uni.BinaryExpr) -> list[ast3.AST] {
    if isinstance(nd.op, (uni.DisconnectOp, uni.ConnectOp)) {
        raise self.ice();
    } elif (nd.op.name in [Tok.PIPE_FWD, Tok.A_PIPE_FWD]) {
        func_node = uni.FuncCall(
            target=nd.right,
            params=`list(nd.left.values)
                if (isinstance(nd.left, uni.TupleVal) and nd.left.values)
                else [nd.left],
            genai_call=None,
            kid=nd.kid
        );
        func_node.parent = nd.parent;
        self.exit_func_call(func_node);
        return func_node.gen.py_ast;
    } elif (nd.op.name in [Tok.KW_SPAWN]) {
        return [
            self.sync(
                ast3.Call(
                    func=self.jaclib_obj('spawn'),
                    args=cast(
                        `list[ast3.expr],
                        [self.py_ast_val(nd.left), self.py_ast_val(nd.right)]
                    ),
                    keywords=[]
                )
            )
        ];
    } elif (nd.op.name in [Tok.PIPE_BKWD, Tok.A_PIPE_BKWD]) {
        func_node = uni.FuncCall(
            target=nd.left,
            params=`list(nd.right.values)
                if (isinstance(nd.right, uni.TupleVal) and nd.right.values)
                else [nd.right],
            genai_call=None,
            kid=nd.kid
        );
        func_node.parent = nd.parent;
        self.exit_func_call(func_node);
        return func_node.gen.py_ast;
    } elif (nd.op.name in [Tok.KW_BY]) {
        return [
            self.sync(
                ast3.Call(
                    func=self.jaclib_obj('by_operator'),
                    args=cast(
                        `list[ast3.expr],
                        [self.py_ast_val(nd.left), self.py_ast_val(nd.right)]
                    ),
                    keywords=[]
                )
            )
        ];
    } elif ((nd.op.name == Tok.PIPE_FWD) and isinstance(nd.right, uni.TupleVal)) {
        self.emit(E5006);
    } else {
        self.emit(E5007, op=str(nd.op.value));
    }
    return [];
}

impl PyastGenPass.exit_compare_expr(nd: uni.CompareExpr) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.Compare(
                left=cast(ast3.expr, self.py_ast_val(nd.left)),
                comparators=[cast(ast3.expr, self.py_ast_val(i)) for i in nd.rights],
                ops=[cast(ast3.cmpop, self.py_ast_val(i)) for i in nd.ops]
            )
        )
    ];
}

"""CfgExpr: propagate inner expression's generated Python AST."""
impl PyastGenPass.exit_cfg_expr(nd: uni.CfgExpr) -> None {
    nd.gen.py_ast = nd.expr.gen.py_ast;
}

impl PyastGenPass.exit_bool_expr(nd: uni.BoolExpr) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.BoolOp(
                op=cast(ast3.boolop, self.py_ast_val(nd.op)),
                values=[cast(ast3.expr, self.py_ast_val(i)) for i in nd.values]
            )
        )
    ];
}

impl PyastGenPass.exit_lambda_expr(nd: uni.LambdaExpr) -> None {
    if isinstance(nd.body, `list) {
        if (nd.signature and nd.signature.gen.py_ast) {
            arguments = cast(ast3.arguments, self.py_ast_val(nd.signature));
        } else {
            arguments = self.sync(
                ast3.arguments(
                    posonlyargs=[], args=[], kwonlyargs=[], kw_defaults=[], defaults=[]
                ),
                jac_node=nd
            );
        }
        body_stmts = [
            cast(ast3.stmt, stmt) for stmt in self.resolve_stmt_block(nd.body, doc=None)
        ];
        if not body_stmts {
            body_stmts = [self.sync(ast3.Pass(), jac_node=nd)];
        }
        func_name = self._next_temp_name('lambda');
        returns = cast(ast3.expr, self.py_ast_val(nd.signature.return_type))
            if (
                nd.signature
                and nd.signature.return_type
                and nd.signature.return_type.gen.py_ast
            )
            else None;
        func_def = self.sync(
            ast3.FunctionDef(
                name=func_name,
                args=arguments,
                body=body_stmts,
                decorator_list=[],
                returns=returns,
                type_params=[]
            ),
            jac_node=nd
        );
        nd.gen.py_ast = [
            self._function_expr_from_def(
                func_def=func_def,
                jac_node=nd,
                filename_hint=f"<jac_lambda:{func_name}>"
            )
        ];
        return;
    }
    if nd.signature {
        self._remove_lambda_param_annotations(nd.signature);
    }
    if (nd.signature and nd.signature.gen.py_ast) {
        arguments = cast(ast3.arguments, self.py_ast_val(nd.signature));
    } else {
        arguments = self.sync(
            ast3.arguments(
                posonlyargs=[], args=[], kwonlyargs=[], kw_defaults=[], defaults=[]
            ),
            jac_node=nd
        );
    }
    body_node = cast(uni.Expr, nd.body);
    body_expr = cast(ast3.expr, self.py_ast_val(body_node));
    nd.gen.py_ast = [
        self.sync(ast3.Lambda(args=arguments, body=body_expr), jac_node=nd)
    ];
}

impl PyastGenPass._remove_lambda_param_annotations(
    signature: uni.FuncSignature
) -> None {
    for param in signature.params {
        if (param.gen.py_ast and isinstance(self.py_ast_val(param), ast3.arg)) {
            self.py_ast_val(param).annotation = None;
        }
    }
}

impl PyastGenPass.exit_unary_expr(nd: uni.UnaryExpr) -> None {
    op_tok = Tok(nd.op.name) if (nd.op.name in Tok.__members__) else None;
    op_cls = UNARY_OP_MAP.get(op_tok) if op_tok else None;
    if op_cls {
        nd.gen.py_ast = [
            self.sync(
                ast3.UnaryOp(
                    op=self.sync(op_cls()),
                    operand=cast(ast3.expr, self.py_ast_val(nd.operand))
                )
            )
        ];
        return;
    } elif (nd.op.name in [Tok.PIPE_FWD, Tok.KW_SPAWN, Tok.A_PIPE_FWD]) {
        nd.gen.py_ast = [
            self.sync(
                ast3.Call(
                    func=cast(ast3.expr, self.py_ast_val(nd.operand)),
                    args=[],
                    keywords=[]
                )
            )
        ];
    } elif (nd.op.name in [Tok.STAR_MUL]) {
        ctx_val = nd.operand.py_ctx_func()
            if isinstance(nd.operand, uni.AstSymbolNode)
            else ast3.Load();
        nd.gen.py_ast = [
            self.sync(
                ast3.Starred(
                    value=cast(ast3.expr, self.py_ast_val(nd.operand)),
                    ctx=cast(ast3.expr_context, ctx_val)
                )
            )
        ];
    } elif (nd.op.name in [Tok.STAR_POW]) {
        nd.gen.py_ast = nd.operand.gen.py_ast;
    } elif (nd.op.name in [Tok.BW_AND]) {
        nd.gen.py_ast = [
            self.sync(
                ast3.Call(
                    func=self.builtin_name('jobj'),
                    args=[],
                    keywords=[
                        self.sync(
                            ast3.keyword(
                                arg='id',
                                value=cast(ast3.expr, self.py_ast_val(nd.operand))
                            )
                        )
                    ]
                )
            )
        ];
    } else {
        self.ice("Unknown Unary operator " + str(nd.op.value));
    }
}

impl PyastGenPass.exit_if_else_expr(nd: uni.IfElseExpr) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.IfExp(
                `test=cast(ast3.expr, self.py_ast_val(nd.condition)),
                body=cast(ast3.expr, self.py_ast_val(nd.value)),
                orelse=cast(ast3.expr, self.py_ast_val(nd.else_value))
            )
        )
    ];
}

impl PyastGenPass.exit_multi_string(nd: uni.MultiString) -> None {
    def get_pieces(str_seq: Sequence) -> list[(str | ast3.AST)] {
        pieces: list[(str | ast3.AST)] = [];
        for i in str_seq {
            if isinstance(i, uni.String) {
                pieces.append(i.lit_value);
            } elif isinstance(i, (uni.FString, uni.ExprStmt)) {
                pieces.append(self.py_ast_val(i));
            } elif (
                isinstance(i, uni.Token) and (i.name in [Tok.LBRACE, Tok.RBRACE])
            ) {
                continue;
            } else {
                raise self.ice('Multi string made of something weird.');
            }
        }
        return pieces;
    }
    combined_multi: list[str | bytes | ast3.AST] = [];
    for item in get_pieces(nd.strings) {
        if (
            combined_multi
            and isinstance(item, str)
            and isinstance(combined_multi[-1], str)
        ) {
            if isinstance(combined_multi[-1], str) {
                combined_multi[-1] += item;
            }
        } elif (
            combined_multi
            and isinstance(item, `bytes)
            and isinstance(combined_multi[-1], `bytes)
        ) {
            combined_multi[-1] += item;
        } else {
            combined_multi.append(item);
        }
    }
    for (i, val) in enumerate(combined_multi) {
        if isinstance(val, (str, `bytes)) {
            combined_multi[i] = self.sync(ast3.Constant(value=val));
        }
    }
    if (
        (len(combined_multi) > 1) or not isinstance(combined_multi[0], ast3.Constant)
    ) {
        nd.gen.py_ast = [
            self.sync(
                ast3.JoinedStr(values=[cast(ast3.expr, nd) for nd in combined_multi])
            )
        ];
    } else {
        nd.gen.py_ast = [combined_multi[0]];
    }
}

impl PyastGenPass.exit_f_string(nd: uni.FString) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.JoinedStr(
                values=[
                    cast(ast3.expr, self.py_ast_val(part))
                    for part in nd.parts
                    if part.gen.py_ast
                ]
            )
        )
    ];
}

impl PyastGenPass.exit_formatted_value(nd: uni.FormattedValue) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.FormattedValue(
                value=cast(ast3.expr, self.py_ast_val(nd.format_part)),
                conversion=nd.conversion,
                format_spec=cast(ast3.expr, self.py_ast_val(nd.format_spec))
                    if nd.format_spec
                    else None
            )
        )
    ];
}

impl PyastGenPass.exit_list_val(nd: uni.ListVal) -> None {
    elts = [cast(ast3.expr, self.py_ast_val(v)) for v in nd.values];
    ctx = ast3.Load()
        if isinstance(nd.py_ctx_func(), ast3.Load)
        else cast(ast3.expr_context, nd.py_ctx_func());
    nd.gen.py_ast = [self.sync(ast3.List(elts=elts, ctx=ctx))];
}

impl PyastGenPass.exit_set_val(nd: uni.SetVal) -> None {
    elts = [cast(ast3.expr, self.py_ast_val(i)) for i in nd.values];
    nd.gen.py_ast = [self.sync(ast3.Set(elts=elts))];
}

impl PyastGenPass.exit_tuple_val(nd: uni.TupleVal) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.Tuple(
                elts=[cast(ast3.expr, self.py_ast_val(i)) for i in nd.values],
                ctx=cast(ast3.expr_context, nd.py_ctx_func())
            )
        )
    ];
}

impl PyastGenPass.exit_dict_val(nd: uni.DictVal) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.Dict(
                keys=[
                    cast(ast3.expr, self.py_ast_val(x.key)) if x.key else None
                    for x in nd.kv_pairs
                ],
                values=[cast(ast3.expr, self.py_ast_val(x.value)) for x in nd.kv_pairs]
            )
        )
    ];
}

impl PyastGenPass.exit_k_v_pair(nd: uni.KVPair) -> None {
    ;
}

impl PyastGenPass.exit_k_w_pair(nd: uni.KWPair) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.keyword(
                arg=self.py_ast_val(nd.key).id
                    if (nd.key and isinstance(self.py_ast_val(nd.key), ast3.Name))
                    else None,
                value=cast(ast3.expr, self.py_ast_val(nd.value))
            )
        )
    ];
}

impl PyastGenPass.exit_inner_compr(nd: uni.InnerCompr) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.comprehension(
                target=cast(ast3.expr, self.py_ast_val(nd.target)),
                iter=cast(ast3.expr, self.py_ast_val(nd.collection)),
                ifs=[cast(ast3.expr, self.py_ast_val(x)) for x in nd.conditional]
                    if nd.conditional
                    else [],
                is_async=0
            )
        )
    ];
}

impl PyastGenPass.exit_list_compr(nd: uni.ListCompr) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.ListComp(
                elt=cast(ast3.expr, self.py_ast_val(nd.out_expr)),
                generators=cast(
                    `list[ast3.comprehension], [self.py_ast_val(i) for i in nd.compr]
                )
            )
        )
    ];
}

impl PyastGenPass.exit_gen_compr(nd: uni.GenCompr) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.GeneratorExp(
                elt=cast(ast3.expr, self.py_ast_val(nd.out_expr)),
                generators=[
                    cast(ast3.comprehension, self.py_ast_val(i)) for i in nd.compr
                ]
            )
        )
    ];
}

impl PyastGenPass.exit_set_compr(nd: uni.SetCompr) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.SetComp(
                elt=cast(ast3.expr, self.py_ast_val(nd.out_expr)),
                generators=[
                    cast(ast3.comprehension, self.py_ast_val(i)) for i in nd.compr
                ]
            )
        )
    ];
}

impl PyastGenPass.exit_dict_compr(nd: uni.DictCompr) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.DictComp(
                key=cast(ast3.expr, self.py_ast_val(nd.kv_pair.key))
                    if nd.kv_pair.key
                    else cast(ast3.expr, ast3.Constant(value=None)),
                value=cast(ast3.expr, self.py_ast_val(nd.kv_pair.value)),
                generators=[
                    cast(ast3.comprehension, self.py_ast_val(i)) for i in nd.compr
                ]
            )
        )
    ];
}

impl PyastGenPass.exit_atom_trailer(nd: uni.AtomTrailer) -> None {
    if nd.is_genai {
        nd.gen.py_ast = [];
    }
    if nd.is_attr {
        if isinstance(nd.right, uni.AstSymbolNode) {
            nd.gen.py_ast = [
                self.sync(
                    ast3.Attribute(
                        value=cast(ast3.expr, self.py_ast_val(nd.target)),
                        attr=self._py_name(nd.right),
                        ctx=cast(ast3.expr_context, nd.right.py_ctx_func())
                    )
                )
            ];
        } else {
            self.emit(E5008);
        }
    } elif isinstance(nd.right, uni.FilterCompr) {
        # Fusion: if target is an EdgeRefTrailer (non-edge-only, non-async),
        # inject the filter as a post_filter kwarg on the refs() call instead
        # of wrapping with filter_on(). This enables the topology index to
        # optimize the type filter.
        if (
            isinstance(nd.target, uni.EdgeRefTrailer)
            and not nd.target.edges_only
            and not nd.target.is_async
        ) {
            target_py = cast(ast3.Call, self.py_ast_val(nd.target));
            target_py.keywords.append(
                self.sync(
                    ast3.keyword(
                        arg='post_filter',
                        value=cast(ast3.expr, self.py_ast_val(nd.right))
                    )
                )
            );
            nd.gen.py_ast = [target_py];
        } else {
            nd.gen.py_ast = [
                self.sync(
                    ast3.Call(
                        func=self.jaclib_obj('filter_on'),
                        args=[],
                        keywords=[
                            self.sync(
                                ast3.keyword(
                                    arg='items',
                                    value=cast(ast3.expr, self.py_ast_val(nd.target))
                                )
                            ),
                            self.sync(
                                ast3.keyword(
                                    arg='func',
                                    value=cast(ast3.expr, self.py_ast_val(nd.right))
                                )
                            )
                        ]
                    )
                )
            ];
        }
    } elif isinstance(nd.right, uni.AssignCompr) {
        nd.gen.py_ast = [
            self.sync(
                ast3.Call(
                    func=self.jaclib_obj('assign_all'),
                    args=cast(
                        `list[ast3.expr],
                        [self.py_ast_val(nd.target), self.py_ast_val(nd.right)]
                    ),
                    keywords=[]
                )
            )
        ];
    } elif (
        isinstance(nd.right, uni.IndexSlice)
        and nd.right.is_range
        and len(nd.right.slices) == 1
        and self._is_edge_ref_target(nd.target)
    ) {
        # Pushdown fusion: a slice chained on an edge-ref result becomes a
        # `slc=slice(...)` kwarg on the Jac.refs() call so the runtime can
        # bound the storage-layer load to the sliced subset, not all neighbors.
        target_py = cast(ast3.Call, self.py_ast_val(nd.target));
        slc = nd.right.slices[0];
        start_ast = (
            cast(ast3.expr, self.py_ast_val(slc.start))
                if slc.start
                else self.sync(ast3.Constant(value=None))
        );
        stop_ast = (
            cast(ast3.expr, self.py_ast_val(slc.stop))
                if slc.stop
                else self.sync(ast3.Constant(value=None))
        );
        step_ast = (
            cast(ast3.expr, self.py_ast_val(slc.step))
                if slc.step
                else self.sync(ast3.Constant(value=None))
        );
        # `slice` is a Python builtin — emit a bare Name (not via builtin_name,
        # which would also try to add it to the builtin imports table).
        slice_call = self.sync(
            ast3.Call(
                func=self.sync(ast3.Name(id='slice', ctx=ast3.Load())),
                args=[start_ast, stop_ast, step_ast],
                keywords=[]
            )
        );
        target_py.keywords.append(self.sync(ast3.keyword(arg='slc', value=slice_call)));
        nd.gen.py_ast = [target_py];
    } else {
        nd.gen.py_ast = [
            self.sync(
                ast3.Subscript(
                    value=cast(ast3.expr, self.py_ast_val(nd.target)),
                    slice=cast(ast3.expr, self.py_ast_val(nd.right)),
                    ctx=cast(ast3.expr_context, nd.right.py_ctx_func())
                        if isinstance(nd.right, uni.AstSymbolNode)
                        else ast3.Load()
                )
            )
        ];
        self.py_ast_val(nd.right).ctx = ast3.Load();
    }
    if nd.is_null_ok {
        walrus_assign = self.sync(
            ast3.NamedExpr(
                target=self.sync(ast3.Name(id='__jac_tmp', ctx=ast3.Store())),
                value=cast(ast3.expr, self.py_ast_val(nd.target))
            )
        );
        tmp_ref = self.sync(ast3.Name(id='__jac_tmp', ctx=ast3.Load()));
        none_const = self.sync(ast3.Constant(value=None));
        body_expr: ast3.expr;
        if isinstance(self.py_ast_val(nd), ast3.Attribute) {
            body_expr = self.sync(
                ast3.Call(
                    func=self.sync(ast3.Name(id='getattr', ctx=ast3.Load())),
                    args=[
                        tmp_ref,
                        self.sync(ast3.Constant(value=self.py_ast_val(nd).attr)),
                        none_const
                    ],
                    keywords=[]
                )
            );
        } elif isinstance(self.py_ast_val(nd), ast3.Call) {
            call_node = self.py_ast_val(nd);
            if (
                isinstance(call_node.func, ast3.Attribute)
                or (
                    isinstance(call_node.func, ast3.Name)
                    and (call_node.func.id == 'filter_on')
                )
            ) {
                for kw in call_node.keywords {
                    if (kw.arg == 'items') {
                        kw.value = tmp_ref;
                    }
                }
            }
            if (
                (
                    isinstance(call_node.func, ast3.Attribute)
                    or (
                        isinstance(call_node.func, ast3.Name)
                        and (call_node.func.id == 'assign_all')
                    )
                )
                and call_node.args
            ) {
                call_node.args[0] = tmp_ref;
            }
            body_expr = cast(ast3.expr, call_node);
        } else {
            if isinstance(self.py_ast_val(nd), ast3.Subscript) {
                index_expr = self.py_ast_val(nd).slice;
                body_expr = self.sync(
                    ast3.Call(
                        func=self.jaclib_obj('safe_subscript'),
                        args=[tmp_ref, index_expr],
                        keywords=[]
                    )
                );
            } else {
                self.py_ast_val(nd).value = tmp_ref;
                body_expr = cast(ast3.expr, self.py_ast_val(nd));
            }
        }
        nd.gen.py_ast = [
            self.sync(
                ast3.IfExp(
                    `test=self.sync(
                        ast3.Compare(
                            left=walrus_assign,
                            ops=[self.sync(ast3.IsNot())],
                            comparators=[none_const]
                        )
                    ),
                    body=body_expr,
                    orelse=none_const
                )
            )
        ];
    }
}

impl PyastGenPass.exit_atom_unit(nd: uni.AtomUnit) -> None {
    if (
        isinstance(nd.value, uni.Ability)
        and nd.value.gen.py_ast
        and isinstance(
            self.py_ast_val(nd.value), (ast3.FunctionDef, ast3.AsyncFunctionDef)
        )
    ) {
        func_ast = cast(
            (ast3.FunctionDef | ast3.AsyncFunctionDef), self.py_ast_val(nd.value)
        );
        nd.gen.py_ast = [
            self._function_expr_from_def(
                func_def=func_ast,
                jac_node=nd,
                filename_hint=f"<jac_iife:{func_ast.name}>"
            )
        ];
        return;
    }
    nd.gen.py_ast = nd.value.gen.py_ast;
}

"""Generate the arguments for a function call."""
impl PyastGenPass.gen_call_args(
    nd: uni.FuncCall
) -> tuple[(list[ast3.expr], list[ast3.keyword])] {
    args = [];
    keywords = [];
    if nd.params {
        for x in nd.params {
            if (isinstance(x, uni.UnaryExpr) and (x.op.name == Tok.STAR_POW)) {
                keywords.append(
                    self.sync(
                        ast3.keyword(value=cast(ast3.expr, self.py_ast_val(x.operand))),
                        x
                    )
                );
            } elif isinstance(x, uni.Expr) {
                args.append(cast(ast3.expr, self.py_ast_val(x)));
            } elif (
                isinstance(x, uni.KWPair)
                and isinstance(self.py_ast_val(x), ast3.keyword)
            ) {
                keywords.append(self.py_ast_val(x));
            } else {
                self.ice('Invalid Parameter');
            }
        }
    }
    return (args, keywords);
}

impl PyastGenPass.exit_func_call(nd: uni.FuncCall) -> None {
    if nd.genai_call {
        self.ice('Type(by llm()) call feature is temporarily disabled.');
    } else {
        # Deprecated `root()` form: bare `root` already lowers to Jac.root() in
        # exit_special_var_ref, so wrapping it in another call would produce
        # `Jac.root()()` (a Root instance called as a function). The W0062
        # diagnostic for this is emitted by the type evaluator; here we just
        # reuse the inner lowering so codegen stays correct.
        if isinstance(nd.target, uni.SpecialVarRef)
        and nd.target.name == Tok.KW_ROOT
        and (nd.params is None or len(nd.params) == 0) {
            nd.gen.py_ast = nd.target.gen.py_ast;
            return;
        }
        # TODO: Primitive emitter dispatch hook.
        # When type information is available, primitive method calls
        # (e.g., mylist.append(x), s.upper()) and builtin function calls
        # (e.g., len(x), print(x)) can be routed through the emitter
        # infrastructure at jaclang.jac0core.passes.primitives_py.
        # For the Python backend this is a pass-through (no behavior change),
        # but wiring it in validates the dispatch mechanism.
        # Integration point: check if nd.target is an AtomTrailer on a
        # primitive type, then call PyListEmitter/PyStrEmitter/etc.
        func = self.py_ast_val(nd.target);
        (args, keywords) = self.gen_call_args(nd);
        nd.gen.py_ast = [
            self.sync(
                ast3.Call(
                    func=cast(ast3.expr, func),
                    args=[cast(ast3.expr, arg) for arg in args],
                    keywords=keywords
                )
            )
        ];
    }
}

impl PyastGenPass.exit_index_slice(nd: uni.IndexSlice) -> None {
    if nd.is_range {
        if (len(nd.slices) > 1) {
            nd.gen.py_ast = [
                self.sync(
                    ast3.Tuple(
                        elts=[
                            self.sync(
                                ast3.Slice(
                                    lower=cast(ast3.expr, self.py_ast_val(slice.start))
                                        if slice.start
                                        else None,
                                    upper=cast(ast3.expr, self.py_ast_val(slice.stop))
                                        if slice.stop
                                        else None,
                                    step=cast(ast3.expr, self.py_ast_val(slice.step))
                                        if slice.step
                                        else None
                                )
                            ) for slice in nd.slices
                        ],
                        ctx=ast3.Load()
                    )
                )
            ];
        } elif (len(nd.slices) == 1) {
            slice = nd.slices[0];
            nd.gen.py_ast = [
                self.sync(
                    ast3.Slice(
                        lower=cast(ast3.expr, self.py_ast_val(slice.start))
                            if slice.start
                            else None,
                        upper=cast(ast3.expr, self.py_ast_val(slice.stop))
                            if slice.stop
                            else None,
                        step=cast(ast3.expr, self.py_ast_val(slice.step))
                            if slice.step
                            else None
                    )
                )
            ];
        }
    } elif ((len(nd.slices) > 0) and (nd.slices[0].start is not None)) {
        nd.gen.py_ast = nd.slices[0].start.gen.py_ast;
    } else {
        nd.gen.py_ast = [];
    }
}

impl PyastGenPass.exit_special_var_ref(nd: uni.SpecialVarRef) -> None {
    if (nd.name == Tok.KW_SUPER) {
        nd.gen.py_ast = [
            self.sync(
                ast3.Call(
                    func=self.sync(ast3.Name(id='super', ctx=nd.py_ctx_func())),
                    args=[],
                    keywords=[]
                )
            )
        ];
    } elif (nd.name == Tok.KW_ROOT) {
        nd.gen.py_ast = [
            self.sync(ast3.Call(func=self.jaclib_obj('root'), args=[], keywords=[]))
        ];
    } else {
        nd.gen.py_ast = [
            self.sync(ast3.Name(id=self._py_name(nd), ctx=nd.py_ctx_func()))
        ];
    }
}

impl PyastGenPass.exit_edge_ref_trailer(nd: uni.EdgeRefTrailer) -> None {
    origin = None;
    cur = nd.chain[0];
    chomp = [*nd.chain[1:]];
    from_visit = bool(isinstance(nd.parent, uni.VisitStmt));
    if not isinstance(cur, uni.EdgeOpRef) {
        origin = self.py_ast_val(cur);
        cur = cast(uni.EdgeOpRef, chomp.pop(0));
    }
    pynode = self.sync(
        ast3.Call(
            func=self.jaclib_obj('OPath'),
            args=[cast(ast3.expr, (origin or self.py_ast_val(cur)))],
            keywords=[]
        )
    );
    while True {
        keywords = [];
        if cur.filter_cond {
            keywords.append(
                self.sync(
                    ast3.keyword(
                        arg='edge',
                        value=cast(
                            ast3.expr, self.sync(self.py_ast_val(cur.filter_cond))
                        )
                    )
                )
            );
        }
        if (chomp and not isinstance(chomp[0], uni.EdgeOpRef)) {
            filt = chomp.pop(0);
            keywords.append(
                self.sync(
                    ast3.keyword(
                        arg='nd',
                        value=cast(ast3.expr, self.sync(self.py_ast_val(filt)))
                    )
                )
            );
        }
        pynode = self.sync(
            ast3.Call(
                func=self.sync(
                    ast3.Attribute(
                        value=pynode,
                        attr=f"edge_{cur.edge_dir.name.lower()}",
                        ctx=ast3.Load()
                    )
                ),
                args=[],
                keywords=keywords
            )
        );
        if chomp {
            cur = cast(uni.EdgeOpRef, chomp.pop(0));
        } else {
            break;
        }
    }
    if nd.edges_only {
        pynode = self.sync(
            ast3.Call(
                func=self.sync(
                    ast3.Attribute(value=pynode, attr='edge', ctx=ast3.Load())
                ),
                args=[],
                keywords=[]
            )
        );
    }
    if from_visit {
        pynode = self.sync(
            ast3.Call(
                func=self.sync(
                    ast3.Attribute(value=pynode, attr='visit', ctx=ast3.Load())
                ),
                args=[],
                keywords=[]
            )
        );
    }
    if nd.is_async {
        pynode = self.sync(
            ast3.Call(func=self.jaclib_obj('arefs'), args=[pynode], keywords=[])
        );
    } else {
        pynode = self.sync(
            ast3.Call(func=self.jaclib_obj('refs'), args=[pynode], keywords=[])
        );
    }
    nd.gen.py_ast = [pynode];
}

impl PyastGenPass.exit_edge_op_ref(nd: uni.EdgeOpRef) -> None {
    loc = self.sync(
        ast3.Name(id=Con.HERE.value, ctx=ast3.Load())
            if nd.from_walker
            else ast3.Name(id='self', ctx=ast3.Load())
    );
    nd.gen.py_ast = [loc];
}

impl PyastGenPass.exit_disconnect_op(nd: uni.DisconnectOp) -> None {
    nd.gen.py_ast = nd.edge_spec.gen.py_ast;
}

impl PyastGenPass.exit_connect_op(nd: uni.ConnectOp) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.Call(
                func=self.jaclib_obj('build_edge'),
                args=[],
                keywords=[
                    self.sync(
                        ast3.keyword(
                            arg='is_undirected',
                            value=self.sync(
                                ast3.Constant(value=(nd.edge_dir == EdgeDir.ANY))
                            )
                        )
                    ),
                    self.sync(
                        ast3.keyword(
                            arg='conn_type',
                            value=cast(ast3.expr, self.py_ast_val(nd.conn_type))
                                if nd.conn_type
                                else self.sync(ast3.Constant(value=None))
                        )
                    ),
                    self.sync(
                        ast3.keyword(
                            arg='conn_assign',
                            value=cast(ast3.expr, self.py_ast_val(nd.conn_assign))
                                if nd.conn_assign
                                else self.sync(ast3.Constant(value=None))
                        )
                    )
                ]
            )
        )
    ];
}

impl PyastGenPass.exit_filter_compr(nd: uni.FilterCompr) -> None {
    iter_name = 'i';
    comprs: list[(ast3.Compare | ast3.Call)] = [
        self.sync(
            ast3.Call(
                func=self.sync(ast3.Name(id='isinstance', ctx=ast3.Load())),
                args=cast(
                    `list[ast3.expr],
                    [
                        self.sync(ast3.Name(id=iter_name, ctx=ast3.Load())),
                        self.sync(self.py_ast_val(nd.f_type))
                    ]
                ),
                keywords=[]
            )
        )
    ]
        if nd.f_type
        else [];
    comprs.extend(
        self.sync(
            ast3.Compare(
                left=self.sync(
                    ast3.Attribute(
                        value=self.sync(
                            ast3.Name(id=iter_name, ctx=ast3.Load()), jac_node=x
                        ),
                        attr=self.py_ast_val(x).left.id,
                        ctx=ast3.Load()
                    ),
                    jac_node=x
                ),
                ops=self.py_ast_val(x).ops,
                comparators=self.py_ast_val(x).comparators
            ),
            jac_node=x
        )
        for x in nd.compares
        if (
            isinstance(self.py_ast_val(x), ast3.Compare)
            and isinstance(self.py_ast_val(x).left, ast3.Name)
        )
    );
    if (
        body := (
            self.sync(
                ast3.BoolOp(
                    op=self.sync(ast3.And()),
                    values=[cast(ast3.expr, item) for item in comprs]
                )
            )
                if (len(comprs) > 1)
                else comprs[0] if comprs else None
        )
    ) {
        nd.gen.py_ast = [
            self.sync(
                ast3.Lambda(
                    args=self.sync(
                        ast3.arguments(
                            posonlyargs=[],
                            args=[self.sync(ast3.arg(arg=iter_name))],
                            kwonlyargs=[],
                            kw_defaults=[],
                            defaults=[]
                        )
                    ),
                    body=body
                )
            )
        ];
    }
}

impl PyastGenPass.exit_assign_compr(nd: uni.AssignCompr) -> None {
    keys = [];
    values = [];
    for i in nd.assigns {
        if i.key {
            keys.append(self.sync(ast3.Constant(i.key.sym_name)));
            values.append(self.py_ast_val(i.value));
        }
    }
    key_tup = self.sync(
        ast3.Tuple(
            elts=[
                key
                for key in keys
                if isinstance(key, ast3.expr)
            ],
            ctx=ast3.Load()
        )
    );
    val_tup = self.sync(
        ast3.Tuple(
            elts=[
                v
                for v in values
                if isinstance(v, ast3.expr)
            ],
            ctx=ast3.Load()
        )
    );
    nd.gen.py_ast = [self.sync(ast3.Tuple(elts=[key_tup, val_tup], ctx=ast3.Load()))];
}

impl PyastGenPass.exit_match_stmt(nd: uni.MatchStmt) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.Match(
                subject=cast(ast3.expr, self.py_ast_val(nd.target)),
                cases=[cast(ast3.match_case, self.py_ast_val(x)) for x in nd.cases]
            )
        )
    ];
}

impl PyastGenPass.exit_match_case(nd: uni.MatchCase) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.match_case(
                pattern=cast(ast3.pattern, self.py_ast_val(nd.pattern)),
                guard=cast(ast3.expr, self.py_ast_val(nd.guard)) if nd.guard else None,
                body=cast(`list[ast3.stmt], self.resolve_stmt_block(nd.body))
            )
        )
    ];
}

impl PyastGenPass.exit_match_or(nd: uni.MatchOr) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.MatchOr(
                patterns=[cast(ast3.pattern, self.py_ast_val(x)) for x in nd.patterns]
            )
        )
    ];
}

impl PyastGenPass.exit_match_as(nd: uni.MatchAs) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.MatchAs(
                name=nd.name.sym_name,
                pattern=cast(ast3.pattern, self.py_ast_val(nd.pattern))
                    if nd.pattern
                    else None
            )
        )
    ];
}

impl PyastGenPass.exit_match_wild(nd: uni.MatchWild) -> None {
    nd.gen.py_ast = [self.sync(ast3.MatchAs())];
}

impl PyastGenPass.exit_match_value(nd: uni.MatchValue) -> None {
    nd.gen.py_ast = [
        self.sync(ast3.MatchValue(value=cast(ast3.expr, self.py_ast_val(nd.value))))
    ];
}

impl PyastGenPass.exit_match_singleton(nd: uni.MatchSingleton) -> None {
    nd.gen.py_ast = [self.sync(ast3.MatchSingleton(value=nd.value.lit_value))];
}

impl PyastGenPass.exit_match_sequence(nd: uni.MatchSequence) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.MatchSequence(
                patterns=[cast(ast3.pattern, self.py_ast_val(x)) for x in nd.values]
            )
        )
    ];
}

impl PyastGenPass.exit_match_mapping(nd: uni.MatchMapping) -> None {
    mapping = self.sync(ast3.MatchMapping(keys=[], patterns=[], rest=None));
    for i in nd.values {
        if (
            isinstance(i, uni.MatchKVPair)
            and isinstance(i.key, uni.MatchValue)
            and isinstance(self.py_ast_val(i.key.value), ast3.expr)
            and isinstance(self.py_ast_val(i.value), ast3.pattern)
        ) {
            mapping.keys.append(self.py_ast_val(i.key.value));
            mapping.patterns.append(self.py_ast_val(i.value));
        } elif isinstance(i, uni.MatchStar) {
            mapping.rest = i.name.sym_name;
        }
    }
    nd.gen.py_ast = [mapping];
}

impl PyastGenPass.exit_match_k_v_pair(nd: uni.MatchKVPair) -> None {
    ;
}

impl PyastGenPass.exit_match_star(nd: uni.MatchStar) -> None {
    nd.gen.py_ast = [self.sync(ast3.MatchStar(name=nd.name.sym_name))];
}

impl PyastGenPass.exit_match_arch(nd: uni.MatchArch) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.MatchClass(
                cls=cast(ast3.expr, self.py_ast_val(nd.name)),
                patterns=[
                    cast(ast3.pattern, self.py_ast_val(x))
                    for x in (nd.arg_patterns or [])
                ],
                kwd_attrs=[
                    x.key.sym_name
                    for x in (nd.kw_patterns or [])
                    if isinstance(x.key, uni.NameAtom)
                ],
                kwd_patterns=[
                    cast(ast3.pattern, self.py_ast_val(x.value))
                    for x in (nd.kw_patterns or [])
                ]
            )
        )
    ];
}

impl PyastGenPass.exit_token(nd: uni.Token) -> None {
    tok = Tok(nd.name) if (nd.name in Tok.__members__) else None;
    op_cls = TOKEN_AST_MAP.get(tok) if tok else None;
    if op_cls {
        nd.gen.py_ast = [self.sync(op_cls())];
    }
}

impl PyastGenPass.exit_name(nd: uni.Name) -> None {
    name = nd.sym_name;
    if name == "Self" {
        resolved = self._resolve_self_type(nd);
        if resolved is not None {
            nd.gen.py_ast = [resolved];
            return;
        }
    }
    if (name in self._get_builtin_names()) {
        self.builtin_imports.add(name);
    }
    if (name in self._get_ambient_typing_names()) {
        self.typing_imports.add(name);
    }
    nd.gen.py_ast = [self.sync(ast3.Name(id=name, ctx=nd.py_ctx_func()))];
}

"""Resolve Self to the appropriate Python construct based on context."""
impl PyastGenPass._resolve_self_type(nd: uni.Name) -> ast3.expr | None {
    # Find enclosing archetype or enum
    arch = nd.find_parent_of_type(uni.Archetype);
    enum_parent = nd.find_parent_of_type(uni.Enum) if not arch else None;
    enclosing = arch or enum_parent;
    enclosing_name: str | None = None;
    if enclosing {
        enclosing_name = enclosing.name.sym_name if enclosing.name else None;
    }
    # For detached impl blocks (not nested inside archetype), get name from target
    if not enclosing_name {
        impl_def = nd.find_parent_of_type(uni.ImplDef);
        if impl_def and impl_def.target and len(impl_def.target) > 0 {
            enclosing_name = impl_def.target[0].sym_name
                if isinstance(impl_def.target[0], uni.NameAtom)
                else None;
        }
    }
    if not enclosing_name {
        return None;
    }
    # Check if we're in a type annotation context (return type, param type, has type)
    if self._is_in_type_annotation(nd) {
        return self.sync(ast3.Name(id=enclosing_name, ctx=ast3.Load()));
    }
    # Runtime usage: check if we're in a classmethod or instance method
    ability = nd.find_parent_of_type(uni.Ability);
    # Also check ImplDef — Self inside impl blocks should resolve via decl_link
    impl_def = nd.find_parent_of_type(uni.ImplDef);
    is_in_classmethod = False;
    is_in_method = False;
    if ability {
        is_in_classmethod = ability.is_cls_method;
        is_in_method = ability.is_method
        and not ability.is_static
        and not ability.is_cls_method;
    } elif impl_def
    and impl_def.decl_link
    and isinstance(impl_def.decl_link, uni.Ability) {
        is_in_classmethod = impl_def.decl_link.is_cls_method;
        is_in_method = (
            impl_def.decl_link.is_method
            and not impl_def.decl_link.is_static
            and not impl_def.decl_link.is_cls_method
        );
    }
    if is_in_classmethod {
        # In classmethod: Self -> cls
        return self.sync(ast3.Name(id='cls', ctx=nd.py_ctx_func()));
    }
    if is_in_method {
        # In instance method: Self -> type(self) for polymorphic behavior
        return self.sync(
            ast3.Call(
                func=self.sync(ast3.Name(id='type', ctx=ast3.Load())),
                args=[self.sync(ast3.Name(id='self', ctx=ast3.Load()))],
                keywords=[]
            )
        );
    }
    # Fallback: use class name directly (e.g., in static methods or other contexts)
    return self.sync(ast3.Name(id=enclosing_name, ctx=nd.py_ctx_func()));
}

"""Check if a node is in a type annotation context."""
impl PyastGenPass._is_in_type_annotation(nd: uni.UniNode) -> bool {
    parent = nd.parent;
    while parent {
        # Return type annotation
        if isinstance(parent, uni.FuncSignature) {
            # Check if nd is within the return_type subtree
            if parent.return_type {
                return self._is_descendant_of(nd, parent.return_type);
            }
        }
        # Parameter type annotation
        if isinstance(parent, uni.ParamVar) {
            if parent.type_tag {
                return True;
            }
        }
        # Has field type annotation
        if isinstance(parent, uni.HasVar) {
            if parent.type_tag {
                return True;
            }
        }
        # SubTag (type tag wrapper)
        if isinstance(parent, uni.SubTag) {
            return True;
        }
        parent = parent.parent;
    }
    return False;
}

"""Check if a node is or is a descendant of another node."""
impl PyastGenPass._is_descendant_of(nd: uni.UniNode, ancestor: uni.UniNode) -> bool {
    if nd is ancestor {
        return True;
    }
    current = nd.parent;
    while current {
        if current is ancestor {
            return True;
        }
        current = current.parent;
    }
    return False;
}

impl PyastGenPass.exit_float(nd: uni.Float) -> None {
    nd.gen.py_ast = [self.sync(ast3.Constant(value=float(nd.value)))];
}

impl PyastGenPass.exit_int(nd: uni.Int) -> None {
    nd.gen.py_ast = [self.sync(ast3.Constant(value=int(nd.value, 0)))];
}

impl PyastGenPass.exit_string(nd: uni.String) -> None {
    nd.gen.py_ast = [self.sync(ast3.Constant(value=nd.lit_value))];
}

impl PyastGenPass.exit_bool(nd: uni.Bool) -> None {
    nd.gen.py_ast = [self.sync(ast3.Constant(value=(nd.value == 'True')))];
}

impl PyastGenPass.exit_builtin_type(nd: uni.BuiltinType) -> None {
    nd.gen.py_ast = [self.sync(ast3.Name(id=nd.sym_name, ctx=nd.py_ctx_func()))];
}

impl PyastGenPass.exit_null(nd: uni.Null) -> None {
    nd.gen.py_ast = [self.sync(ast3.Constant(value=None))];
}

impl PyastGenPass.exit_ellipsis(nd: uni.Ellipsis) -> None {
    nd.gen.py_ast = [self.sync(ast3.Constant(value=...))];
}

"""Generate Python AST for JSX elements."""
impl PyastGenPass.exit_jsx_element(nd: uni.JsxElement) -> None {
    self.jsx_processor.element(nd);
}

"""Generate Python AST for JSX element names."""
impl PyastGenPass.exit_jsx_element_name(nd: uni.JsxElementName) -> None {
    self.jsx_processor.element_name(nd);
}

"""Bases class for JSX attributes - handled by subclasses."""
impl PyastGenPass.exit_jsx_attribute(nd: uni.JsxAttribute) -> None {
    ;
}

"""Generate Python AST for JSX spread attributes."""
impl PyastGenPass.exit_jsx_spread_attribute(nd: uni.JsxSpreadAttribute) -> None {
    self.jsx_processor.spread_attribute(nd);
}

"""Generate Python AST for JSX normal attributes."""
impl PyastGenPass.exit_jsx_normal_attribute(nd: uni.JsxNormalAttribute) -> None {
    self.jsx_processor.normal_attribute(nd);
}

"""Bases class for JSX children - handled by subclasses."""
impl PyastGenPass.exit_jsx_child(nd: uni.JsxChild) -> None {
    ;
}

"""Generate Python AST for JSX text nodes."""
impl PyastGenPass.exit_jsx_text(nd: uni.JsxText) -> None {
    self.jsx_processor.text(nd);
}

"""Generate Python AST for JSX expression children."""
impl PyastGenPass.exit_jsx_expression(nd: uni.JsxExpression) -> None {
    self.jsx_processor.expression(nd);
}

impl PyastGenPass.exit_semi(nd: uni.Semi) -> None {
    ;
}

impl PyastGenPass.exit_comment_token(nd: uni.CommentToken) -> None {
    ;
}
