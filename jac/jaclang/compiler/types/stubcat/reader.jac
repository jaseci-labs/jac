import mmap;
import os;
import json;
import struct;
import from pathlib { Path }
import from jaclang.compiler.frontend.unitree {
    Ability,
    HasVar,
    Module,
    Name,
    Source,
    Symbol,
    SymbolProvider,
    Token,
    UniNode,
    UniScopeNode
}
import from jaclang.compiler.frontend.constant {
    BindingKind,
    OwnershipKind,
    SymbolAccess,
    SymbolType,
    Tokens as Tok
}
import from jaclang.compiler.types.types {
    AnyType,
    ClassDetailsPrivate,
    ClassDetailsShared,
    ClassType,
    EnumMemberInfo,
    EnumMemberType,
    FunctionType,
    ModuleType,
    NeverType,
    OverloadedType,
    ParamKind,
    Parameter,
    ParameterCategory,
    TypeBase,
    TypeFlags,
    TypeVarType,
    UnionType,
    UnknownType
}
import from jaclang.compiler.types.stubcat.format {
    ACCESS_PRIVATE,
    ACCESS_PROTECTED,
    Cursor,
    Header,
    LIT_BOOL,
    LIT_INT,
    LIT_STR,
    MOD_EXTERNAL,
    PM_CLS,
    PM_COMPTIME,
    PM_HAS_DEFAULT,
    PM_SELF,
    SC_MODULE,
    SH_BUILTIN,
    SH_DATACLASS,
    SH_ENUM,
    SH_NAMEDTUPLE,
    SH_ROOT,
    SH_STDLIB,
    SH_TYPEDDICT,
    SH_XREF,
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
    unpack_header
}

obj CatProvider(SymbolProvider) {
    has cat: StubCatalog,
        type_id: int,
        alias_mod: int,
        alias_name: str,
        prop_kind: int,
        write_kind: int,
        write_type_id: int,
        symbits: int = 0,
        memo: (TypeBase | None) = None,
        memo_set: bool = False;

    override def resolve_type(symbol: Symbol) -> TypeBase {
        if not self.memo_set {
            resolved = (
                self.cat.type_of(self.type_id) if self.type_id >= 0 else UnknownType()
            );
            if resolved is None {
                resolved = UnknownType();
            }
            self.memo = resolved;
            self.memo_set = True;
            try {
                symbol.decl.type = resolved;
            } except Exception {}
        }
        found = self.memo;
        if found is None {
            return UnknownType();
        }
        return found;
    }

    override def definition -> (Symbol | None) {
        if self.alias_mod < 0 {
            return None;
        }
        return self.cat.symbol_in_module(self.alias_mod, self.alias_name);
    }

    override def property_kind -> int {
        return self.prop_kind;
    }

    override def property_write_kind -> int {
        return self.write_kind;
    }

    override def property_write_type -> (TypeBase | None) {
        if self.write_type_id < 0 {
            return None;
        }
        return self.cat.type_of(self.write_type_id);
    }
}

node CatScope(UniScopeNode) {
    has cat: StubCatalog,
        cat_id: int,
        cat_kind: int,
        cat_name: str,
        cat_arch_kind: int,
        cat_kids: dict[str, int],
        cat_metaclass: int = -1,
        cat_owner_sym: (Symbol | None) = None;

    def init(
        *,
        cat: StubCatalog,
        cat_id: int,
        kind: int,
        name: str,
        arch_kind: int,
        kids: dict[str, int],
        tok: Token
    ) {
        self.cat = cat;
        self.cat_id = cat_id;
        self.cat_kind = kind;
        self.cat_name = name;
        self.cat_arch_kind = arch_kind;
        self.cat_kids = kids;
        self.cat_metaclass = -1;
        self.cat_owner_sym = None;
        UniScopeNode.init(self, kid=[tok]);
    }

    def postinit {
        UniNode.postinit(self);
        UniScopeNode._init_scope(self, name=self.cat_name);
    }

    def find_scope(name: str) -> (UniScopeNode | None) {
        sid = self.cat_kids.get(name);
        if sid is None {
            return None;
        }
        return self.cat.scope_of(sid);
    }

    def metaclass_type -> (TypeBase | None) {
        if self.cat_metaclass < 0 {
            return None;
        }
        return self.cat.type_of(self.cat_metaclass);
    }

    def get_has_vars -> list[HasVar] {
        return [];
    }

    def get_methods -> list[Ability] {
        return [];
    }

    def __repr__ -> str {
        return f"CatScope({self.cat_name})";
    }
}

