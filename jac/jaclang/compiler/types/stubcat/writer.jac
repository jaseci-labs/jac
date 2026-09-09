import os;
import json;
import struct;
import from jaclang.compiler.frontend.unitree {
    Ability,
    Archetype,
    Assignment,
    AtomTrailer,
    ElseIf,
    DictCompr,
    ElseStmt,
    Enum,
    FuncSignature,
    HasVar,
    IfStmt,
    InnerCompr,
    ListCompr,
    Import,
    KWPair,
    Module,
    ModulePath,
    Name,
    ParamVar,
    Symbol,
    UniScopeNode
}
import from jaclang.compiler.frontend.helpers { evaluate_version_condition }
import from jaclang.compiler.types.types {
    AnyType,
    ClassDetailsShared,
    ClassType,
    EnumMemberType,
    FunctionType,
    ModuleType,
    NeverType,
    OverloadedType,
    TypeBase,
    TypeVarType,
    UnionType,
    UnknownType
}
import from jaclang.compiler.frontend.constant { BindingKind }
import from jaclang.compiler.types.stubcat.format {
    ACCESS_PRIVATE,
    ACCESS_PROTECTED,
    ACCESS_PUBLIC,
    ARCH_CLASS,
    ARCH_ENUM,
    ARCH_NONE,
    ARCH_OBJ,
    HEADER_SIZE,
    Header,
    LIT_BOOL,
    LIT_INT,
    LIT_NONE,
    LIT_STR,
    MOD_EXTERNAL,
    MOD_JAC_INTERNAL,
    MOD_TYPESHED,
    PM_CLS,
    PM_COMPTIME,
    PM_HAS_DEFAULT,
    PM_SELF,
    SC_CLASS,
    SC_FUNCTION,
    SC_MODULE,
    SC_OTHER,
    SH_BUILTIN,
    SH_DATACLASS,
    SH_ENUM,
    SH_NAMEDTUPLE,
    SH_ROOT,
    SH_STDLIB,
    SH_TYPEDDICT,
    SH_XREF,
    SYMF_DEFER,
    SYMF_HAS_DEFAULT,
    SYMF_INSTANCE_METHOD,
    SYMF_NA_ESCAPES,
    SYMF_NA_REGION_HANDLE,
    SYMF_NA_STACK_OK,
    SYMF_PARAM_REBOUND,
    TV_CLASS_PARAM,
    TV_CONTRAVARIANT,
    TV_COVARIANT,
    TV_PARAM_SPEC,
    TV_SELF,
    TY_ANY,
    TY_CLASS,
    TY_ENUM_MEMBER,
    TY_FUNCTION,
    TY_MODULE,
    TY_NEVER,
    TY_OVERLOAD,
    TY_TYPEVAR,
    TY_UNION,
    TY_UNKNOWN,
    pack_header,
    put_ref,
    put_refs,
    put_svar,
    put_uvar
}

obj ScopeMembers {
    has names: dict[str, Symbol] = {},
        overloads: dict[str, list[Symbol]] = {};
}

def live_branches(guard: IfStmt) -> list[UniScopeNode] {
    result = evaluate_version_condition(guard.condition);
    if result is None or result {
        return [guard];
    }
    if isinstance(guard.else_body, ElseIf) {
        return live_branches(guard.else_body);
    }
    if isinstance(guard.else_body, ElseStmt) {
        return [guard.else_body];
    }
    return [];
}

def live_kid_scopes(scope: UniScopeNode) -> list[UniScopeNode] {
    out: list[UniScopeNode] = [];
    for kid in scope.kid_scope {
        if UniScopeNode.is_python_scoping(kid)
            or isinstance(kid, (ListCompr, DictCompr, InnerCompr)) {
            continue;
        }
        if isinstance(kid, (ElseStmt, ElseIf)) and isinstance(kid.parent, IfStmt) {
            continue;
        }
        if isinstance(kid, IfStmt) {
            out.extend(live_branches(kid));
        } else {
            out.append(kid);
        }
    }
    return out;
}

def collect_scope_members(scope: UniScopeNode) -> ScopeMembers {
    members = ScopeMembers();
    stack: list[UniScopeNode] = [scope];
    while stack {
        cur = stack.pop(0);
        for (name, sym) in cur.names_in_scope.items() {
            if name not in members.names {
                members.names[name] = sym;
            }
        }
        for (name, syms) in cur.names_in_scope_overload.items() {
            if name not in members.overloads {
                members.overloads[name] = [];
            }
            members.overloads[name].extend(syms);
        }
        stack.extend(live_kid_scopes(cur));
    }
    return members;
}

def live_scopes(scope: UniScopeNode) -> set[int] {
    out: set[int] = set();
    stack: list[UniScopeNode] = [scope];
    while stack {
        cur = stack.pop();
        out.add(id(cur));
        stack.extend(live_kid_scopes(cur));
    }
    return out;
}

def enclosing_scope(nd: any) -> (UniScopeNode | None) {
    cur = nd.parent;
    while cur is not None and not isinstance(cur, UniScopeNode) {
        cur = cur.parent;
    }
    return cur;
}

def star_import_members(
    mod: Module, evaluator: any, visited: (set[int] | None) = None
) -> dict[str, Symbol] {
    seen: set[int] = visited if visited is not None else set();
    out: dict[str, Symbol] = {};
    if id(mod) in seen {
        return out;
    }
    seen.add(id(mod));
    live = live_scopes(mod);
    for imp in mod.get_all_sub_nodes(Import) {
        if not imp.is_absorb or not imp.items {
            continue;
        }
        holder = enclosing_scope(imp);
        if holder is not None and id(holder) not in live {
            continue;
        }
        submod = imp.absorbed_mod;
        if submod is None {
            star_path = imp.items[0];
            if isinstance(star_path, ModulePath) {
                resolved = star_path.resolve_relative_path_list();
                if resolved and os.path.exists(resolved[-1]) {
                    try {
                        submod = evaluator._import_module_from_path(resolved[-1]);
                    } except Exception {
                        submod = None;
                    }
                }
            }
        }
        if submod is None {
            continue;
        }
        inner = collect_scope_members(submod);
        for (name, sym) in inner.names.items() {
            if name.startswith("_") or name in out {
                continue;
            }
            out[name] = sym;
        }
        for (name, sym) in star_import_members(submod, evaluator, seen).items() {
            if name not in out {
                out[name] = sym;
            }
        }
    }
    return out;
}