node CatModule(Module) {
    has cat: StubCatalog,
        cat_id: int,
        cat_kids: dict[str, int];

    def init(
        *, cat: StubCatalog, cat_id: int, name: str, kids: dict[str, int], tok: Token
    ) {
        self.cat = cat;
        self.cat_id = cat_id;
        self.cat_kids = kids;
        Module.init(
            self,
            name=name,
            source=tok.orig_src,
            body=[],
            terminals=[],
            stub_only=True,
            kid=[tok]
        );
    }

    def find_scope(name: str) -> (UniScopeNode | None) {
        sid = self.cat_kids.get(name);
        if sid is None {
            return None;
        }
        return self.cat.scope_of(sid);
    }

    def __repr__ -> str {
        return f"CatModule({self.name})";
    }
}

obj ScopeRec {
    has kind: int = 0,
        name: str = "",
        parent: int = -1,
        module: int = -1,
        owner: int = -1,
        line: int = 0,
        col: int = 0,
        end_line: int = 0,
        end_col: int = 0,
        arch_kind: int = 0,
        metaclass: int = -1,
        members: list[tuple[str, int]] = [],
        overloads: list[tuple[str, list[int]]] = [],
        kids: dict[str, int] = {};
}

obj SymbolRec {
    has name: str = "",
        symtype: str = "",
        access: int = 0,
        imported: bool = False,
        line: int = 0,
        col: int = 0,
        end_line: int = 0,
        end_col: int = 0,
        module: int = -1,
        scope: int = -1,
        type_id: int = -1,
        alias_mod: int = -1,
        alias_name: str = "",
        prop_kind: int = 0,
        write_kind: int = 0,
        write_type: int = -1,
        ownership: int = 0,
        binding: int = 0,
        symbits: int = 0;
}

obj StubCatalog {
    has buf: any,
        pkg_dir: str,
        keepalive: any = None,
        resolver: any = None,
        hdr: Header postinit,
        _str_memo: dict[int, str] postinit,
        _mod_memo: dict[int, Module] postinit,
        _scope_memo: dict[int, UniScopeNode] postinit,
        _sym_memo: dict[int, Symbol] postinit,
        _type_memo: dict[int, TypeBase] postinit,
        _shared_memo: dict[int, ClassDetailsShared] postinit,
        _sources: dict[int, Source] postinit,
        _mod_names: dict[str, int] postinit,
        _mod_rel: dict[str, int] postinit,
        _mod_recs: list[tuple[str, str, int, int, str]] postinit,
        _base_dir: str postinit;

    def postinit {
        hdr = unpack_header(self.buf);
        if hdr is None {
            raise ValueError("not a stub catalog (bad magic or format version)");
        }
        self.hdr = hdr;
        self._str_memo = {};
        self._mod_memo = {};
        self._scope_memo = {};
        self._sym_memo = {};
        self._type_memo = {};
        self._shared_memo = {};
        self._sources = {};
        self._mod_names = {};
        self._mod_rel = {};
        self._mod_recs = [];
        self._base_dir = os.path.realpath(self.pkg_dir);
        for i in range(hdr.n_modules) {
            c = self._rec(hdr.off_modtab, i);
            name = self.string(c.u());
            rel = self.string(c.u());
            flags = c.u();
            scope = c.ref();
            decided = self.string(c.u());
            self._mod_names[name] = i;
            self._mod_rel[rel] = i;
            self._mod_recs.append((name, rel, flags, scope, decided));
        }
    }

    def string(sid: int) -> str {
        found = self._str_memo.get(sid);
        if found is not None {
            return found;
        }
        (off, length) = struct.unpack_from(
            "<II", self.buf, self.hdr.off_strtab + sid * 8
        );
        start = self.hdr.off_strblob + off;
        text = bytes(self.buf[start:start + length]).decode("utf-8");
        self._str_memo[sid] = text;
        return text;
    }

    def string_or_none(sid: int) -> (str | None) {
        if sid == 0 {
            return None;
        }
        return self.string(sid);
    }

    def _rec(table_off: int, idx: int) -> Cursor {
        (off, ) = struct.unpack_from("<I", self.buf, table_off + idx * 4);
        return Cursor(buf=self.buf, pos=self.hdr.off_recblob + off);
    }

    def key -> str {
        return self.string(self.hdr.key_sid);
    }

    def ambient_typing_names -> dict[str, set[str]] {
        raw = json.loads(self.string(self.hdr.ambient_sid));
        out: dict[str, set[str]] = {};
        for (mod_name, names) in raw.items() {
            out[mod_name] = set(names);
        }
        return out;
    }

    def abs_path(rel: str) -> str {
        if not rel {
            return "";
        }
        if os.path.isabs(rel) {
            return rel;
        }
        return os.path.join(self._base_dir, *rel.split("/"));
    }

    def rel_of(path: str) -> (str | None) {
        try {
            real = os.path.realpath(path);
        } except OSError {
            return None;
        }
        prefix = self._base_dir + os.sep;
        if not real.startswith(prefix) {
            return None;
        }
        return real[len(prefix):].replace(os.sep, "/");
    }

    def module_path(parts: list[str]) -> (str | None) {
        mid = self._mod_names.get(".".join(parts));
        if mid is None {
            return None;
        }
        return self.abs_path(self._mod_recs[mid][1]);
    }

    def module(name: str) -> (Module | None) {
        mid = self._mod_names.get(name);
        if mid is None {
            return None;
        }
        return self.module_by_id(mid);
    }

    def module_for_path(path: str) -> (Module | None) {
        rel = self.rel_of(path);
        if rel is None {
            return None;
        }
        mid = self._mod_rel.get(rel);
        if mid is None {
            return None;
        }
        return self.module_by_id(mid);
    }

    def symbol_in_module(mid: int, name: str) -> (Symbol | None) {
        mod = self.module_by_id(mid);
        if mod is None {
            return None;
        }
        return mod.names_in_scope.get(name);
    }

    def _source(mid: int) -> Source {
        found = self._sources.get(mid);
        if found is not None {
            return found;
        }
        path = self.abs_path(self._mod_recs[mid][1]) if mid >= 0 else "<stubcat>";
        src = Source("", path);
        self._sources[mid] = src;
        return src;
    }

    def _token(
        mid: int, name: str, line: int, col: int, end_line: int, end_col: int
    ) -> Token {
        return Token(
            orig_src=self._source(mid),
            name=Tok.NAME.value,
            value=name,
            line=line,
            end_line=end_line,
            col_start=col,
            col_end=end_col,
            pos_start=0,
            pos_end=0
        );
    }

    def module_by_id(mid: int) -> (Module | None) {
        if mid < 0 {
            return None;
        }
        found = self._mod_memo.get(mid);
        if found is not None {
            return found;
        }
        (name, rel, flags, scope_id, decided) = self._mod_recs[mid];
        if (flags & MOD_EXTERNAL) != 0 or scope_id < 0 {
            ext: (Module | None) = None;
            if self.resolver is not None {
                try {
                    ext = self.resolver.resolve_module(self.abs_path(rel));
                } except Exception {
                    ext = None;
                }
            }
            if ext is None {
                tok = self._token(mid, name, 1, 0, 1, 0);
                ext = CatModule(cat=self, cat_id=mid, name=name, kids={}, tok=tok);
            }
            self._mod_memo[mid] = ext;
            return ext;
        }
        rec = self._read_scope(scope_id);
        tok = self._token(mid, name, 1, 0, 1, 0);
        mod = CatModule(cat=self, cat_id=mid, name=name, kids=rec.kids, tok=tok);
        self._mod_memo[mid] = mod;
        self._scope_memo[scope_id] = mod;
        if decided {
            try {
                mod.decided_codespace = decided;
            } except Exception {}
        }
        if name != "builtins" {
            builtins = self.module("builtins");
            if builtins is not None {
                mod.parent_scope = builtins;
            }
        }
        self._populate(mod, rec);
        return mod;
    }

    def _read_scope(sid: int) -> ScopeRec {
        c = self._rec(self.hdr.off_scopetab, sid);
        rec = ScopeRec();
        rec.kind = c.u();
        rec.name = self.string(c.u());
        rec.parent = c.ref();
        rec.module = c.ref();
        rec.owner = c.ref();
        rec.line = c.u();
        rec.col = c.u();
        rec.end_line = c.u();
        rec.end_col = c.u();
        rec.arch_kind = c.u();
        rec.metaclass = c.ref();
        members: list[tuple[str, int]] = [];
        n = c.u();
        for i in range(n) {
            nm = self.string(c.u());
            members.append((nm, c.ref()));
        }
        rec.members = members;
        overloads: list[tuple[str, list[int]]] = [];
        n = c.u();
        for i in range(n) {
            nm = self.string(c.u());
            overloads.append((nm, c.refs()));
        }
        rec.overloads = overloads;
        kids: dict[str, int] = {};
        n = c.u();
        for i in range(n) {
            nm = self.string(c.u());
            kids[nm] = c.ref();
        }
        rec.kids = kids;
        return rec;
    }

    def scope_of(sid: int) -> (UniScopeNode | None) {
        if sid < 0 {
            return None;
        }
        found = self._scope_memo.get(sid);
        if found is not None {
            return found;
        }
        rec = self._read_scope(sid);
        if rec.kind == SC_MODULE {
            return self.module_by_id(rec.module);
        }
        tok = self._token(
            rec.module, rec.name, rec.line, rec.col, rec.end_line, rec.end_col
        );
        scope = CatScope(
            cat=self,
            cat_id=sid,
            kind=rec.kind,
            name=rec.name,
            arch_kind=rec.arch_kind,
            kids=rec.kids,
            tok=tok
        );
        self._scope_memo[sid] = scope;
        scope.cat_metaclass = rec.metaclass;
        if rec.parent >= 0 {
            parent = self.scope_of(rec.parent);
            if parent is not None {
                scope.parent_scope = parent;
                scope.set_parent(parent);
            }
        }
        if rec.owner >= 0 {
            scope.cat_owner_sym = self.symbol_of(rec.owner);
        }
        self._populate(scope, rec);
        return scope;
    }

    def _populate(scope: UniScopeNode, rec: ScopeRec) {
        index = scope._names_index;
        for (name, sym_id) in rec.members {
            sym = self.symbol_of(sym_id);
            if sym is not None {
                index[name] = sym;
            }
        }
        if rec.overloads {
            overload_index = scope._overload_index;
            for (name, ids) in rec.overloads {
                extra: list[Symbol] = [];
                for sym_id in ids {
                    sym = self.symbol_of(sym_id);
                    if sym is not None {
                        extra.append(sym);
                    }
                }
                overload_index[name] = extra;
            }
        }
    }

    def _read_symbol(sid: int) -> SymbolRec {
        c = self._rec(self.hdr.off_symtab, sid);
        rec = SymbolRec();
        rec.name = self.string(c.u());
        rec.symtype = self.string(c.u());
        rec.access = c.u();
        rec.imported = c.u() == 1;
        rec.line = c.u();
        rec.col = c.u();
        rec.end_line = c.u();
        rec.end_col = c.u();
        rec.module = c.ref();
        rec.scope = c.ref();
        rec.type_id = c.ref();
        rec.alias_mod = c.ref();
        rec.alias_name = self.string(c.u());
        rec.prop_kind = c.u();
        rec.write_kind = c.u();
        rec.write_type = c.ref();
        rec.ownership = c.u();
        rec.binding = c.u();
        rec.symbits = c.u();
        return rec;
    }

    def symbol_of(sid: int) -> (Symbol | None) {
        if sid < 0 {
            return None;
        }
        found = self._sym_memo.get(sid);
        if found is not None {
            return found;
        }
        rec = self._read_symbol(sid);
        scope = self.scope_of(rec.scope);
        found = self._sym_memo.get(sid);
        if found is not None {
            return found;
        }
        return self._make_symbol(sid, rec, scope);
    }

    def _make_symbol(sid: int, rec: SymbolRec, scope: (UniScopeNode | None)) -> Symbol {
        tok = Name(
            orig_src=self._source(rec.module),
            name=Tok.NAME.value,
            value=rec.name,
            line=rec.line,
            end_line=rec.end_line,
            col_start=rec.col,
            col_end=rec.end_col,
            pos_start=0,
            pos_end=0
        );
        category: SymbolType = SymbolType.VAR;
        try {
            category = SymbolType(rec.symtype);
        } except ValueError {
            category = SymbolType.VAR;
        }
        tok.bind_sym(tok, rec.name, category);
        if scope is not None {
            tok.set_parent(scope);
        }
        access = SymbolAccess.PUBLIC;
        if rec.access == ACCESS_PRIVATE {
            access = SymbolAccess.PRIVATE;
        } elif rec.access == ACCESS_PROTECTED {
            access = SymbolAccess.PROTECTED;
        }
        sym = Symbol(defn=tok, access=access, parent_tab=scope, imported=rec.imported);
        sym.provider = CatProvider(
            cat=self,
            type_id=rec.type_id,
            alias_mod=rec.alias_mod,
            alias_name=rec.alias_name,
            prop_kind=rec.prop_kind,
            write_kind=rec.write_kind,
            write_type_id=rec.write_type,
            symbits=rec.symbits
        );
        if rec.ownership {
            try {
                sym.ownership = OwnershipKind(rec.ownership);
            } except ValueError {}
        }
        if rec.binding == 1 {
            sym._binding_kind = BindingKind.VALUE;
        } elif rec.binding == 2 {
            sym._binding_kind = BindingKind.TYPE;
        } elif rec.binding == 3 {
            sym._binding_kind = BindingKind.BOTH;
        }
        sym.param_rebound = (rec.symbits & SYMF_PARAM_REBOUND) != 0;
        sym.na_escapes = (rec.symbits & SYMF_NA_ESCAPES) != 0;
        sym.na_region_handle = (rec.symbits & SYMF_NA_REGION_HANDLE) != 0;
        sym.na_stack_ok = (rec.symbits & SYMF_NA_STACK_OK) != 0;
        self._sym_memo[sid] = sym;
        return sym;
    }

    def _flags(value: int) -> any {
        try {
            return TypeFlags(value);
        } except ValueError {
            return value;
        }
    }

    def _literal(c: Cursor) -> (str | int | bool | None) {
        kind = c.u();
        if kind == LIT_STR {
            return self.string(c.u());
        }
        if kind == LIT_INT {
            return c.s();
        }
        if kind == LIT_BOOL {
            return c.u() == 1;
        }
        return None;
    }

    def _types(ids: list[int]) -> list[TypeBase] {
        out: list[TypeBase] = [];
        for i in ids {
            t = self.type_of(i);
            if t is not None {
                out.append(t);
            }
        }
        return out;
    }

    def type_of(tid: int) -> (TypeBase | None) {
        if tid < 0 {
            return None;
        }
        found = self._type_memo.get(tid);
        if found is not None {
            return found;
        }
        c = self._rec(self.hdr.off_typetab, tid);
        tag = c.u();
        flags = self._flags(c.u());
        if tag == TY_CLASS {
            shared_id = c.ref();
            type_args = c.refs();
            alias_name = self.string_or_none(c.u());
            literal = self._literal(c);
            distinct_key = self.string_or_none(c.u());
            private = ClassDetailsPrivate(
                type_args=None,
                alias_name=alias_name,
                literal_value=literal,
                distinct_key=distinct_key
            );
            cls = ClassType(_shared=None, private=private, flags=flags);
            self._type_memo[tid] = cls;
            cls._shared = self.shared_of(shared_id);
            if type_args {
                cls.private.type_args = self._types(type_args);
            }
            return cls;
        }
        if tag == TY_FUNCTION {
            name = self.string(c.u());
            function_flags = c.u();
            is_async = c.u() == 1;
            guard_strict = c.u() == 1;
            ret = c.ref();
            guard = c.ref();
            type_params = c.refs();
            n_params = c.u();
            raw_params: list[tuple[str, int, int, int, int]] = [];
            for i in range(n_params) {
                pname = self.string(c.u());
                category = c.u();
                kind = c.u();
                ptype = c.ref();
                bits = c.u();
                raw_params.append((pname, category, kind, ptype, bits));
            }
            fn = FunctionType(
                func_name=name,
                return_type=None,
                parameters=None,
                function_flags=function_flags,
                type_params=None,
                is_async=is_async,
                type_guard=None,
                type_guard_is_strict=guard_strict,
                flags=flags
            );
            self._type_memo[tid] = fn;
            fn.return_type = self.type_of(ret);
            params: list[Parameter] = [];
            for (pname, category, kind, ptype, bits) in raw_params {
                params.append(
                    Parameter(
                        name=pname,
                        category=ParameterCategory(category) if category > 0 else None,
                        param_type=self.type_of(ptype),
                        default_value=None,
                        is_self=(bits & PM_SELF) != 0,
                        is_cls=(bits & PM_CLS) != 0,
                        param_kind=ParamKind(kind),
                        has_default=(bits & PM_HAS_DEFAULT) != 0,
                        is_comptime=(bits & PM_COMPTIME) != 0
                    )
                );
            }
            fn.parameters = params;
            if type_params {
                tps: list[TypeVarType] = [];
                for tv in self._types(type_params) {
                    if isinstance(tv, TypeVarType) {
                        tps.append(tv);
                    }
                }
                fn.type_params = tps;
            }
            if guard >= 0 {
                fn.type_guard = self.type_of(guard);
            }
            return fn;
        }
        if tag == TY_OVERLOAD {
            ids = c.refs();
            ov = OverloadedType(overloads=None, flags=flags);
            self._type_memo[tid] = ov;
            fns: list[FunctionType] = [];
            for t in self._types(ids) {
                if isinstance(t, FunctionType) {
                    fns.append(t);
                }
            }
            ov.overloads = fns;
            return ov;
        }
        if tag == TY_UNION {
            ids = c.refs();
            un = UnionType(types=None, flags=flags);
            self._type_memo[tid] = un;
            un.types = self._types(ids);
            return un;
        }
        if tag == TY_TYPEVAR {
            name = self.string(c.u());
            bits = c.u();
            bound = c.ref();
            constraints = c.refs();
            tv = TypeVarType(
                name=name,
                is_covariant=(bits & TV_COVARIANT) != 0,
                is_contravariant=(bits & TV_CONTRAVARIANT) != 0,
                is_self=(bits & TV_SELF) != 0,
                is_param_spec=(bits & TV_PARAM_SPEC) != 0,
                is_class_type_param=(bits & TV_CLASS_PARAM) != 0,
                bound=None,
                constraints=None,
                flags=flags
            );
            self._type_memo[tid] = tv;
            if bound >= 0 {
                tv.bound = self.type_of(bound);
            }
            if constraints {
                tv.constraints = self._types(constraints);
            }
            return tv;
        }
        if tag == TY_MODULE {
            mod_name = self.string(c.u());
            rel = self.string(c.u());
            is_external = c.u() == 1;
            mid = c.ref();
            file_path = self.abs_path(rel)
                if "/" in rel or rel.endswith(".pyi")
                else rel;
            mt = ModuleType(
                mod_name=mod_name,
                file_uri=Path(file_path) if file_path else Path(""),
                symbol_table=None,
                is_external=is_external,
                flags=flags
            );
            self._type_memo[tid] = mt;
            if mid >= 0 {
                mt.symbol_table = self.module_by_id(mid);
            }
            return mt;
        }
        if tag == TY_ENUM_MEMBER {
            enum_cls = c.ref();
            member_name = self.string(c.u());
            value_type = c.ref();
            literal = self._literal(c);
            em = EnumMemberType(enum_class=None, member_info=None, flags=flags);
            self._type_memo[tid] = em;
            cls_t = self.type_of(enum_cls);
            if isinstance(cls_t, ClassType) {
                em.enum_class = cls_t;
            }
            lit: (int | str | None) = None;
            if isinstance(literal, bool) {
                lit = 1 if literal else 0;
            } elif isinstance(literal, (int, str)) {
                lit = literal;
            }
            em.member_info = EnumMemberInfo(
                member_name=member_name,
                value_type=self.type_of(value_type),
                literal_value=lit
            );
            return em;
        }
        if tag == TY_NEVER {
            nv = NeverType(flags=flags);
            self._type_memo[tid] = nv;
            return nv;
        }
        if tag == TY_ANY {
            is_foreign = c.u() == 1;
            scalar = self.string_or_none(c.u());
            an = AnyType(flags=flags, is_foreign=is_foreign, foreign_scalar=scalar);
            self._type_memo[tid] = an;
            return an;
        }
        is_diagnosed = c.u() == 1 if tag == TY_UNKNOWN else False;
        is_incomplete = c.u() == 1 if tag == TY_UNKNOWN else False;
        uk = UnknownType(
            flags=flags, is_diagnosed=is_diagnosed, is_incomplete=is_incomplete
        );
        self._type_memo[tid] = uk;
        return uk;
    }

    def shared_of(shid: int) -> (ClassDetailsShared | None) {
        if shid < 0 {
            return None;
        }
        found = self._shared_memo.get(shid);
        if found is not None {
            return found;
        }
        c = self._rec(self.hdr.off_sharedtab, shid);
        name = self.string(c.u());
        bits = c.u();
        if (bits & SH_XREF) != 0 {
            xmid = c.ref();
            dotted = self.string(c.u());
            ident_rel = self.string(c.u());
            ident_line = c.u();
            ident_col = c.u();
            resolved: (ClassDetailsShared | None) = None;
            if self.resolver is not None and xmid >= 0 {
                try {
                    resolved = self.resolver.resolve_shared(
                        self.abs_path(self._mod_recs[xmid][1]), dotted, name
                    );
                } except Exception {
                    resolved = None;
                }
            }
            if resolved is None {
                resolved = ClassDetailsShared(
                    class_name=name,
                    symbol_table=self._orphan_scope(name),
                    mro=None,
                    type_params=None,
                    base_classes=None,
                    _identity_key=(
                        self.abs_path(ident_rel),
                        ident_line,
                        ident_col,
                        name
                    )
                );
                resolved.mro = [];
            }
            self._shared_memo[shid] = resolved;
            return resolved;
        }
        scope_id = c.ref();
        mro = c.refs();
        type_params = c.refs();
        bases = c.refs();
        n = c.u();
        td_fields: list[tuple[str, int]] = [];
        for i in range(n) {
            fname = self.string(c.u());
            td_fields.append((fname, c.ref()));
        }
        enum_value_type = c.ref();
        n = c.u();
        enum_members: list[tuple[str, int, (str | int | bool | None)]] = [];
        for i in range(n) {
            mname = self.string(c.u());
            vt = c.ref();
            enum_members.append((mname, vt, self._literal(c)));
        }
        n = c.u();
        ct_params: list[str] = [];
        for i in range(n) {
            ct_params.append(self.string(c.u()));
        }
        ct_params_opt: (list[str] | None) = None;
        if len(ct_params) > 0 {
            ct_params_opt = ct_params;
        }
        n = c.u();
        derived: list[tuple[str, int]] = [];
        for i in range(n) {
            dname = self.string(c.u());
            derived.append((dname, c.ref()));
        }
        ident_rel = self.string(c.u());
        ident_line = c.u();
        ident_col = c.u();
        scope = self.scope_of(scope_id);
        if scope is None {
            scope = self._orphan_scope(name);
        }
        identity = (self.abs_path(ident_rel), ident_line, ident_col, name);
        shared = ClassDetailsShared(
            class_name=name,
            symbol_table=scope,
            mro=None,
            type_params=None,
            base_classes=None,
            is_builtin_class=(bits & SH_BUILTIN) != 0,
            is_from_stdlib_stub=(bits & SH_STDLIB) != 0,
            is_data_class=(bits & SH_DATACLASS) != 0,
            is_namedtuple=(bits & SH_NAMEDTUPLE) != 0,
            is_typeddict=(bits & SH_TYPEDDICT) != 0,
            typeddict_fields=None,
            is_root_class=(bits & SH_ROOT) != 0,
            is_enum_class=(bits & SH_ENUM) != 0,
            enum_value_type=None,
            enum_members=None,
            _identity_key=identity,
            ct_params=ct_params_opt
        );
        self._shared_memo[shid] = shared;
        if bases {
            shared.base_classes = self._types(bases);
        }
        if type_params {
            tps: list[TypeVarType] = [];
            for tv in self._types(type_params) {
                if isinstance(tv, TypeVarType) {
                    tps.append(tv);
                }
            }
            shared.type_params = tps;
        }
        mro_types: list[ClassType] = [];
        for t in self._types(mro) {
            if isinstance(t, ClassType) {
                mro_types.append(t);
            }
        }
        shared.mro = mro_types;
        if td_fields {
            fields: dict[str, TypeBase] = {};
            for (fname, ftype) in td_fields {
                ft = self.type_of(ftype);
                if ft is not None {
                    fields[fname] = ft;
                }
            }
            shared.typeddict_fields = fields;
        }
        if enum_value_type >= 0 {
            shared.enum_value_type = self.type_of(enum_value_type);
        }
        if derived {
            specials: dict[str, ClassType] = {};
            for (dname, dtype) in derived {
                dt = self.type_of(dtype);
                if isinstance(dt, ClassType) {
                    specials[dname] = dt;
                }
            }
            shared._derived_special_types = specials;
        }
        if enum_members {
            members: dict[str, EnumMemberInfo] = {};
            for (mname, vt, literal) in enum_members {
                lit: (int | str | None) = None;
                if isinstance(literal, bool) {
                    lit = 1 if literal else 0;
                } elif isinstance(literal, (int, str)) {
                    lit = literal;
                }
                members[mname] = EnumMemberInfo(
                    member_name=mname, value_type=self.type_of(vt), literal_value=lit
                );
            }
            shared.enum_members = members;
        }
        return shared;
    }

    def _orphan_scope(name: str) -> UniScopeNode {
        tok = self._token(-1, name, 0, 0, 0, 0);
        return CatScope(
            cat=self, cat_id=-1, kind=1, name=name, arch_kind=0, kids={}, tok=tok
        );
    }
}