def metaclass_of_scope(scope: UniScopeNode, evaluator: any) -> (TypeBase | None) {
    if hasattr(scope, "cat_metaclass") {
        try {
            cat_meta: any = getattr(scope, "metaclass_type");
            found = cat_meta();
            return found if isinstance(found, TypeBase) else None;
        } except Exception {
            return None;
        }
    }
    if not isinstance(scope, Archetype) {
        return None;
    }
    for kid in scope.kid {
        if (
            isinstance(kid, KWPair)
            and kid.key is not None
            and kid.key.sym_name == "metaclass"
        ) {
            try {
                return evaluator.get_type_of_expression(kid.value);
            } except Exception {
                return None;
            }
        }
    }
    return None;
}

def home_scope(sym: Symbol) -> (UniScopeNode | None) {
    tab = sym.parent_tab;
    while tab is not None and not UniScopeNode.is_python_scoping(tab) {
        tab = tab.parent_scope;
    }
    return tab;
}

def module_of(scope: (UniScopeNode | None)) -> (Module | None) {
    cur = scope;
    while cur is not None {
        if isinstance(cur, Module) {
            return cur;
        }
        cur = cur.parent_scope;
    }
    return None;
}

obj CatalogWriter {
    has evaluator: any,
        pkg_dir: str,
        strings: dict[str, int] postinit,
        str_list: list[str] postinit,
        module_names: dict[any, str] postinit,
        module_ids: dict[any, int] postinit,
        modules: list[Module] postinit,
        scope_ids: dict[any, int] postinit,
        scopes: list[UniScopeNode] postinit,
        pending_scopes: list[int] postinit,
        sym_ids: dict[any, int] postinit,
        syms: list[Symbol] postinit,
        pending_syms: list[int] postinit,
        type_ids: dict[any, int] postinit,
        _ident_visiting: set[int] postinit,
        _type_ident_memo: dict[int, any] postinit,
        types: list[TypeBase] postinit,
        pending_types: list[int] postinit,
        shared_ids: dict[any, int] postinit,
        shareds: list[ClassDetailsShared] postinit,
        pending_shared: list[int] postinit,
        module_recs: list[bytes] postinit,
        scope_recs: list[(bytes | None)] postinit,
        sym_recs: list[(bytes | None)] postinit,
        type_recs: list[(bytes | None)] postinit,
        shared_recs: list[(bytes | None)] postinit,
        sym_types: dict[any, (TypeBase | None)] postinit,
        sym_props: dict[any, tuple[int, int, (TypeBase | None)]] postinit,
        forced_scopes: set[any] postinit,
        base_dir: str postinit,
        external_modules: set[any] postinit,
        boundary: (Module | None) = None,
        failures: int = 0,
        evaluated: int = 0,
        failure_log: list[str] = [],
        orphans: list[str] = [];

    def postinit {
        self.strings = {};
        self.str_list = [];
        self.sid("");
        self.module_names = {};
        self.module_ids = {};
        self.modules = [];
        self.scope_ids = {};
        self.scopes = [];
        self.pending_scopes = [];
        self.sym_ids = {};
        self.syms = [];
        self.pending_syms = [];
        self.type_ids = {};
        self.types = [];
        self.pending_types = [];
        self.shared_ids = {};
        self.shareds = [];
        self.pending_shared = [];
        self.module_recs = [];
        self.scope_recs = [];
        self.sym_recs = [];
        self.type_recs = [];
        self.shared_recs = [];
        self.sym_types = {};
        self.sym_props = {};
        self.forced_scopes = set();
        self.base_dir = os.path.realpath(self.pkg_dir);
        self.external_modules = set();
        self._ident_visiting = set();
        self._type_ident_memo = {};
    }

    def in_boundary(mod: (Module | None)) -> bool {
        if self.boundary is None {
            return True;
        }
        if mod is None {
            return False;
        }
        if mod is self.boundary {
            return True;
        }
        try {
            bpath = self.boundary.loc.mod_path if self.boundary.loc else "";
            mpath = mod.loc.mod_path if mod.loc else "";
            if not bpath or not mpath {
                return False;
            }
            return os.path.realpath(mpath) == os.path.realpath(bpath);
        } except Exception {
            return False;
        }
    }

    def _mod_ident(mod: (Module | None)) -> any {
        if mod is None {
            return -1;
        }
        if self.boundary is None {
            return id(mod);
        }
        try {
            mpath = mod.loc.mod_path if mod.loc else "";
        } except Exception {
            mpath = "";
        }
        if mpath {
            return os.path.realpath(mpath);
        }
        return id(mod);
    }

    def _scope_ident(scope: (UniScopeNode | None)) -> any {
        if scope is None {
            return -1;
        }
        if self.boundary is None {
            return id(scope);
        }
        mod = module_of(scope);
        if mod is None or not self.in_boundary(mod) {
            return id(scope);
        }
        loc = scope.loc;
        span = (
            (loc.first_line, loc.col_start, loc.last_line, loc.col_end)
                if loc
                else (0, 0, 0, 0)
        );
        return (
            self._mod_ident(mod),
            self.scope_dotted_path(scope),
            type(scope).__name__,
            span,

        );
    }

    def _sym_ident(sym: Symbol) -> any {
        if self.boundary is None {
            return id(sym);
        }
        home = home_scope(sym);
        mod = module_of(home);
        if home is None or mod is None or not self.in_boundary(mod) {
            return id(sym);
        }
        loc = sym.decl.loc if sym.decl else None;
        if loc is None {
            return id(sym);
        }

        return (
            self._scope_ident(home),
            sym.sym_name,
            (loc.first_line, loc.col_start, loc.last_line, loc.col_end),

        );
    }

    def _shared_ident(shared: ClassDetailsShared) -> any {
        if self.boundary is None {
            return id(shared);
        }
        tab: (UniScopeNode | None) = None;
        try {
            tab = shared.symbol_table;
        } except Exception {
            tab = None;
        }
        mod = module_of(tab) if tab is not None else None;
        if tab is None or mod is None or not self.in_boundary(mod) {
            return id(shared);
        }
        return (self._scope_ident(tab), shared.class_name, );
    }

    def scope_dotted_path(scope: (UniScopeNode | None)) -> str {
        parts: list[str] = [];
        cur = scope;
        while cur is not None and not isinstance(cur, Module) {
            if UniScopeNode.is_python_scoping(cur) or hasattr(cur, "cat_kind") {
                parts.append(cur.scope_name);
            }
            cur = cur.parent_scope;
        }
        parts.reverse();
        return ".".join(parts);
    }

    def sid(text: str) -> int {
        found = self.strings.get(text);
        if found is not None {
            return found;
        }
        idx = len(self.str_list);
        self.strings[text] = idx;
        self.str_list.append(text);
        return idx;
    }

    def rel_of(path: str) -> str {
        if not path {
            return "";
        }
        real = os.path.realpath(path);
        prefix = self.base_dir + os.sep;
        if real.startswith(prefix) {
            return real[len(prefix):].replace(os.sep, "/");
        }
        return real;
    }

    def add_module(mod: Module, dotted: str) -> None {
        key = self._mod_ident(mod);
        if key in self.module_ids {
            return;
        }
        self.module_ids[key] = len(self.modules);
        self.module_names[key] = dotted;
        self.modules.append(mod);
    }

    def ref_module(mod: (Module | None)) -> int {
        if mod is None {
            return -1;
        }
        found = self.module_ids.get(self._mod_ident(mod));
        if found is not None {
            return found;
        }
        if self.boundary is not None {
            if not self.in_boundary(mod) {
                self.external_modules.add(self._mod_ident(mod));
            }
            self.add_module(mod, self.dotted_name_of(mod));
            return self.module_ids[self._mod_ident(mod)];
        }
        if mod.stub_only and mod.loc and mod.loc.mod_path.endswith(".pyi") {
            self.add_module(mod, self.dotted_name_of(mod));
            return self.module_ids[self._mod_ident(mod)];
        }
        return -1;
    }

    def dotted_name_of(mod: Module) -> str {
        path = mod.loc.mod_path if mod.loc else "";
        if mod.name and not path.endswith(".pyi") {
            return mod.name;
        }
        rel = self.rel_of(mod.loc.mod_path if mod.loc else "");
        prefix = "vendor/typeshed/stdlib/";
        if rel.startswith(prefix) {
            rel = rel[len(prefix):];
        } else {
            rel = rel.rsplit("/", 1)[-1];
        }
        if rel.endswith(".pyi") {
            rel = rel[:-4];
        }
        dotted = rel.replace("/", ".");
        if dotted.endswith(".__init__") {
            dotted = dotted[:-9];
        }
        return dotted;
    }

    def force_all {
        for mod in list(self.modules) {
            self.force_scope(mod);
        }
    }

    def _materialize_lazy_members(scope: UniScopeNode) -> None {
        if not isinstance(scope, Archetype) {
            return;
        }
        owner = scope.name_spec.sym;
        if owner is None {
            return;
        }
        cls_t: any = None;
        try {
            cls_t = self.evaluator.get_type_of_symbol(owner);
        } except Exception {
            return;
        }
        if not isinstance(cls_t, ClassType) {
            return;
        }
        for method_name in ("init", "__post_init__") {
            method_sym = scope.lookup(method_name, deep=False);
            if method_sym is None or not isinstance(method_sym.decl.name_of, Ability) {
                continue;
            }
            ability = method_sym.decl.name_of;
            sig = ability.signature;
            if isinstance(sig, FuncSignature) and sig.params {
                for param in sig.params {
                    if isinstance(param, ParamVar) and param.name.value != "self" {
                        cls_t.lookup_member_symbol(param.name.value);
                    }
                }
            }
            for trailer in ability.get_all_sub_nodes(AtomTrailer) {
                holder = trailer.parent;
                if not isinstance(holder, Assignment)
                    or trailer is not holder.target[0] {
                    continue;
                }
                if isinstance(trailer.right, Name) {
                    cls_t.lookup_member_symbol(trailer.right.value);
                }
            }
        }
    }

    def force_scope(scope: UniScopeNode) -> None {
        key = self._scope_ident(scope);
        if key in self.forced_scopes {
            return;
        }
        self.forced_scopes.add(key);
        self._materialize_lazy_members(scope);
        members = collect_scope_members(scope);
        if isinstance(scope, Module) {
            for (name, sym) in star_import_members(scope, self.evaluator).items() {
                if name not in members.names {
                    members.names[name] = sym;
                }
            }
        }
        for (name, sym) in members.names.items() {
            self.force_symbol(sym);
        }
        for syms in members.overloads.values() {
            for sym in syms {
                self.force_symbol(sym);
            }
        }
    }

    def force_symbol(sym: Symbol) -> None {
        key = self._sym_ident(sym);
        if key in self.sym_types {
            return;
        }
        resolved: (TypeBase | None) = None;
        try {
            resolved = self.evaluator.get_type_of_symbol(sym);
            self.evaluated += 1;
        } except Exception as e {
            self.failures += 1;
            if len(self.failure_log) < 200 {
                self.failure_log.append(f"{sym.sym_name}: {type(e).__name__}: {e}");
            }
        }
        self.sym_types[key] = resolved;
        self.sym_props[key] = self.property_facts(sym);
        own_scope: (UniScopeNode | None) = None;
        try {
            own_scope = sym.symbol_table;
        } except Exception {
            own_scope = None;
        }
        if own_scope is not None
            and (
                isinstance(own_scope, (Archetype, Enum))
                or hasattr(own_scope, "cat_kind")
            )
            and self.in_boundary(module_of(own_scope)) {
            self.force_scope(own_scope);
        }
    }

    def _jac_method_of(sym: Symbol) -> (Ability | None) {
        decl = sym.decl;
        node_ = decl.name_of if decl is not None else None;
        if not isinstance(node_, Ability) or not node_.is_method {
            return None;
        }
        if node_.is_static or node_.is_cls_method {
            return None;
        }
        sig = node_.signature;
        if isinstance(sig, FuncSignature) and sig.is_in_py_class {
            return None;
        }
        for dec in (node_.decorators or ()) {
            if isinstance(dec, Name)
                and dec.sym_name in ("staticmethod", "classmethod") {
                return None;
            }
        }
        return node_;
    }

    def property_facts(sym: Symbol) -> tuple[int, int, (TypeBase | None)] {
        import from jaclang.compiler.types.type_utils { PropertyWriteKind }
        kind = 0;
        write_kind = 0;
        write_type: (TypeBase | None) = None;
        try {
            kind = int(self.evaluator._classify_property_symbol(sym).value);
        } except Exception {
            kind = 0;
        }
        if kind != 0 {
            try {
                result = self.evaluator.get_property_write_type(sym);
                write_kind = int(result.kind.value);
                write_type = result.write_type;
            } except Exception {
                write_kind = kind;
                write_type = None;
            }
        }
        return (kind, write_kind, write_type);
    }

    def ref_scope(scope: (UniScopeNode | None)) -> int {
        if scope is None {
            return -1;
        }
        if self.boundary is not None and not self.in_boundary(module_of(scope)) {
            return -1;
        }
        key = self._scope_ident(scope);
        found = self.scope_ids.get(key);
        if found is not None {
            return found;
        }
        idx = len(self.scopes);
        self.scope_ids[key] = idx;
        self.scopes.append(scope);
        self.scope_recs.append(None);
        self.pending_scopes.append(idx);
        return idx;
    }

    def ref_symbol(sym: (Symbol | None)) -> int {
        if sym is None {
            return -1;
        }
        key = self._sym_ident(sym);
        found = self.sym_ids.get(key);
        if found is not None {
            return found;
        }
        idx = len(self.syms);
        self.sym_ids[key] = idx;
        self.syms.append(sym);
        self.sym_recs.append(None);
        self.pending_syms.append(idx);
        return idx;
    }

    def _type_ident(t: TypeBase) -> any {
        tid = id(t);
        if self.boundary is None {
            return tid;
        }
        memo = self._type_ident_memo.get(tid);
        if memo is not None {
            return memo;
        }
        if tid in self._ident_visiting {
            return tid;
        }
        self._ident_visiting.add(tid);
        try {
            key = self._type_ident_uncached(t);
        } finally {
            self._ident_visiting.discard(tid);
        }
        self._type_ident_memo[tid] = key;
        return key;
    }

    def _type_ident_uncached(t: TypeBase) -> any {
        tid = id(t);
        try {
            flags = int(t.flags);
            if isinstance(t, ClassType) {
                shared = t._shared;
                if shared is None {
                    return ("unknown", flags, );
                }
                return (
                    "class",
                    flags,
                    self._shared_ident(shared),
                    self._types_ident(t.private.type_args),
                    t.private.alias_name or "",
                    self._literal_ident(t.private.literal_value),
                    t.private.distinct_key or "",

                );
            }
            if isinstance(t, FunctionType) {
                params: list = [];
                for p in (t.parameters or []) {
                    params.append(
                        (
                            p.name or "",
                            int(p.category) if p.category is not None else 0,
                            int(p.param_kind),
                            self._type_ident(p.param_type)
                                if p.param_type is not None
                                else -1,
                            bool(p.is_self),
                            bool(p.is_cls),
                            bool(p.has_default or p.default_value is not None),
                            bool(p.is_comptime),

                        )
                    );
                }
                return (
                    "fn",
                    flags,
                    t.func_name or "",
                    int(t.function_flags),
                    bool(t.is_async),
                    bool(t.type_guard_is_strict),
                    self._type_ident(t.return_type)
                        if t.return_type is not None
                        else -1,
                    self._type_ident(t.type_guard) if t.type_guard is not None else -1,
                    self._types_ident([tv for tv in (t.type_params or [])]),
                    tuple(params),

                );
            }
            if isinstance(t, OverloadedType) {
                return (
                    "overload",
                    flags,
                    self._types_ident([fn for fn in (t.overloads or [])]),

                );
            }
            if isinstance(t, UnionType) {
                return ("union", flags, self._types_ident(t.types), );
            }
            if isinstance(t, TypeVarType) {
                return (
                    "typevar",
                    flags,
                    t.name or "",
                    bool(t.is_covariant),
                    bool(t.is_contravariant),
                    bool(t.is_self),
                    bool(t.is_param_spec),
                    bool(t.is_class_type_param),
                    self._type_ident(t.bound) if t.bound is not None else -1,
                    self._types_ident(t.constraints),

                );
            }
            if isinstance(t, ModuleType) {
                tab = t.symbol_table;
                return (
                    "module",
                    flags,
                    t.mod_name or "",
                    str(t.file_uri) if t.file_uri else "",
                    bool(t.is_external),
                    self._mod_ident(tab) if isinstance(tab, Module) else -1,

                );
            }
            if isinstance(t, EnumMemberType) {
                info = t.member_info;
                return (
                    "enum_member",
                    flags,
                    self._type_ident(t.enum_class) if t.enum_class is not None else -1,
                    info.member_name if info else "",
                    self._type_ident(info.value_type)
                        if (info and info.value_type is not None)
                        else -1,
                    self._literal_ident(info.literal_value if info else None),

                );
            }
            if isinstance(t, NeverType) {
                return ("never", flags, );
            }
            if isinstance(t, AnyType) {
                return ("any", flags, bool(t.is_foreign), t.foreign_scalar or "", );
            }
            return tid;
        } except Exception {
            return tid;
        }
    }

    def _types_ident(ts: (list | None)) -> tuple {
        out: list = [];
        for x in (ts or []) {
            out.append(self._type_ident(x) if x is not None else -1);
        }
        return tuple(out);
    }

    def _literal_ident(value: any) -> any {
        if value is None or isinstance(value, (bool, int, str, float)) {
            return (type(value).__name__, value, );
        }
        return (type(value).__name__, repr(value), );
    }

    def ref_type(t: (TypeBase | None)) -> int {
        if t is None {
            return -1;
        }
        key = self._type_ident(t);
        found = self.type_ids.get(key);
        if found is not None {
            return found;
        }
        idx = len(self.types);
        self.type_ids[key] = idx;
        self.types.append(t);
        self.type_recs.append(None);
        self.pending_types.append(idx);
        return idx;
    }

    def ref_types(ts: (list[TypeBase] | None)) -> list[int] {
        out: list[int] = [];
        for t in (ts or []) {
            out.append(self.ref_type(t));
        }
        return out;
    }

    def ref_shared(shared: (ClassDetailsShared | None)) -> int {
        if shared is None {
            return -1;
        }
        key = self._shared_ident(shared);
        found = self.shared_ids.get(key);
        if found is not None {
            return found;
        }
        idx = len(self.shareds);
        self.shared_ids[key] = idx;
        self.shareds.append(shared);
        self.shared_recs.append(None);
        self.pending_shared.append(idx);
        return idx;
    }

    def put_literal(out: bytearray, value: any) {
        if isinstance(value, bool) {
            put_uvar(out, LIT_BOOL);
            put_uvar(out, 1 if value else 0);
        } elif isinstance(value, int) {
            put_uvar(out, LIT_INT);
            put_svar(out, value);
        } elif isinstance(value, str) {
            put_uvar(out, LIT_STR);
            put_uvar(out, self.sid(value));
        } else {
            put_uvar(out, LIT_NONE);
        }
    }

    def encode_module(idx: int) -> bytes {
        mod = self.modules[idx];
        out = bytearray();
        put_uvar(out, self.sid(self.module_names[self._mod_ident(mod)]));
        rel = self.rel_of(mod.loc.mod_path if mod.loc else "");
        put_uvar(out, self.sid(rel));
        if self._mod_ident(mod) in self.external_modules {
            put_uvar(out, MOD_EXTERNAL);
            put_ref(out, -1);
            put_uvar(out, self.sid(""));
            return bytes(out);
        }
        if "vendor/typeshed/" in rel {
            flags = MOD_TYPESHED;
        } elif self.boundary is None {
            flags = MOD_JAC_INTERNAL;
        } else {
            flags = 0;
        }
        put_uvar(out, flags);
        put_ref(out, self.ref_scope(mod));
        decided = "";
        try {
            decided = mod.decided_codespace;
        } except Exception {
            decided = "";
        }
        put_uvar(out, self.sid(decided));
        return bytes(out);
    }

    def encode_scope(idx: int) -> bytes {
        scope = self.scopes[idx];
        out = bytearray();
        kind = SC_OTHER;
        arch_kind = ARCH_NONE;
        owner: (Symbol | None) = None;
        if isinstance(scope, Module) {
            kind = SC_MODULE;
        } elif isinstance(scope, Archetype) {
            kind = SC_CLASS;
            arch_kind = ARCH_CLASS if scope.arch_type.name == "KW_CLASS" else ARCH_OBJ;
            owner = scope.name_spec.sym;
        } elif isinstance(scope, Enum) {
            kind = SC_CLASS;
            arch_kind = ARCH_ENUM;
            owner = scope.name_spec.sym;
        } elif isinstance(scope, Ability) {
            kind = SC_FUNCTION;
            owner = scope.name_spec.sym;
        } elif hasattr(scope, "cat_kind") {
            kind = int(getattr(scope, "cat_kind"));
            arch_kind = int(getattr(scope, "cat_arch_kind"));
            cat_owner: any = scope?.cat_owner_sym;
            if isinstance(cat_owner, Symbol) {
                owner = cat_owner;
            }
        }
        put_uvar(out, kind);
        put_uvar(out, self.sid(scope.scope_name));
        parent = -1;
        if kind != SC_MODULE {
            parent_scope = scope.parent_scope;
            while parent_scope is not None
                and not UniScopeNode.is_python_scoping(parent_scope) {
                parent_scope = parent_scope.parent_scope;
            }
            parent = self.ref_scope(parent_scope);
        }
        put_ref(out, parent);
        put_ref(out, self.ref_module(module_of(scope)));
        put_ref(out, self.ref_symbol(owner));
        loc = scope.loc;
        put_uvar(out, max(loc.first_line, 0) if loc else 0);
        put_uvar(out, max(loc.col_start, 0) if loc else 0);
        put_uvar(out, max(loc.last_line, 0) if loc else 0);
        put_uvar(out, max(loc.col_end, 0) if loc else 0);
        put_uvar(out, arch_kind);
        put_ref(out, self.ref_type(metaclass_of_scope(scope, self.evaluator)));
        if kind == SC_FUNCTION {
            put_uvar(out, 0);
            put_uvar(out, 0);
            put_uvar(out, 0);
            return bytes(out);
        }
        members = collect_scope_members(scope);
        if isinstance(scope, Module) {
            for (name, sym) in star_import_members(scope, self.evaluator).items() {
                if name not in members.names {
                    members.names[name] = sym;
                }
            }
        }
        put_uvar(out, len(members.names));
        kids: list[tuple[str, int]] = [];
        seen_kids: set[str] = set();
        for (name, sym) in members.names.items() {
            put_uvar(out, self.sid(name));
            put_ref(out, self.ref_symbol(sym));
            if name in seen_kids {
                continue;
            }
            own_scope: (UniScopeNode | None) = None;
            try {
                own_scope = sym.symbol_table;
            } except Exception {
                own_scope = None;
            }
            if (
                isinstance(own_scope, (Archetype, Enum, Ability))
                or hasattr(own_scope, "cat_kind")
            )
                and self.in_boundary(module_of(own_scope)) {
                seen_kids.add(name);
                kids.append((name, self.ref_scope(own_scope)));
            }
        }
        put_uvar(out, len(members.overloads));
        for (name, syms) in members.overloads.items() {
            put_uvar(out, self.sid(name));
            refs: list[int] = [];
            for sym in syms {
                refs.append(self.ref_symbol(sym));
            }
            put_refs(out, refs);
        }
        put_uvar(out, len(kids));
        for (name, sid_) in kids {
            put_uvar(out, self.sid(name));
            put_ref(out, sid_);
        }
        return bytes(out);
    }

    def encode_symbol(idx: int) -> bytes {
        sym = self.syms[idx];
        if self._sym_ident(sym) not in self.sym_types {
            self.force_symbol(sym);
        }
        out = bytearray();
        put_uvar(out, self.sid(sym.sym_name));
        put_uvar(out, self.sid(str(sym.sym_type.value)));
        access = ACCESS_PUBLIC;
        if sym.access.value == "private" {
            access = ACCESS_PRIVATE;
        } elif sym.access.value == "protected" {
            access = ACCESS_PROTECTED;
        }
        put_uvar(out, access);
        put_uvar(out, 1 if sym.imported else 0);
        loc = sym.decl.loc if sym.decl else None;
        put_uvar(out, max(loc.first_line, 0) if loc else 0);
        put_uvar(out, max(loc.col_start, 0) if loc else 0);
        put_uvar(out, max(loc.last_line, 0) if loc else 0);
        put_uvar(out, max(loc.col_end, 0) if loc else 0);
        home = home_scope(sym);
        put_ref(out, self.ref_module(module_of(home)));
        put_ref(out, self.ref_scope(home));
        put_ref(out, self.ref_type(self.sym_types.get(self._sym_ident(sym))));
        alias_mod = -1;
        alias_name = "";
        if sym.imported {
            try {
                target = self.evaluator.resolve_to_definition_symbol(sym);
            } except Exception {
                target = sym;
            }
            if target is not sym {
                target_mod = module_of(home_scope(target));
                alias_mod = self.ref_module(target_mod);
                if alias_mod >= 0 {
                    alias_name = target.sym_name;
                }
            }
        }
        put_ref(out, alias_mod);
        put_uvar(out, self.sid(alias_name));
        (prop_kind, write_kind, write_type) = self.sym_props.get(
            self._sym_ident(sym), (0, 0, None)
        );
        put_uvar(out, prop_kind);
        put_uvar(out, write_kind);
        put_ref(out, self.ref_type(write_type));
        ownership = 0;
        try {
            ownership = int(sym.ownership.value);
        } except Exception {
            ownership = 0;
        }
        put_uvar(out, ownership);
        binding = 0;
        try {
            kind = sym.binding_kind;
            if kind is BindingKind.VALUE {
                binding = 1;
            } elif kind is BindingKind.TYPE {
                binding = 2;
            } elif kind is BindingKind.BOTH {
                binding = 3;
            }
        } except Exception {
            binding = 0;
        }
        put_uvar(out, binding);
        symbits = 0;
        if sym.param_rebound {
            symbits |= SYMF_PARAM_REBOUND;
        }
        if sym.na_escapes {
            symbits |= SYMF_NA_ESCAPES;
        }
        if sym.na_region_handle {
            symbits |= SYMF_NA_REGION_HANDLE;
        }
        if sym.na_stack_ok {
            symbits |= SYMF_NA_STACK_OK;
        }
        if self._jac_method_of(sym) is not None {
            symbits |= SYMF_INSTANCE_METHOD;
        }
        try {
            decl_node = sym.decl.name_of if sym.decl else None;
            if isinstance(decl_node, HasVar) {
                if decl_node.value is not None {
                    symbits |= SYMF_HAS_DEFAULT;
                }
                if decl_node.defer {
                    symbits |= SYMF_DEFER;
                }
            }
        } except Exception {}
        put_uvar(out, symbits);
        return bytes(out);
    }

    def encode_type(idx: int) -> bytes {
        t = self.types[idx];
        out = bytearray();
        flags = int(t.flags);
        if isinstance(t, ClassType) {
            shared = t._shared;
            if shared is None {
                put_uvar(out, TY_UNKNOWN);
                put_uvar(out, flags);
                put_uvar(out, 0);
                put_uvar(out, 1);
                return bytes(out);
            }
            put_uvar(out, TY_CLASS);
            put_uvar(out, flags);
            put_ref(out, self.ref_shared(shared));
            put_refs(out, self.ref_types(t.private.type_args));
            put_uvar(out, self.sid(t.private.alias_name or ""));
            self.put_literal(out, t.private.literal_value);
            put_uvar(out, self.sid(t.private.distinct_key or ""));
            return bytes(out);
        }
        if isinstance(t, FunctionType) {
            put_uvar(out, TY_FUNCTION);
            put_uvar(out, flags);
            put_uvar(out, self.sid(t.func_name or ""));
            put_uvar(out, int(t.function_flags));
            put_uvar(out, 1 if t.is_async else 0);
            put_uvar(out, 1 if t.type_guard_is_strict else 0);
            put_ref(out, self.ref_type(t.return_type));
            put_ref(out, self.ref_type(t.type_guard));
            tps: list[TypeBase] = [];
            for tv in (t.type_params or []) {
                tps.append(tv);
            }
            put_refs(out, self.ref_types(tps));
            params = t.parameters or [];
            put_uvar(out, len(params));
            for p in params {
                put_uvar(out, self.sid(p.name or ""));
                put_uvar(out, int(p.category) if p.category is not None else 0);
                put_uvar(out, int(p.param_kind));
                put_ref(out, self.ref_type(p.param_type));
                bits = 0;
                if p.is_self {
                    bits |= PM_SELF;
                }
                if p.is_cls {
                    bits |= PM_CLS;
                }
                if p.has_default or p.default_value is not None {
                    bits |= PM_HAS_DEFAULT;
                }
                if p.is_comptime {
                    bits |= PM_COMPTIME;
                }
                put_uvar(out, bits);
            }
            return bytes(out);
        }
        if isinstance(t, OverloadedType) {
            put_uvar(out, TY_OVERLOAD);
            put_uvar(out, flags);
            fns: list[TypeBase] = [];
            for fn in (t.overloads or []) {
                fns.append(fn);
            }
            put_refs(out, self.ref_types(fns));
            return bytes(out);
        }
        if isinstance(t, UnionType) {
            put_uvar(out, TY_UNION);
            put_uvar(out, flags);
            put_refs(out, self.ref_types(t.types));
            return bytes(out);
        }
        if isinstance(t, TypeVarType) {
            put_uvar(out, TY_TYPEVAR);
            put_uvar(out, flags);
            put_uvar(out, self.sid(t.name or ""));
            bits = 0;
            if t.is_covariant {
                bits |= TV_COVARIANT;
            }
            if t.is_contravariant {
                bits |= TV_CONTRAVARIANT;
            }
            if t.is_self {
                bits |= TV_SELF;
            }
            if t.is_param_spec {
                bits |= TV_PARAM_SPEC;
            }
            if t.is_class_type_param {
                bits |= TV_CLASS_PARAM;
            }
            put_uvar(out, bits);
            put_ref(out, self.ref_type(t.bound));
            put_refs(out, self.ref_types(t.constraints));
            return bytes(out);
        }
        if isinstance(t, ModuleType) {
            put_uvar(out, TY_MODULE);
            put_uvar(out, flags);
            put_uvar(out, self.sid(t.mod_name or ""));
            put_uvar(out, self.sid(self.rel_of(str(t.file_uri)) if t.file_uri else ""));
            put_uvar(out, 1 if t.is_external else 0);
            tab = t.symbol_table;
            put_ref(out, self.ref_module(tab if isinstance(tab, Module) else None));
            return bytes(out);
        }
        if isinstance(t, EnumMemberType) {
            put_uvar(out, TY_ENUM_MEMBER);
            put_uvar(out, flags);
            put_ref(out, self.ref_type(t.enum_class));
            info = t.member_info;
            put_uvar(out, self.sid(info.member_name if info else ""));
            put_ref(out, self.ref_type(info.value_type if info else None));
            self.put_literal(out, info.literal_value if info else None);
            return bytes(out);
        }
        if isinstance(t, NeverType) {
            put_uvar(out, TY_NEVER);
            put_uvar(out, flags);
            return bytes(out);
        }
        if isinstance(t, AnyType) {
            put_uvar(out, TY_ANY);
            put_uvar(out, flags);
            put_uvar(out, 1 if t.is_foreign else 0);
            put_uvar(out, self.sid(t.foreign_scalar or ""));
            return bytes(out);
        }
        put_uvar(out, TY_UNKNOWN);
        put_uvar(out, flags);
        is_diagnosed = t.is_diagnosed if isinstance(t, UnknownType) else False;
        is_incomplete = t.is_incomplete if isinstance(t, UnknownType) else False;
        put_uvar(out, 1 if is_diagnosed else 0);
        put_uvar(out, 1 if is_incomplete else 0);
        return bytes(out);
    }

    def note_orphan(sh: ClassDetailsShared) {
        key = sh.canonical_key();
        site = f"{key[0]}:{key[1]}:{key[2]}" if key is not None else "<no site>";
        self.orphans.append(f"{sh.class_name} @ {site}");
    }

    def encode_shared(idx: int) -> bytes {
        sh = self.shareds[idx];
        out = bytearray();
        put_uvar(out, self.sid(sh.class_name or ""));
        home_mod = module_of(sh.symbol_table) if sh.symbol_table is not None else None;
        if self.boundary is not None and home_mod is None {
            self.note_orphan(sh);
        }
        if (
            self.boundary is not None
            and home_mod is not None
            and not self.in_boundary(home_mod)
        ) {
            put_uvar(out, SH_XREF);
            put_ref(out, self.ref_module(home_mod));
            put_uvar(out, self.sid(self.scope_dotted_path(sh.symbol_table)));
            key = sh.canonical_key();
            if key is not None {
                put_uvar(out, self.sid(self.rel_of(key[0])));
                put_uvar(out, max(key[1], 0));
                put_uvar(out, max(key[2], 0));
            } else {
                put_uvar(out, self.sid(""));
                put_uvar(out, 0);
                put_uvar(out, 0);
            }
            return bytes(out);
        }
        bits = 0;
        if sh.is_builtin_class {
            bits |= SH_BUILTIN;
        }
        if sh.is_from_stdlib_stub {
            bits |= SH_STDLIB;
        }
        if sh.is_data_class {
            bits |= SH_DATACLASS;
        }
        if sh.is_namedtuple {
            bits |= SH_NAMEDTUPLE;
        }
        if sh.is_typeddict {
            bits |= SH_TYPEDDICT;
        }
        if sh.is_root_class {
            bits |= SH_ROOT;
        }
        if sh.is_enum_class {
            bits |= SH_ENUM;
        }
        put_uvar(out, bits);
        scope_ref = self.ref_scope(sh.symbol_table);
        if scope_ref < 0
            and self.boundary is not None
            and sh.symbol_table is not None {
            self.note_orphan(sh);
        }
        put_ref(out, scope_ref);
        mro: list[TypeBase] = [];
        for cls in (sh.mro or []) {
            mro.append(cls);
        }
        put_refs(out, self.ref_types(mro));
        tps: list[TypeBase] = [];
        for tv in (sh.type_params or []) {
            tps.append(tv);
        }
        put_refs(out, self.ref_types(tps));
        put_refs(out, self.ref_types(sh.base_classes));
        fields = sh.typeddict_fields or {};
        put_uvar(out, len(fields));
        for (fname, ftype) in fields.items() {
            put_uvar(out, self.sid(fname));
            put_ref(out, self.ref_type(ftype));
        }
        put_ref(out, self.ref_type(sh.enum_value_type));
        members = sh.enum_members or {};
        put_uvar(out, len(members));
        for (mname, info) in members.items() {
            put_uvar(out, self.sid(mname));
            put_ref(out, self.ref_type(info.value_type));
            self.put_literal(out, info.literal_value);
        }
        ct_params = sh.ct_params or [];
        put_uvar(out, len(ct_params));
        for name in ct_params {
            put_uvar(out, self.sid(name));
        }
        derived = sh._derived_special_types or {};
        put_uvar(out, len(derived));
        for (dname, dtype) in derived.items() {
            put_uvar(out, self.sid(dname));
            put_ref(out, self.ref_type(dtype));
        }
        key = sh.canonical_key();
        if key is not None {
            put_uvar(out, self.sid(self.rel_of(key[0])));
            put_uvar(out, max(key[1], 0));
            put_uvar(out, max(key[2], 0));
        } else {
            put_uvar(out, self.sid(""));
            put_uvar(out, 0);
            put_uvar(out, 0);
        }
        return bytes(out);
    }

    def drain {
        while (
            self.pending_scopes
            or self.pending_syms
            or self.pending_types
            or self.pending_shared
        ) {
            while self.pending_scopes {
                i = self.pending_scopes.pop();
                self.scope_recs[i] = self.encode_scope(i);
            }
            while self.pending_syms {
                i = self.pending_syms.pop();
                self.sym_recs[i] = self.encode_symbol(i);
            }
            while self.pending_types {
                i = self.pending_types.pop();
                self.type_recs[i] = self.encode_type(i);
            }
            while self.pending_shared {
                i = self.pending_shared.pop();
                self.shared_recs[i] = self.encode_shared(i);
            }
        }
    }

    def emit(key: str, ambient: dict[str, set[str]]) -> bytes {
        while True {
            self.drain();
            if len(self.module_recs) == len(self.modules) {
                break;
            }
            for i in range(len(self.module_recs), len(self.modules)) {
                self.module_recs.append(self.encode_module(i));
            }
        }
        ambient_json: dict[str, list[str]] = {};
        for (mod_name, names) in ambient.items() {
            ambient_json[mod_name] = sorted(names);
        }
        key_sid = self.sid(key);
        ambient_sid = self.sid(json.dumps(ambient_json, sort_keys=True));

        recblob = bytearray();
        def lay(recs: list) -> bytes {
            offsets: list[bytes] = [];
            for r in recs {
                offsets.append(len(recblob).to_bytes(4, "little"));
                recblob.extend(r if r is not None else b"\x00");
            }
            return b"".join(offsets);
        }
        modtab = lay(self.module_recs);
        scopetab = lay(self.scope_recs);
        symtab = lay(self.sym_recs);
        typetab = lay(self.type_recs);
        sharedtab = lay(self.shared_recs);

        strblob = bytearray();
        strtab_parts: list[bytes] = [];
        for s in self.str_list {
            encoded = s.encode("utf-8");
            strtab_parts.append(struct.pack("<II", len(strblob), len(encoded)));
            strblob.extend(encoded);
        }
        strtab = b"".join(strtab_parts);

        h = Header();
        h.n_strings = len(self.str_list);
        h.n_modules = len(self.module_recs);
        h.n_scopes = len(self.scope_recs);
        h.n_symbols = len(self.sym_recs);
        h.n_types = len(self.type_recs);
        h.n_shared = len(self.shared_recs);
        h.key_sid = key_sid;
        h.ambient_sid = ambient_sid;
        pos = HEADER_SIZE;
        h.off_strtab = pos;
        pos += len(strtab);
        h.off_strblob = pos;
        pos += len(strblob);
        h.off_modtab = pos;
        pos += len(modtab);
        h.off_scopetab = pos;
        pos += len(scopetab);
        h.off_symtab = pos;
        pos += len(symtab);
        h.off_typetab = pos;
        pos += len(typetab);
        h.off_sharedtab = pos;
        pos += len(sharedtab);
        h.off_recblob = pos;
        return b"".join(
            [
                pack_header(h),
                strtab,
                bytes(strblob),
                modtab,
                scopetab,
                symtab,
                typetab,
                sharedtab,
                bytes(recblob)
            ]
        );
    }

    def manifest -> dict[str, any] {
        return {
            "modules": len(self.modules),
            "scopes": len(self.scopes),
            "symbols": len(self.syms),
            "types": len(self.types),
            "shared": len(self.shareds),
            "strings": len(self.str_list),
            "evaluated": self.evaluated,
            "failures": self.failures,
            "failure_log": list(self.failure_log)
        };
    }
}