def map_region(path: str, offset: int, length: int) -> (tuple[any, any] | None) {
    try {
        fd = os.open(path, os.O_RDONLY);
    } except OSError {
        return None;
    }
    try {
        gran = mmap.ALLOCATIONGRANULARITY;
        base = offset - (offset % gran);
        span = length + (offset - base);
        mm = mmap.mmap(fd, span, access=mmap.ACCESS_READ, offset=base);
    } except (OSError, ValueError) {
        os.close(fd);
        return None;
    }
    os.close(fd);
    view = memoryview(mm)[offset - base:offset - base + length];
    return (mm, view);
}

def open_catalog_file(path: str, pkg_dir: str) -> (StubCatalog | None) {
    try {
        size = os.path.getsize(path);
    } except OSError {
        return None;
    }
    if size <= 0 {
        return None;
    }
    mapped = map_region(path, 0, size);
    if mapped is None {
        return None;
    }
    (mm, view) = mapped;
    try {
        return StubCatalog(buf=view, pkg_dir=pkg_dir, keepalive=mm);
    } except ValueError {
        return None;
    }
}

def open_catalog_region(
    path: str, offset: int, length: int, pkg_dir: str
) -> (StubCatalog | None) {
    if length <= 0 {
        return None;
    }
    mapped = map_region(path, offset, length);
    if mapped is None {
        return None;
    }
    (mm, view) = mapped;
    try {
        return StubCatalog(buf=view, pkg_dir=pkg_dir, keepalive=mm);
    } except ValueError {
        return None;
    }
}
