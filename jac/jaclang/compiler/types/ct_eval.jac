import os;
import from jaclang.compiler.frontend.unitree {
    Ability,
    Archetype,
    AssertStmt,
    Assignment,
    AstImplNeedingNode,
    AtomTrailer,
    AtomUnit,
    BinaryExpr,
    Bool,
    BoolExpr,
    BuiltinType,
    CastExpr,
    CfgExpr,
    CompareExpr,
    CtrlStmt,
    DictCompr,
    DictVal,
    ElseIf,
    ElseStmt,
    Enum,
    Expr,
    ExprStmt,
    Float,
    FormattedValue,
    FString,
    FuncCall,
    FuncSignature,
    GlobalVars,
    HasVar,
    IfElseExpr,
    IfStmt,
    ImplDef,
    Import,
    InForStmt,
    IndexSlice,
    InnerCompr,
    Int,
    KVPair,
    KWPair,
    ListCompr,
    ListVal,
    Module,
    ModuleItem,
    ModulePath,
    MultiString,
    Name,
    Null,
    ParamVar,
    RaiseStmt,
    ReturnStmt,
    Semi,
    SetCompr,
    SetVal,
    Slice,
    SpecialVarRef,
    String,
    Symbol,
    Token,
    TryStmt,
    TupleVal,
    TypeParam,
    UnaryExpr,
    UniNode,
    UniScopeNode,
    WhileStmt
}
import from jaclang.compiler.frontend.constant {
    CodeContext,
    OwnershipKind,
    Tokens as Tok
}
import from jaclang.compiler.frontend.codeinfo { module_dotted_name }
import from jaclang.runtime.scalars { shape_of }
import from jaclang.compiler.types.ct_value {
    CT_DEFERRED,
    CT_NONE,
    CtBool,
    CtBound,
    CtBuiltin,
    CtBytes,
    CtCaller,
    CtDeferred,
    CtDeferredSignal,
    CtDict,
    CtEnumMember,
    CtEnvironment,
    CtError,
    CtExc,
    CtFloat,
    CtFunc,
    CtInt,
    CtList,
    CtMethod,
    CtModule,
    CtNone,
    CtNotComptime,
    CtRaise,
    CtRange,
    CtRecord,
    CtSet,
    CtStr,
    CtTuple,
    CtType,
    CtValue,
    CtView,
    as_ct_int,
    ascii_escape,
    ct_eq,
    ct_exc,
    ct_exc_is,
    ct_iter,
    ct_repr,
    ct_str,
    ct_truthy,
    ct_type_name,
    dict_set,
    mk_bool,
    mk_bytes,
    mk_dict,
    mk_float,
    mk_int,
    mk_list,
    mk_set,
    mk_str,
    mk_tuple,
    range_len,
    set_add
}
import from jaclang.compiler.types.ct_ops {
    ct_compare,
    ct_getitem,
    ct_getslice,
    ct_int_literal,
    ct_setitem,
    ct_symbol,
    ct_unary,
    int_add,
    int_cmp
}
import from jaclang.compiler.types.ct_format {
    ct_binary,
    ct_convert,
    ct_format,
    ct_inplace
}
import from jaclang.compiler.types.ct_builtins {
    CT_BUILTIN_EXCEPTIONS,
    CT_BUILTIN_FUNCS,
    CT_BUILTIN_TYPES,
    ct_call_builtin,
    ct_call_method,
    ct_call_method_value,
    ct_construct_builtin,
    ct_type_attr,
    ct_value_attr
}
import from jaclang.compiler.types.types {
    ClassType,
    ModuleType,
    TypeBase,
    UnknownType
}
import from jaclang.compiler.types.stubcat.reader { CatModule }
import from jaclang.compiler.types.type_utils { lookup_symtab }
import type from jaclang.compiler.types.type_evaluator { TypeEvaluator }

glob CT_FUEL_DEFAULT: int = 50000000,
     CT_MODULE_SUFFIX: str = "jaclang/comptime.jac",
     CT_INTRINSICS: frozenset[str] = frozenset(
         {
             "typeof",
             "fields",
             "get_field",
             "set_field",
             "has_field",
             "members",
             "semstr",
             "name",
             "module_of",
             "is_subtype",
             "set_fuel",
             "embed_file",
             "embed_bytes",
             "sizeof",
             "alignof"
         }
     ),
     CT_AUG_OPS: dict[str, str] = {
         "ADD_EQ": "+",
         "SUB_EQ": "-",
         "MUL_EQ": "*",
         "DIV_EQ": "/",
         "FLOOR_DIV_EQ": "//",
         "MOD_EQ": "%",
         "STAR_POW_EQ": "**",
         "BW_AND_EQ": "&",
         "BW_OR_EQ": "|",
         "BW_XOR_EQ": "^",
         "LSHIFT_EQ": "<<",
         "RSHIFT_EQ": ">>"
     },
     CT_CMP_OPS: dict[str, str] = {
         "EE": "==",
         "NE": "!=",
         "LT": "<",
         "LTE": "<=",
         "GT": ">",
         "GTE": ">=",
         "KW_IN": "in",
         "KW_NIN": "not in",
         "KW_IS": "is",
         "KW_ISN": "is not"
     },
     CT_UNARY_OPS: dict[str, str] = {
         "MINUS": "-",
         "PLUS": "+",
         "NOT": "not",
         "BW_NOT": "~"
     };

def ct_read_host_file(path: str) -> bytes {
    with open(path, "rb") as fh {
        return fh.read();
    }
}

def _norm_path(p: str) -> str {
    return p.replace("\\", "/");
}

def _is_comptime_module(mod: (Module | None)) -> bool {
    if mod is None {
        return False;
    }
    return _norm_path(mod.loc.mod_path if mod.loc else "").endswith(CT_MODULE_SUFFIX);
}

def _mod_dotted(mod: (Module | None)) -> str {
    if mod is None {
        return "";
    }
    return module_dotted_name(mod.loc.mod_path if mod.loc else "", str(mod.name));
}

def _scope_of(nd: UniNode) -> (UniScopeNode | None) {
    try {
        return nd.sym_tab;
    } except ValueError {
        return None;
    }
}

def _impl_body(nd: UniNode) -> list[UniNode] {
    if not isinstance(nd, AstImplNeedingNode) {
        return [];
    }
    body = nd.body;
    if isinstance(body, ImplDef) {
        inner = body.body;
        if isinstance(inner, list) {
            return inner;
        }
        return [];
    }
    if isinstance(body, list) {
        return body;
    }
    return [];
}

def _is_builtin_name(name: str) -> bool {
    return name in CT_BUILTIN_TYPES
        or name in CT_BUILTIN_EXCEPTIONS
        or name in CT_BUILTIN_FUNCS;
}

obj CtEvaluator(CtCaller) {
    has evaluator: TypeEvaluator,
        env: CtEnvironment = CtEnvironment(),
        fuel: int = CT_FUEL_DEFAULT,
        frames: list[dict[str, CtValue]] = [],
        barriers: list[bool] = [],
        call_stack: list[str] = [],
        last_error: (str | None) = None,
        demand: bool = False,
        _failed: set[int] = set(),
        _active: set[tuple[str, int]] = set(),
        _enum_cache: dict[int, list[CtEnumMember]] = {},
        _handling: list[CtExc] = [],
        _ret: CtValue = CT_NONE,
        _ct_root: (Module | None) = None;

    def _enter_root(nd: UniNode) -> (Module | None) {
        prev = self._ct_root;
        if prev is None {
            self._ct_root = nd.find_parent_of_type(Module);
        }
        return prev;
    }

    def _note_ct_path(path: str, body: bool = False) {
        owner = self._ct_root;
        if owner is None or not path {
            return;
        }
        owner.record_comptime_dependency(path, body);
    }

    def _note_producer(home: (Module | None), body: bool = False) {
        if home is None or home is self._ct_root {
            return;
        }
        path = _norm_path(home.loc.mod_path if home.loc else "");
        if not path.endswith(".jac") {
            return;
        }
        try {
            self._note_ct_path(os.path.realpath(path), body=body);
        } except OSError {}
    }

    def try_eval(nd: Expr, demand: bool = False) -> (CtValue | None) {
        self.last_error = None;
        key = ("node", id(nd));
        if key in self._active {
            return None;
        }
        self._active.add(key);
        saved_frames = self.frames;
        saved_barriers = self.barriers;
        saved_demand = self.demand;
        saved_handling = self._handling;
        saved_root = self._enter_root(nd);
        self.frames = [];
        self.barriers = [];
        self._handling = [];
        self.demand = demand;
        try {
            return self._eval_inner(nd);
        } except CtDeferredSignal {
            return CT_DEFERRED;
        } except CtNotComptime {
            self._failed.add(id(nd));
            return None;
        } except CtError as e {
            self.last_error = str(e);
            self._failed.add(id(nd));
            return None;
        } except CtRaise as e {
            if e.user {
                self.last_error = f"comptime code raised {ct_str(e.exc)}";
            } else {
                self.last_error = f"{e.exc.kind}: {ct_str(e.exc)}";
            }
            self._failed.add(id(nd));
            return None;
        } except RecursionError {
            self.last_error = "comptime evaluation recursed too deeply";
            self._failed.add(id(nd));
            return None;
        } except Exception as e {
            self.last_error = f"{type(e).__name__}: {e}";
            self._failed.add(id(nd));
            return None;
        } finally {
            self._active.discard(key);
            self.frames = saved_frames;
            self.barriers = saved_barriers;
            self.demand = saved_demand;
            self._handling = saved_handling;
            self._ct_root = saved_root;
        }
    }

    def eval_with_bindings(nd: Expr, bindings: dict[str, CtValue]) -> CtValue {
        saved_demand = self.demand;
        saved_root = self._enter_root(nd);
        try {
            self.demand = True;
            self.push_frame(barrier=True);
            for (k, v) in bindings.items() {
                self.bind(k, v);
            }
            return self._eval_inner(nd);
        } finally {
            self.pop_frame();
            self.demand = saved_demand;
            self._ct_root = saved_root;
        }
    }

    def burn(n: int = 1) {
        self.fuel -= n;
        if self.fuel < 0 {
            self.fuel = CT_FUEL_DEFAULT;
            raise CtError(
                "comptime fuel exhausted (runaway comptime loop or recursion?); "
                "raise [build] comptime_fuel in jac.toml if the work is intended"
            );
        }
    }

    def push_frame(barrier: bool = False) {
        self.frames.append({});
        self.barriers.append(barrier);
    }

    def pop_frame {
        self.frames.pop();
        self.barriers.pop();
    }

    def bind(name: str, v: CtValue) {
        if self.frames {
            self.frames[-1][name] = v;
        }
    }

    def frame_lookup(name: str) -> (CtValue | None) {
        idx = len(self.frames) - 1;
        while idx >= 0 {
            got = self.frames[idx].get(name);
            if got is not None {
                return got;
            }
            if self.barriers[idx] {
                break;
            }
            idx -= 1;
        }
        return None;
    }

    def assign_name(name: str, v: CtValue) {
        idx = len(self.frames) - 1;
        while idx >= 0 {
            if name in self.frames[idx] {
                self.frames[idx][name] = v;
                return;
            }
            if self.barriers[idx] {
                break;
            }
            idx -= 1;
        }
        if self.frames {
            self.frames[-1][name] = v;
        } else {
            raise CtError(f"cannot assign '{name}' outside a comptime function");
        }
    }

    def eval(nd: UniNode) -> CtValue {
        self.burn();
        if isinstance(nd, Expr) {
            cv = nd.ct_value;
            if cv is not None and not cv.is_deferred {
                return cv;
            }
            if not self.frames {
                if cv is not None {
                    raise CtDeferredSignal();
                }
                if id(nd) in self._failed and not self.demand {
                    raise CtNotComptime();
                }
            }
        }
        return self._eval_inner(nd);
    }

    def truthy(nd: UniNode) -> bool {
        v = self.eval(nd);
        if isinstance(v, CtDeferred) {
            raise CtDeferredSignal();
        }
        return ct_truthy(v);
    }

    def _eval_inner(nd: UniNode) -> CtValue {
        if isinstance(nd, SpecialVarRef) {
            return self._eval_special(nd);
        }
        if isinstance(nd, BuiltinType) {
            return self._builtin_type(nd.value);
        }
        if isinstance(nd, Name) {
            return self._eval_name(nd);
        }
        if isinstance(nd, Int) {
            return ct_int_literal(nd.value);
        }
        if isinstance(nd, Float) {
            return mk_float(nd.lit_value);
        }
        if isinstance(nd, Bool) {
            return mk_bool(nd.lit_value);
        }
        if isinstance(nd, String) {
            lit = nd.lit_value;
            if isinstance(lit, bytes) {
                return mk_bytes(lit);
            }
            return mk_str(lit);
        }
        if isinstance(nd, Null) {
            return CT_NONE;
        }
        if isinstance(nd, MultiString) {
            return self._eval_multistring(nd);
        }
        if isinstance(nd, FString) {
            return mk_str(self._eval_fstring(nd));
        }
        if isinstance(nd, AtomUnit) {
            return self.eval(nd.value);
        }
        if isinstance(nd, CfgExpr) {
            return self.eval(nd.expr);
        }
        if isinstance(nd, CastExpr) {
            return self.eval(nd.value);
        }
        if isinstance(nd, BinaryExpr) {
            return self._eval_binary(nd);
        }
        if isinstance(nd, CompareExpr) {
            return self._eval_compare(nd);
        }
        if isinstance(nd, BoolExpr) {
            return self._eval_bool(nd);
        }
        if isinstance(nd, UnaryExpr) {
            return self._eval_unary(nd);
        }
        if isinstance(nd, IfElseExpr) {
            if self.truthy(nd.condition) {
                return self.eval(nd.value);
            }
            return self.eval(nd.else_value);
        }
        if isinstance(nd, ListVal) {
            return mk_list([self.eval(v) for v in nd.values]);
        }
        if isinstance(nd, TupleVal) {
            out: list[CtValue] = [];
            for v in nd.values {
                if isinstance(v, KWPair) {
                    raise CtError("keyword pairs are not values in comptime tuples");
                }
                out.append(self.eval(v));
            }
            return mk_tuple(out);
        }
        if isinstance(nd, SetVal) {
            return mk_set([self.eval(v) for v in (nd.values or [])]);
        }
        if isinstance(nd, DictVal) {
            return self._eval_dict(nd);
        }
        if isinstance(nd, DictCompr) {
            pairs = self._compr_items(nd.compr, 0, None, nd.kv_pair);
            out2 = mk_dict();
            for pair in pairs {
                if isinstance(pair, CtTuple) {
                    dict_set(out2, pair.items[0], pair.items[1]);
                }
            }
            return out2;
        }
        if isinstance(nd, ListCompr) {
            items = self._compr_items(nd.compr, 0, nd.out_expr, None);
            if isinstance(nd, SetCompr) {
                return mk_set(items);
            }
            return mk_list(items);
        }
        if isinstance(nd, AtomTrailer) {
            return self._eval_trailer(nd);
        }
        if isinstance(nd, FuncCall) {
            return self._eval_call(nd);
        }
        if isinstance(nd, KWPair) {
            return self.eval(nd.value);
        }
        raise CtError(f"'{type(nd).__name__}' is not supported in comptime code");
    }

    def _eval_special(nd: SpecialVarRef) -> CtValue {
        got = self.frame_lookup(nd.value);
        if got is not None {
            return got;
        }
        raise CtNotComptime();
    }

    def _builtin_type(name: str) -> CtType {
        return CtType(name=name, module="builtins", typ=self._prefetched_class(name));
    }

    def _prefetched_class(name: str) -> (ClassType | None) {
        pref = self.evaluator.prefetch;
        if pref is None {
            return None;
        }
        if name == "int" {
            return pref.int_class;
        }
        if name == "float" {
            return pref.float_class;
        }
        if name == "str" {
            return pref.str_class;
        }
        if name == "bool" {
            return pref.bool_class;
        }
        if name == "bytes" {
            return pref.bytes_class;
        }
        if name == "list" {
            return pref.list_class;
        }
        if name == "dict" {
            return pref.dict_class;
        }
        if name == "set" {
            return pref.set_class;
        }
        if name == "tuple" {
            return pref.tuple_class;
        }
        if name == "type" {
            return pref.type_class;
        }
        if name == "object" {
            return pref.object_class;
        }
        return None;
    }

    def _eval_multistring(nd: MultiString) -> CtValue {
        parts: list[str] = [];
        is_bytes = False;
        chunks: list[bytes] = [];
        for p in (nd.strings or []) {
            v = self.eval(p);
            if isinstance(v, CtBytes) {
                is_bytes = True;
                chunks.append(v.value);
            } else {
                parts.append(ct_str(v));
            }
        }
        if is_bytes and not parts {
            return mk_bytes(b"".join(chunks));
        }
        return mk_str("".join(parts));
    }

    def _eval_fstring(nd: FString) -> str {
        out = "";
        for p in (nd.parts or []) {
            if isinstance(p, String) {
                out += str(p.lit_value);
            } elif isinstance(p, FormattedValue) {
                v = self.eval(p.format_part);
                if isinstance(v, CtDeferred) {
                    raise CtDeferredSignal();
                }
                conv = p.conversion;
                if conv == ord("r") {
                    v = ct_convert(v, "r");
                } elif conv == ord("s") {
                    v = ct_convert(v, "s");
                } elif conv == ord("a") {
                    v = ct_convert(v, "a");
                }
                spec = "";
                if p.format_spec is not None {
                    spec = ct_str(self.eval(p.format_spec));
                }
                out += ct_format(v, spec);
            } else {
                out += ct_str(self.eval(p));
            }
        }
        return out;
    }

    def _eval_dict(nd: DictVal) -> CtDict {
        out = mk_dict();
        for kv in nd.kv_pairs {
            if kv.key is None {
                spread = self.eval(kv.value);
                if not isinstance(spread, CtDict) {
                    raise CtError("dict spread of a non-dict in comptime code");
                }
                for (i, k) in enumerate(spread.keys) {
                    dict_set(out, k, spread.vals[i]);
                }
                continue;
            }
            key = self.eval(kv.key);
            dict_set(out, key, self.eval(kv.value));
        }
        return out;
    }

    def iterate(coll: CtValue) -> list[CtValue] {
        if isinstance(coll, CtDeferred) {
            raise CtDeferredSignal();
        }
        return ct_iter(coll);
    }

    def _compr_items(
        comprs: list[InnerCompr],
        depth: int,
        out_expr: (Expr | None),
        kv_pair: (KVPair | None)
    ) -> list[CtValue] {
        if depth >= len(comprs) {
            if kv_pair is not None {
                key_expr = kv_pair.key;
                val_expr = kv_pair.value;
                if key_expr is None or val_expr is None {
                    raise CtNotComptime();
                }
                k = self.eval(key_expr);
                return [mk_tuple([k, self.eval(val_expr)])];
            }
            if out_expr is None {
                raise CtNotComptime();
            }
            return [self.eval(out_expr)];
        }
        c: InnerCompr = comprs[depth];
        coll = self.eval(c.collection);
        out: list[CtValue] = [];
        for item in self.iterate(coll) {
            self.burn(2);
            self.push_frame();
            self._bind_target(c.target, item);
            keep = True;
            for cond in (c.conditional or []) {
                if not self.truthy(cond) {
                    keep = False;
                    break;
                }
            }
            if keep {
                out.extend(self._compr_items(comprs, depth + 1, out_expr, kv_pair));
            }
            self.pop_frame();
        }
        return out;
    }

    def _unpack(v: CtValue, count: int) -> list[CtValue] {
        vals = self.iterate(v);
        if len(vals) != count {
            raise CtError("comptime destructuring arity mismatch");
        }
        return vals;
    }

    def _bind_target(tgt: UniNode, v: CtValue) {
        if isinstance(tgt, Name) {
            self.bind(tgt.value, v);
            return;
        }
        if isinstance(tgt, AtomUnit) {
            self._bind_target(tgt.value, v);
            return;
        }
        if isinstance(tgt, (TupleVal, ListVal)) {
            vals = self._unpack(v, len(tgt.values));
            for (i, t) in enumerate(tgt.values) {
                self._bind_target(t, vals[i]);
            }
            return;
        }
        raise CtError(f"'{type(tgt).__name__}' target not supported in comptime code");
    }

    def _assign_target(tgt: UniNode, v: CtValue) {
        if isinstance(tgt, Name) {
            self.assign_name(tgt.value, v);
            return;
        }
        if isinstance(tgt, AtomUnit) {
            self._assign_target(tgt.value, v);
            return;
        }
        if isinstance(tgt, (TupleVal, ListVal)) {
            vals = self._unpack(v, len(tgt.values));
            for (i, t) in enumerate(tgt.values) {
                self._assign_target(t, vals[i]);
            }
            return;
        }
        if isinstance(tgt, AtomTrailer) {
            base = self.eval(tgt.target);
            if tgt.is_attr and isinstance(tgt.right, Name) {
                if isinstance(base, CtRecord) {
                    base.fields[tgt.right.value] = v;
                    return;
                }
                raise CtError("attribute assignment on a non-record in comptime code");
            }
            if isinstance(tgt.right, IndexSlice) and len(tgt.right.slices) == 1 {
                s0 = tgt.right.slices[0];
                if not tgt.right.is_range and s0.start is not None {
                    ct_setitem(base, self.eval(s0.start), v);
                    return;
                }
            }
        }
        raise CtError(
            f"'{type(tgt).__name__}' assign target not supported in comptime code"
        );
    }

    def _tok_name(op: (UniNode | None)) -> str {
        return op.name if isinstance(op, Token) else "";
    }

    def _eval_binary(nd: BinaryExpr) -> CtValue {
        opn = self._tok_name(nd.op);
        l = self.eval(nd.left);
        r = self.eval(nd.right);
        op_text = nd.op.value if isinstance(nd.op, Token) else opn;
        return self._binop_by_name(opn, l, r, display_name=op_text);
    }

    def _cmp(opn: str, l: CtValue, r: CtValue) -> bool {
        sym = CT_CMP_OPS.get(opn);
        if sym is None {
            raise CtError(f"comparison '{opn}' is not supported in comptime code");
        }
        if isinstance(l, CtDeferred) or isinstance(r, CtDeferred) {
            raise CtDeferredSignal();
        }
        return ct_compare(sym, l, r);
    }

    def _eval_compare(nd: CompareExpr) -> CtValue {
        left = self.eval(nd.left);
        for (i, right_nd) in enumerate(nd.rights) {
            right = self.eval(right_nd);
            if not self._cmp(self._tok_name(nd.ops[i]), left, right) {
                return mk_bool(False);
            }
            left = right;
        }
        return mk_bool(True);
    }

    def _eval_bool(nd: BoolExpr) -> CtValue {
        opn = self._tok_name(nd.op);
        r: CtValue = mk_bool(opn == Tok.KW_AND.value);
        want_stop = opn != Tok.KW_AND.value;
        for v in nd.values {
            r = self.eval(v);
            if isinstance(r, CtDeferred) {
                raise CtDeferredSignal();
            }
            if ct_truthy(r) == want_stop {
                return r;
            }
        }
        return r;
    }

    def _eval_unary(nd: UnaryExpr) -> CtValue {
        opn = self._tok_name(nd.op);
        v = self.eval(nd.operand);
        sym = CT_UNARY_OPS.get(opn);
        if sym is not None {
            return ct_unary(sym, v);
        }
        if nd.ownership != OwnershipKind.NONE or opn == Tok.BW_AND.value {
            return v;
        }
        op_text = nd.op.value if isinstance(nd.op, Token) else opn;
        raise CtError(f"unary operator '{op_text}' is not supported in comptime code");
    }

    def _eval_name(nd: Name) -> CtValue {
        name = nd.value;
        got = self.frame_lookup(name);
        if got is not None {
            return got;
        }
        sym: (Symbol | None) = nd.sym;
        if sym is None {
            scope = _scope_of(nd);
            bmod = self.evaluator.builtins_module;
            if scope is not None and bmod is not None {
                sym = lookup_symtab(scope, name, bmod);
            }
        }
        if sym is None {
            builtin = self._builtin_value(name);
            if builtin is not None {
                return builtin;
            }
            if shape_of(name) is not None {
                return CtType(name=name, module="jaclang.runtime.scalars");
            }
            raise CtNotComptime();
        }
        return self._eval_symbol(sym, nd);
    }

    def _builtin_value(name: str) -> (CtValue | None) {
        if name in CT_BUILTIN_TYPES or name in CT_BUILTIN_EXCEPTIONS {
            return self._builtin_type(name);
        }
        if name in CT_BUILTIN_FUNCS {
            return CtBuiltin(name=name);
        }
        return None;
    }

    def _is_stub_module(mod: (Module | None)) -> bool {
        if mod is None {
            return False;
        }
        path = _norm_path(mod.loc.mod_path if mod.loc else "");
        return path.endswith(".pyi");
    }

    def _demand_tree(sym: Symbol) -> Symbol {
        decl = sym.decl;
        home = decl.find_parent_of_type(Module) if decl is not None else None;
        if home is None or not isinstance(home, CatModule) {
            return sym;
        }
        path = _norm_path(home.loc.mod_path if home.loc else "");
        if not path.endswith(".jac") {
            return sym;
        }
        chain: list[str] = [];
        scope = sym.parent_tab;
        while scope is not None and scope is not home {
            chain.append(scope.scope_name);
            scope = scope.parent_scope;
        }
        try {
            real = self.evaluator.program.load_dependency_module(path, need_tree=True);
        } except Exception {
            return sym;
        }
        if real is None or isinstance(real, CatModule) {
            return sym;
        }
        target: UniScopeNode = real;
        for name in reversed(chain) {
            nxt = target.find_scope(name);
            if nxt is None {
                return sym;
            }
            target = nxt;
        }
        found = target.names_in_scope.get(sym.sym_name);
        return found if found is not None else sym;
    }

    def _eval_symbol(sym: Symbol, use: UniNode) -> CtValue {
        skey = ("sym", id(sym));
        if skey in self._active {
            raise CtNotComptime();
        }
        self._active.add(skey);
        try {
            sym = self._resolve_symbol_deep(sym);
            if self.demand {
                sym = self._demand_tree(sym);
            }
            decl = sym.decl;
            node_ = decl.name_of;
            home = node_.find_parent_of_type(Module);
            if isinstance(home, Module) and self._is_stub_module(home) {
                nm = decl.sym_name;
                home_path = _norm_path(home.loc.mod_path if home.loc else "");
                if home is self.evaluator.builtins_module
                    or home_path.endswith("/builtins.pyi") {
                    builtin = self._builtin_value(nm);
                    if builtin is not None {
                        return builtin;
                    }
                }
                if isinstance(node_, Archetype) and shape_of(nm) is not None {
                    return CtType(name=nm, module="jaclang.runtime.scalars");
                }
                raise CtNotComptime();
            }
            if isinstance(node_, Enum) {
                return self._type_of_enum(node_);
            }
            if isinstance(node_, Archetype) {
                return self._type_of_arch(node_);
            }
            if isinstance(node_, Ability) {
                return self._func_of(node_);
            }
            if isinstance(node_, TypeParam) {
                raise CtDeferredSignal();
            }
            if isinstance(node_, ParamVar) {
                if node_.is_comptime {
                    raise CtDeferredSignal();
                }
                raise CtNotComptime();
            }
            if isinstance(node_, ModulePath) {
                return self._module_value(node_);
            }
            if isinstance(node_, Name) {
                par = node_.parent;
                if isinstance(par, ModulePath) {
                    return self._module_value(par);
                }
                if isinstance(par, ModuleItem) {
                    return self._resolve_module_item(par, use);
                }
                if isinstance(par, Assignment) {
                    if par.is_enum_stmt {
                        return self._enum_member_of(par);
                    }
                    if par.is_comptime {
                        return self._eval_binding(par);
                    }
                    if self._is_comptime_glob(par, node_.value) {
                        return self._ct_module_glob(node_.value, use);
                    }
                    raise CtNotComptime();
                }
                if self._is_comptime_loop_target(node_) {
                    raise CtDeferredSignal();
                }
                if node_.value in CT_BUILTIN_FUNCS
                    and sym.parent_tab is not None
                    and sym.parent_tab is self.evaluator.builtins_module {
                    return CtBuiltin(name=node_.value);
                }
                raise CtNotComptime();
            }
            decl_name = decl.sym_name if decl is not None else "";
            if decl_name and decl_name in CT_BUILTIN_FUNCS {
                return CtBuiltin(name=decl_name);
            }
            raise CtNotComptime();
        } finally {
            self._active.discard(skey);
        }
    }

    def _module_value(mp: ModulePath) -> CtModule {
        path = ".".join([p.value for p in (mp.path or [])]);
        if path == "math" {
            return CtModule(name="math");
        }
        raise CtNotComptime();
    }

    def _symbol_via_module_item(item: ModuleItem) -> (Symbol | None) {
        imp = item.find_parent_of_type(Import);
        if imp is None or imp.from_loc is None {
            return None;
        }
        mt = self.evaluator.get_type_of_module(imp.from_loc);
        tab = mt.symbol_table if isinstance(mt, ModuleType) else None;
        if tab is None {
            return None;
        }
        return tab.lookup(item.name.value, deep=False);
    }

    def _resolve_symbol_deep(sym: Symbol) -> Symbol {
        seen: set[int] = set();
        while id(sym) not in seen {
            seen.add(id(sym));
            sym = self.evaluator.resolve_imported_symbols(sym);
            sym = self.evaluator.resolve_to_definition_symbol(sym);
            node_ = sym.decl.name_of;
            if isinstance(node_, Name) and isinstance(node_.parent, ModuleItem) {
                nxt = self._symbol_via_module_item(node_.parent);
                if nxt is None or nxt is sym {
                    return sym;
                }
                sym = nxt;
                continue;
            }
            return sym;
        }
        raise CtNotComptime();
    }

    def _resolve_module_item(item: ModuleItem, use: UniNode) -> CtValue {
        target = self._symbol_via_module_item(item);
        if target is None {
            raise CtNotComptime();
        }
        return self._eval_symbol(target, use);
    }

    def _is_comptime_glob(asn: Assignment, name: str) -> bool {
        if not isinstance(asn.parent, GlobalVars) {
            return False;
        }
        if name not in ("codespace", "target") {
            return False;
        }
        return _is_comptime_module(asn.find_parent_of_type(Module));
    }

    def _ct_module_glob(name: str, use: UniNode) -> CtValue {
        if name == "codespace" {
            ctx = use.codespace();
            return CtEnumMember(
                enum_name="Codespace",
                member=ctx.name,
                value=mk_str(ctx.value),
                module="jaclang.comptime"
            );
        }
        return CtRecord(
            class_name="TargetInfo",
            module="jaclang.comptime",
            fields={"os": mk_str(self.env.os), "arch": mk_str(self.env.arch)}
        );
    }

    def _is_comptime_loop_target(nd: Name) -> bool {
        cur: (UniNode | None) = nd;
        while cur is not None
            and isinstance(cur.parent, (TupleVal, ListVal, AtomUnit)) {
            cur = cur.parent;
        }
        par = cur.parent if cur is not None else None;
        return isinstance(par, InForStmt) and par.is_comptime and par.target is cur;
    }

    def _eval_binding(asn: Assignment) -> CtValue {
        self._note_producer(asn.find_parent_of_type(Module));
        if asn.value is None {
            raise CtError("comptime binding has no initializer");
        }
        cv = asn.value.ct_value;
        if cv is not None {
            if cv.is_deferred {
                raise CtDeferredSignal();
            }
            self._stamp_home(cv, asn);
            return cv;
        }
        key = ("node", id(asn));
        if key in self._active {
            raise CtError("comptime binding depends on itself");
        }
        self._active.add(key);
        saved_frames = self.frames;
        saved_barriers = self.barriers;
        saved_demand = self.demand;
        self.frames = [];
        self.barriers = [];
        self.demand = True;
        try {
            v = self._eval_inner(asn.value);
        } finally {
            self._active.discard(key);
            self.frames = saved_frames;
            self.barriers = saved_barriers;
            self.demand = saved_demand;
        }
        self._stamp_home(v, asn);
        asn.value.ct_value = v;
        return v;
    }

    def _stamp_home(v: CtValue, asn: Assignment) {
        if isinstance(v, CtRecord) and not v.home {
            v.home = _mod_dotted(asn.find_parent_of_type(Module));
        }
    }

    def _type_of_arch(nd: Archetype) -> CtType {
        return CtType(
            name=nd.name.value,
            module=_mod_dotted(nd.find_parent_of_type(Module)),
            typ=self.evaluator.get_type_of_class(nd)
        );
    }

    def _type_of_enum(nd: Enum) -> CtType {
        return CtType(
            name=nd.name.value,
            module=_mod_dotted(nd.find_parent_of_type(Module)),
            typ=self.evaluator.get_type_of_enum(nd)
        );
    }

    def _func_of(nd: Ability) -> CtFunc {
        owner = nd.method_owner;
        qual = nd.name_ref.sym_name if nd.name_ref else "unnamed";
        if owner is not None {
            qual = f"{owner.name.value}.{qual}";
        }
        return CtFunc(
            qualname=qual,
            module=_mod_dotted(nd.find_parent_of_type(Module)),
            ability=nd
        );
    }

    def _enum_members(nd: Enum) -> list[CtEnumMember] {
        self._note_producer(nd.find_parent_of_type(Module), body=True);
        key = id(nd);
        if key in self._enum_cache {
            return self._enum_cache[key];
        }
        out: list[CtEnumMember] = [];
        mod = _mod_dotted(nd.find_parent_of_type(Module));
        enum_type = self.evaluator.get_type_of_enum(nd);
        running: (CtInt | None) = None;
        for stmt in _impl_body(nd) {
            if not (isinstance(stmt, Assignment) and stmt.is_enum_stmt) {
                continue;
            }
            tgt = stmt.target[0] if stmt.target else None;
            if not isinstance(tgt, Name) {
                continue;
            }
            val: CtValue = CT_NONE;
            if stmt.value is not None {
                saved_frames = self.frames;
                saved_barriers = self.barriers;
                self.frames = [];
                self.barriers = [];
                try {
                    val = self._eval_inner(stmt.value);
                } finally {
                    self.frames = saved_frames;
                    self.barriers = saved_barriers;
                }
            } elif running is None {
                val = CtInt(small=1);
            } else {
                val = int_add(running, CtInt(small=1));
            }
            if isinstance(val, CtInt) {
                if running is None or int_cmp(val, running) > 0 {
                    running = val;
                }
            }
            out.append(
                CtEnumMember(
                    enum_name=nd.name.value,
                    member=tgt.value,
                    value=val,
                    module=mod,
                    enum_type=enum_type
                )
            );
        }
        self._enum_cache[key] = out;
        return out;
    }

    def _enum_member_of(asn: Assignment) -> CtEnumMember {
        enum_nd = asn.find_parent_of_type(Enum);
        if enum_nd is None {
            impl_nd = asn.find_parent_of_type(ImplDef);
            if impl_nd is not None and isinstance(impl_nd.decl_link, Enum) {
                enum_nd = impl_nd.decl_link;
            }
        }
        if enum_nd is None {
            raise CtNotComptime();
        }
        tgt = asn.target[0] if asn.target else None;
        want = tgt.value if isinstance(tgt, Name) else "";
        for m in self._enum_members(enum_nd) {
            if m.member == want {
                return m;
            }
        }
        raise CtNotComptime();
    }

    def _class_type_of(v: CtValue) -> (ClassType | None) {
        if isinstance(v, CtType) and isinstance(v.typ, ClassType) {
            return v.typ;
        }
        if isinstance(v, CtRecord) {
            return v.class_type;
        }
        return None;
    }

    def _arch_node_of(ct: (ClassType | None)) -> (Archetype | Enum | None) {
        if ct is None {
            return None;
        }
        tab = ct.shared.symbol_table;
        if isinstance(tab, (Archetype, Enum)) {
            return tab;
        }
        return None;
    }

    def ct_type_of_class(t: (TypeBase | None)) -> CtType {
        if isinstance(t, ClassType) {
            node_ = self._arch_node_of(t);
            mod = "builtins";
            if node_ is not None {
                mod = _mod_dotted(node_.find_parent_of_type(Module));
            } elif not t.is_builtin() {
                mod = "";
            }
            return CtType(
                name=t.shared.class_name, module=mod, typ=t, ct_args=t.private.ct_args
            );
        }
        raise CtNotComptime();
    }

    def ct_type_of_value(v: CtValue) -> CtType {
        if isinstance(v, CtRecord) {
            return CtType(
                name=v.class_name, module=v.module, typ=v.class_type, ct_args=v.ct_args
            );
        }
        if isinstance(v, CtEnumMember) {
            return CtType(name=v.enum_name, module=v.module, typ=v.enum_type);
        }
        if isinstance(v, CtType) {
            return self._builtin_type("type");
        }
        if isinstance(v, CtNone) {
            return CtType(name="NoneType", module="builtins");
        }
        if isinstance(v, CtExc) {
            return self._builtin_type(v.kind);
        }
        if isinstance(
            v,
            (
                CtBool,
                CtInt,
                CtFloat,
                CtStr,
                CtBytes,
                CtList,
                CtDict,
                CtTuple,
                CtSet,
                CtRange
            )
        ) {
            return self._builtin_type(ct_type_name(v));
        }
        raise CtError(f"no comptime type for {ct_repr(v)}");
    }

    def _builtin_isinstance(v: CtValue, name: str) -> bool {
        if name == "object" {
            return True;
        }
        if name == "int" {
            return isinstance(v, CtInt);
        }
        if name == "bool" {
            return isinstance(v, CtBool);
        }
        if name == "float" {
            return isinstance(v, CtFloat);
        }
        if name == "str" {
            return isinstance(v, CtStr);
        }
        if name == "bytes" {
            return isinstance(v, CtBytes);
        }
        if name == "list" {
            return isinstance(v, CtList);
        }
        if name == "dict" {
            return isinstance(v, CtDict);
        }
        if name == "tuple" {
            return isinstance(v, CtTuple);
        }
        if name == "set" {
            return isinstance(v, CtSet) and not v.frozen;
        }
        if name == "frozenset" {
            return isinstance(v, CtSet) and v.frozen;
        }
        if name == "type" {
            return isinstance(v, CtType);
        }
        if name in CT_BUILTIN_EXCEPTIONS {
            return isinstance(v, CtExc) and ct_exc_is(v.kind, name);
        }
        return False;
    }

    def ct_isinstance(v: CtValue, t: CtValue) -> bool {
        if isinstance(v, CtDeferred) or isinstance(t, CtDeferred) {
            raise CtDeferredSignal();
        }
        if isinstance(t, CtTuple) {
            for alt in t.items {
                if self.ct_isinstance(v, alt) {
                    return True;
                }
            }
            return False;
        }
        if isinstance(t, CtType) {
            if t.module == "builtins"
                and (t.name in CT_BUILTIN_TYPES or t.name in CT_BUILTIN_EXCEPTIONS) {
                return self._builtin_isinstance(v, t.name);
            }
            if isinstance(v, (CtRecord, CtEnumMember)) {
                return self._is_subtype(self.ct_type_of_value(v), t);
            }
            return False;
        }
        raise CtError("isinstance needs a type in comptime code");
    }

    def _is_subtype(t: CtType, u: CtType) -> bool {
        if ct_eq(t, u) {
            return True;
        }
        ct = self._class_type_of(t);
        if ct is None {
            return False;
        }
        for base in ct.shared.mro {
            if base.shared.class_name == u.name {
                return True;
            }
        }
        return False;
    }

    def _has_vars_of(ct: ClassType) -> list[HasVar] {
        out: list[HasVar] = [];
        seen: dict[str, int] = {};
        for cls in ct.shared.mro[::-1] {
            tab = cls.shared.symbol_table;
            if not isinstance(tab, Archetype) {
                continue;
            }
            for hv in tab.get_has_vars() {
                nm = hv.name.value;
                if nm in seen {
                    out[seen[nm]] = hv;
                } else {
                    seen[nm] = len(out);
                    out.append(hv);
                }
            }
        }
        return out;
    }

    def _field_type_of(hv: HasVar) -> (CtType | None) {
        if hv.type_tag is None or hv.type_tag.tag is None {
            return None;
        }
        try {
            return self.ct_type_of_class(
                self.evaluator._convert_to_instance(
                    self.evaluator.get_type_of_expression(hv.type_tag.tag)
                )
            );
        } except Exception {
            return None;
        }
    }

    def _field_info(hv: HasVar, sym: (Symbol | None)) -> CtRecord {
        ftype = self._field_type_of(hv);
        dflt: CtValue = CT_NONE;
        hval = hv.value;
        has_dflt = hval is not None;
        if hval is not None {
            try {
                dflt = self.eval(hval);
            } except Exception {
                dflt = CT_NONE;
            }
        }
        sem_text = hv.semstr or (sym.semstr if sym is not None else "");
        return CtRecord(
            class_name="FieldInfo",
            module="jaclang.comptime",
            fields={
                "name": mk_str(hv.name.value),
                "type": ftype if ftype is not None else CT_NONE,
                "has_default": mk_bool(has_dflt),
                "default": dflt,
                "semstr": mk_str(sem_text)
            }
        );
    }

    def intrinsic_fields(t: CtValue) -> CtList {
        if isinstance(t, CtDeferred) {
            raise CtDeferredSignal();
        }
        ct = self._class_type_of(t);
        if ct is None {
            raise CtError("fields() needs an archetype type");
        }
        out: list[CtValue] = [];
        for hv in self._has_vars_of(ct) {
            if hv.accessors {
                continue;
            }
            out.append(self._field_info(hv, hv.sym));
        }
        return mk_list(out);
    }

    def intrinsic_members(t: CtValue) -> CtList {
        if isinstance(t, CtDeferred) {
            raise CtDeferredSignal();
        }
        node_ = self._arch_node_of(self._class_type_of(t));
        if not isinstance(node_, Enum) {
            raise CtError("members() needs an enum type");
        }
        items: list[CtValue] = [];
        for m in self._enum_members(node_) {
            items.append(m);
        }
        return mk_list(items);
    }

    def _semstr_of_name(nd: Name) -> str {
        return nd.semstr or (nd.sym.semstr if nd.sym else "");
    }

    def intrinsic_semstr(t: CtValue, field: str = "") -> CtValue {
        if isinstance(t, CtEnumMember) {
            node_ = self._arch_node_of(t.enum_type);
            if node_ is not None {
                for stmt in _impl_body(node_) {
                    if isinstance(stmt, Assignment) and stmt.is_enum_stmt {
                        tgt = stmt.target[0] if stmt.target else None;
                        if isinstance(tgt, Name) and tgt.value == t.member {
                            return mk_str(self._semstr_of_name(tgt));
                        }
                    }
                }
            }
            return CT_NONE;
        }
        ct = self._class_type_of(t);
        node_ = self._arch_node_of(ct);
        if node_ is None {
            raise CtError("semstr() needs an archetype, enum, or enum member");
        }
        if not field {
            return mk_str(
                node_.semstr or (node_.name.sym.semstr if node_.name.sym else "")
            );
        }
        if isinstance(ct, ClassType) {
            for hv in self._has_vars_of(ct) {
                if hv.name.value == field {
                    return mk_str(hv.semstr or (hv.sym.semstr if hv.sym else ""));
                }
            }
        }
        return CT_NONE;
    }

    def _str_arg(v: CtValue, what: str) -> str {
        if isinstance(v, CtStr) {
            return v.value;
        }
        raise CtError(f"{what} needs a str argument");
    }

    def _intrinsic(
        name: str, nd: FuncCall, args: list[CtValue], kwargs: dict[str, CtValue]
    ) -> CtValue {
        if name == "set_fuel" {
            fuel_arg = as_ct_int(args[0]) if len(args) == 1 else None;
            if fuel_arg is None or isinstance(args[0], CtBool) {
                raise CtError("set_fuel() takes one int argument");
            }
            if not fuel_arg.mag {
                self.fuel = max(self.fuel, fuel_arg.small);
            } elif not fuel_arg.neg {
                self.fuel = max(self.fuel, 4611686018427387903);
            }
            return CT_NONE;
        }
        if name in ("embed_file", "embed_bytes") {
            if len(args) != 1 or not isinstance(args[0], CtStr) {
                raise CtError(f"{name}() takes one str path argument");
            }
            return self._embed(nd, args[0].value, name == "embed_bytes");
        }
        if name in ("sizeof", "alignof") {
            if len(args) != 1 {
                raise CtError(f"{name}() takes one type argument");
            }
            (size, align) = self._size_align(args[0]);
            return mk_int(size if name == "sizeof" else align);
        }
        if name == "typeof" {
            if len(args) != 1 {
                raise CtError("typeof() takes one argument");
            }
            v = args[0];
            if isinstance(v, CtDeferred) {
                raise CtDeferredSignal();
            }
            return self.ct_type_of_value(v);
        }
        if not args {
            raise CtError(f"{name}() needs an argument");
        }
        if name == "fields" {
            return self.intrinsic_fields(args[0]);
        }
        if name == "members" {
            return self.intrinsic_members(args[0]);
        }
        if name == "has_field" {
            ct = self._class_type_of(args[0]);
            if ct is None {
                raise CtError("has_field() needs an archetype type");
            }
            want = self._str_arg(args[1], "has_field()") if len(args) > 1 else "";
            for hv in self._has_vars_of(ct) {
                if hv.name.value == want {
                    return mk_bool(True);
                }
            }
            return mk_bool(False);
        }
        if name == "get_field" {
            holder = args[0];
            if isinstance(holder, CtRecord) {
                fname = self._str_arg(args[1], "get_field()") if len(args) > 1 else "";
                if fname in holder.fields {
                    return holder.fields[fname];
                }
                raise CtError(f"{holder.class_name} has no field '{fname}'");
            }
            raise CtDeferredSignal();
        }
        if name == "set_field" {
            holder = args[0];
            if isinstance(holder, CtRecord) {
                if len(args) < 3 {
                    raise CtError(
                        "set_field() takes a target, a field name, and a value"
                    );
                }
                holder.fields[self._str_arg(args[1], "set_field()")] = args[2];
                return CT_NONE;
            }
            raise CtDeferredSignal();
        }
        if name == "semstr" {
            fld_v: CtValue = kwargs.get(
                "field", args[1] if len(args) > 1 else mk_str("")
            );
            return self.intrinsic_semstr(args[0], self._str_arg(fld_v, "semstr()"));
        }
        if name == "name" {
            v = args[0];
            if isinstance(v, CtType) {
                return mk_str(v.name);
            }
            if isinstance(v, CtEnumMember) {
                return mk_str(v.member);
            }
            if isinstance(v, CtFunc) {
                return mk_str(v.qualname.split(".")[-1]);
            }
            raise CtError("name() needs a type, enum member, or function");
        }
        if name == "is_subtype" {
            if len(args) == 2
                and isinstance(args[0], CtType)
                and isinstance(args[1], CtType) {
                return mk_bool(self._is_subtype(args[0], args[1]));
            }
            raise CtError("is_subtype() needs two types");
        }
        if name == "module_of" {
            v = args[0];
            if isinstance(v, CtRecord) and v.home {
                return mk_str(v.home);
            }
            first: (UniNode | None) = nd.params[0] if nd.params else None;
            bound = isinstance(first, Name)
                and self.frame_lookup(first.value) is not None;
            home = self._defining_module_of(first)
                if first is not None and not bound
                else None;
            if home {
                return mk_str(home);
            }
            if isinstance(v, CtType) {
                return mk_str(v.module);
            }
            if isinstance(v, CtFunc) {
                return mk_str(v.module);
            }
            if isinstance(v, CtRecord) {
                return mk_str(v.module);
            }
            if isinstance(v, CtEnumMember) {
                return mk_str(v.module);
            }
            raise CtError("module_of() needs a type, function, enum member, or record");
        }
        raise CtError(f"unknown comptime intrinsic '{name}'");
    }

    def _intrinsic_name_of(tgt: UniNode) -> (str | None) {
        if not isinstance(tgt, Name) or isinstance(tgt, SpecialVarRef) {
            return None;
        }
        sym: (Symbol | None) = tgt.sym;
        if sym is None {
            scope = _scope_of(tgt);
            bmod = self.evaluator.builtins_module;
            if scope is not None and bmod is not None {
                sym = lookup_symtab(scope, tgt.value, bmod);
            }
        }
        if sym is None {
            return None;
        }
        sym = self._resolve_symbol_deep(sym);
        decl = sym.decl;
        if decl is None {
            return None;
        }
        if (
            sym.sym_name in CT_INTRINSICS
            and _is_comptime_module(decl.find_parent_of_type(Module))
        ) {
            return sym.sym_name;
        }
        node_ = decl.name_of;
        if (
            isinstance(node_, Ability)
            and node_.name_ref is not None
            and node_.name_ref.sym_name in CT_INTRINSICS
            and _is_comptime_module(node_.find_parent_of_type(Module))
        ) {
            return node_.name_ref.sym_name;
        }
        return None;
    }

    def _defining_module_of(nd: UniNode) -> (str | None) {
        if not isinstance(nd, Name) or isinstance(nd, SpecialVarRef) {
            return None;
        }
        sym: (Symbol | None) = nd.sym;
        if sym is None {
            scope = _scope_of(nd);
            bmod = self.evaluator.builtins_module;
            if scope is not None and bmod is not None {
                sym = lookup_symtab(scope, nd.value, bmod);
            }
        }
        if sym is None {
            return None;
        }
        sym = self._resolve_symbol_deep(sym);
        return _mod_dotted(sym.decl.find_parent_of_type(Module));
    }

    def _call_args(nd: FuncCall) -> tuple[list[CtValue], dict[str, CtValue]] {
        args: list[CtValue] = [];
        kwargs: dict[str, CtValue] = {};
        for p in (nd.params or []) {
            if isinstance(p, KWPair) {
                if p.key is None {
                    spread = self.eval(p.value);
                    if not isinstance(spread, CtDict) {
                        raise CtError("** spread of a non-dict in comptime code");
                    }
                    for (i, k) in enumerate(spread.keys) {
                        if not isinstance(k, CtStr) {
                            raise ct_exc("TypeError", "keywords must be strings");
                        }
                        kwargs[k.value] = spread.vals[i];
                    }
                } else {
                    kwargs[p.key.sym_name] = self.eval(p.value);
                }
            } elif isinstance(p, UnaryExpr)
                and self._tok_name(p.op) == Tok.STAR_MUL.value {
                args.extend(self.iterate(self.eval(p.operand)));
            } else {
                args.append(self.eval(p));
            }
        }
        return (args, kwargs);
    }

    def _eval_call(nd: FuncCall) -> CtValue {
        if nd.genai_call is not None {
            raise CtError("'by llm' calls cannot run at compile time");
        }
        intr = self._intrinsic_name_of(nd.target);
        (args, kwargs) = self._call_args(nd);
        if intr is not None {
            self.burn(5);
            return self._intrinsic(intr, nd, args, kwargs);
        }
        tgt = nd.target;
        if isinstance(tgt, AtomTrailer)
            and tgt.is_attr
            and isinstance(tgt.right, Name) {
            recv = self.eval(tgt.target);
            if tgt.is_null_ok and isinstance(recv, CtNone) {
                return CT_NONE;
            }
            return self._call_attr(recv, tgt.right.value, args, kwargs);
        }
        callee = self.eval(tgt);
        return self.call_value(callee, args, kwargs);
    }

    def _class_binding(ct: (ClassType | None), name: str) -> (Assignment | None) {
        if ct is None {
            return None;
        }
        for cls in ct.shared.mro {
            tab = cls.shared.symbol_table;
            if not isinstance(tab, Archetype) {
                continue;
            }
            for item in _impl_body(tab) {
                if not (isinstance(item, GlobalVars) and item.is_frozen) {
                    continue;
                }
                for asn in item.assignments {
                    tgt = asn.target[0] if asn.target else None;
                    if isinstance(tgt, Name) and tgt.value == name {
                        return asn;
                    }
                }
            }
        }
        return None;
    }

    def _ct_subscript(base: CtType, head: (Expr | None)) -> CtType {
        vals: list[Expr | KWPair] = [];
        if isinstance(head, TupleVal) {
            vals = `list(head.values);
        } elif head is not None {
            vals = [head];
        }
        node_ = self._arch_node_of(self._class_type_of(base));
        ct_args: dict[str, CtValue] = `dict(base.ct_args or {});
        if isinstance(node_, Archetype) {
            for (i, tp) in enumerate(node_.type_params or []) {
                if tp.is_comptime and i < len(vals) {
                    ct_args[tp.name.value] = self.eval(vals[i]);
                }
            }
        }
        return CtType(
            name=base.name, module=base.module, typ=base.typ, ct_args=ct_args or None
        );
    }

    def _find_method(ct: (ClassType | None), name: str) -> (Ability | None) {
        if ct is None {
            return None;
        }
        for cls in ct.shared.mro {
            tab = cls.shared.symbol_table;
            if not isinstance(tab, (Archetype, Enum)) {
                continue;
            }
            for m in _impl_body(tab) {
                if isinstance(m, Ability)
                    and m.name_ref
                    and m.name_ref.sym_name == name {
                    return m;
                }
            }
        }
        return None;
    }

    def _call_attr(
        recv: CtValue, attr: str, args: list[CtValue], kwargs: dict[str, CtValue]
    ) -> CtValue {
        if isinstance(recv, CtDeferred) {
            raise CtDeferredSignal();
        }
        if isinstance(recv, CtType) {
            m = self._find_method(self._class_type_of(recv), attr);
            if m is None {
                if recv.module == "builtins" and not attr.startswith("_") {
                    return self.call_value(ct_type_attr(recv.name, attr), args, kwargs);
                }
                raise CtError(f"{recv.name} has no method '{attr}'");
            }
            if m.is_static or m.is_comptime or m.is_classmethod {
                return self.call_ability(m, args, kwargs, self_val=recv);
            }
            raise CtError(
                f"{recv.name}.{attr} is an instance method; call it on an instance"
            );
        }
        if isinstance(recv, CtRecord) {
            m = self._find_method(recv.class_type, attr);
            if m is None {
                raise CtError(f"{recv.class_name} has no method '{attr}'");
            }
            if m.is_static {
                return self.call_ability(m, args, kwargs);
            }
            return self.call_ability(m, args, kwargs, self_val=recv);
        }
        if isinstance(recv, (CtEnumMember, CtFunc)) {
            raise CtError(
                f"'{attr}' is not callable on {ct_repr(recv)} in comptime code"
            );
        }
        if attr.startswith("_") {
            raise CtError(f"access to '{attr}' is not allowed in comptime code");
        }
        if isinstance(recv, CtModule) {
            return self.call_value(ct_value_attr(recv, attr), args, kwargs);
        }
        self.burn(10);
        return ct_call_method(self, recv, attr, args, kwargs);
    }

    def call_value(
        callee: CtValue, args: list[CtValue], kwargs: dict[str, CtValue]
    ) -> CtValue {
        if isinstance(callee, CtDeferred) {
            raise CtDeferredSignal();
        }
        if isinstance(callee, CtFunc) {
            if callee.ability is None {
                raise CtError(f"{callee.qualname} has no body the compiler can run");
            }
            return self.call_ability(callee.ability, args, kwargs);
        }
        if isinstance(callee, CtBound) {
            return self.call_ability(
                callee.ability, args, kwargs, self_val=callee.self_val
            );
        }
        if isinstance(callee, CtType) {
            return self._construct(callee, args, kwargs);
        }
        if isinstance(callee, CtBuiltin) {
            self.burn(10);
            return ct_call_builtin(self, callee.name, args, kwargs);
        }
        if isinstance(callee, CtMethod) {
            self.burn(10);
            return ct_call_method_value(self, callee, args, kwargs);
        }
        if isinstance(callee, (CtRecord, CtEnumMember)) {
            raise CtError(f"{ct_repr(callee)} is not callable");
        }
        raise CtError(f"{ct_repr(callee)} is not callable in comptime code");
    }

    def _construct(
        t: CtType, args: list[CtValue], kwargs: dict[str, CtValue]
    ) -> CtValue {
        if t.module == "builtins" {
            if t.name == "type" {
                if len(args) != 1 or kwargs {
                    raise CtError("type() takes exactly one argument in comptime code");
                }
                return self.ct_type_of_value(args[0]);
            }
            if t.name in CT_BUILTIN_TYPES or t.name in CT_BUILTIN_EXCEPTIONS {
                self.burn(5);
                return ct_construct_builtin(t.name, args, kwargs);
            }
            raise CtError(f"cannot construct builtin '{t.name}' at compile time");
        }
        ct = self._class_type_of(t);
        node_ = self._arch_node_of(ct);
        if isinstance(node_, Enum) {
            if len(args) != 1 or kwargs {
                raise CtError(f"{t.name}(...) takes exactly one value");
            }
            for m in self._enum_members(node_) {
                if ct_eq(m.value, args[0]) {
                    return m;
                }
            }
            raise CtError(f"{ct_repr(args[0])} is not a value of {t.name}");
        }
        if ct is None or node_ is None {
            raise CtError(f"cannot construct '{t.name}' at compile time");
        }
        hvs = [
            hv
            for hv in self._has_vars_of(ct)
            if not hv.accessors
        ];
        self._note_producer(node_.find_parent_of_type(Module), body=True);
        fields: dict[str, CtValue] = {};
        init_ab = self._user_method(ct, "init") or self._user_method(ct, "__init__");
        if init_ab is not None {
            for hv in hvs {
                if hv.value is not None {
                    fields[hv.name.value] = self.eval(hv.value);
                }
            }
            rec = CtRecord(
                class_name=t.name,
                module=t.module,
                fields=fields,
                class_type=ct,
                ct_args=t.ct_args
            );
            self.call_ability(init_ab, args, kwargs, self_val=rec);
            return rec;
        }
        remaining: dict[str, CtValue] = `dict(kwargs);
        ai = 0;
        for hv in hvs {
            nm = hv.name.value;
            if ai < len(args) {
                fields[nm] = args[ai];
                ai += 1;
            } elif nm in remaining {
                fields[nm] = remaining.pop(nm);
            } elif hv.value is not None {
                fields[nm] = self.eval(hv.value);
            } elif hv.defer {
                fields[nm] = CT_NONE;
            } else {
                raise CtError(f"{t.name}() is missing field '{nm}'");
            }
        }
        if ai < len(args) {
            raise CtError(
                f"{t.name}() got {len(args) - ai} extra positional argument(s)"
            );
        }
        if remaining {
            raise CtError(f"{t.name}() got unexpected field(s) {sorted(remaining)}");
        }
        rec = CtRecord(
            class_name=t.name,
            module=t.module,
            fields=fields,
            class_type=ct,
            ct_args=t.ct_args
        );
        post_ab = self._user_method(ct, "postinit")
            or self._user_method(ct, "__post_init__");
        if post_ab is not None {
            self.call_ability(post_ab, [], {}, self_val=rec);
        }
        return rec;
    }

    def _user_method(ct: ClassType, name: str) -> (Ability | None) {
        m = self._find_method(ct, name);
        if m is None or self._is_stub_module(m.find_parent_of_type(Module)) {
            return None;
        }
        return m;
    }

    def call_ability(
        ability: Ability,
        args: list[CtValue],
        kwargs: dict[str, CtValue],
        self_val: (CtValue | None) = None
    ) -> CtValue {
        self.burn(20);
        if not self.frames and not self.demand {
            raise CtNotComptime();
        }
        name = ability.name_ref.sym_name if ability.name_ref else "unnamed";
        if ability.is_abstract {
            raise CtError(f"{name} is abstract");
        }
        if isinstance(ability.body, Expr)
            or (
                isinstance(ability.body, ImplDef)
                and isinstance(ability.body.body, Expr)
            ) {
            raise CtError(f"{name} is a 'by' ability and cannot run at compile time");
        }
        body = _impl_body(ability);
        if not body and ability.body is None {
            raise CtError(f"{name} has no body");
        }
        if not isinstance(ability.signature, FuncSignature) {
            raise CtError(f"{name} is an event ability and cannot run at compile time");
        }
        if len(self.call_stack) > 200 {
            raise CtError("comptime call stack exceeded 200 frames");
        }
        params = ability.signature.get_parameters();
        kw: dict[str, CtValue] = `dict(kwargs);
        self._note_producer(ability.find_parent_of_type(Module), body=True);
        self.push_frame(barrier=True);
        self.call_stack.append(name);
        try {
            self_type = self._self_type_of(self_val, ability);
            if self_type is not None {
                self.bind("Self", self_type);
                for (ck, cvv) in (self_type.ct_args or {}).items() {
                    self.bind(ck, cvv);
                }
            }
            if isinstance(self_val, CtRecord) and not ability.is_static {
                self.bind("self", self_val);
            }
            ai = 0;
            first = True;
            for p in params {
                pname = p.name.value;
                if first
                    and (isinstance(p.name, SpecialVarRef) or pname in ("self", "cls"))
                    and self_val is not None {
                    self.bind(pname, self_val);
                    first = False;
                    continue;
                }
                first = False;
                if p.is_vararg {
                    self.bind(pname, mk_tuple(args[ai:]));
                    ai = len(args);
                    continue;
                }
                if p.is_kwargs {
                    spread = mk_dict();
                    for (kk, kv) in kw.items() {
                        dict_set(spread, mk_str(kk), kv);
                    }
                    self.bind(pname, spread);
                    kw = {};
                    continue;
                }
                if ai < len(args) {
                    self.bind(pname, args[ai]);
                    ai += 1;
                } elif pname in kw {
                    self.bind(pname, kw.pop(pname));
                } elif p.value is not None {
                    self.bind(pname, self.eval(p.value));
                } else {
                    raise CtError(f"{name}() is missing argument '{pname}'");
                }
            }
            if ai < len(args) {
                raise CtError(
                    f"{name}() got {len(args) - ai} extra positional argument(s)"
                );
            }
            if kw {
                raise CtError(f"{name}() got unexpected keyword(s) {sorted(kw)}");
            }
            self._ret = CT_NONE;
            self._exec_block(body);
            out = self._ret;
            self._ret = CT_NONE;
            return out;
        } finally {
            self.call_stack.pop();
            self.pop_frame();
        }
    }

    def _embed(nd: FuncCall, rel: str, as_bytes: bool) -> CtValue {
        mod = nd.find_parent_of_type(Module);
        base = os.path.dirname(mod.loc.mod_path) if mod is not None and mod.loc else "";
        path = rel if os.path.isabs(rel) else os.path.join(base, rel);
        path = os.path.normpath(path);
        try {
            data = ct_read_host_file(path);
        } except OSError as e {
            raise CtError(f"embed_file: cannot read {path}: {e}");
        }
        if mod is not None and path not in mod.ct_file_deps {
            mod.ct_file_deps.append(path);
        }
        self._note_ct_path(path);
        self.burn(len(data) // 64 + 1);
        if as_bytes {
            return mk_bytes(data);
        }
        try {
            return mk_str(data.decode("utf-8"));
        } except UnicodeDecodeError {
            raise CtError(f"embed_file: {path} is not UTF-8 text; use embed_bytes");
        }
    }

    def _scalar_size_align(t: CtValue) -> (tuple[int, int] | None) {
        name = t.name if isinstance(t, CtType) else ct_str(t);
        if name == "bool" {
            return (1, 1, );
        }
        if name in ("int", "float") {
            return (8, 8, );
        }
        shape = shape_of(name);
        if shape is not None {
            n = shape.size_bytes();
            return (n, n, );
        }
        return None;
    }

    def _size_align(t: CtValue) -> tuple[int, int] {
        if isinstance(t, CtDeferred) {
            raise CtDeferredSignal();
        }
        scalar = self._scalar_size_align(t);
        if scalar is not None {
            return scalar;
        }
        ct = self._class_type_of(t);
        node_ = self._arch_node_of(ct) if ct is not None else None;
        if ct is None or not isinstance(node_, Archetype) {
            return (8, 8, );
        }
        off = 0;
        top = 1;
        for hv in self._has_vars_of(ct) {
            if hv.accessors {
                continue;
            }
            sz = 8;
            al = 8;
            ftype = self._field_type_of(hv);
            if ftype is not None {
                inner = self._scalar_size_align(ftype);
                if inner is not None {
                    sz = inner[0];
                    al = inner[1];
                }
            }
            off = (off + al - 1) // al * al + sz;
            if al > top {
                top = al;
            }
        }
        return ((off + top - 1) // top * top, top, );
    }

    def _self_type_of(self_val: (CtValue | None), ability: Ability) -> (CtType | None) {
        if isinstance(self_val, CtType) {
            return self_val;
        }
        if isinstance(self_val, CtRecord) {
            return self.ct_type_of_value(self_val);
        }
        owner = ability.find_parent_of_type(Archetype);
        if owner is not None {
            return self._type_of_arch(owner);
        }
        return None;
    }

    def _exec_block(stmts: list[UniNode]) -> int {
        for s in stmts {
            sig = self._exec_stmt(s);
            if sig != 0 {
                return sig;
            }
        }
        return 0;
    }

    def _for_item(coll: CtValue, items: list[CtValue], idx: int) -> (CtValue | None) {
        if isinstance(coll, CtList) {
            return coll.items[idx] if idx < len(coll.items) else None;
        }
        if isinstance(coll, CtRange) {
            return mk_int(coll.start + idx * coll.step)
                if idx < range_len(coll)
                else None;
        }
        return items[idx] if idx < len(items) else None;
    }

    def _exec_for(nd: InForStmt) -> int {
        coll = self.eval(nd.collection);
        if isinstance(coll, CtDeferred) {
            raise CtDeferredSignal();
        }
        broke = False;
        idx = 0;
        items: list[CtValue] = [];
        if not isinstance(coll, (CtList, CtRange)) {
            items = self.iterate(coll);
        }
        while True {
            item = self._for_item(coll, items, idx);
            if item is None {
                break;
            }
            idx += 1;
            self.burn(2);
            self.push_frame();
            try {
                self._bind_target(nd.target, item);
                sig = self._exec_block(`list(nd.body));
            } finally {
                self.pop_frame();
            }
            if sig == 1 {
                return 1;
            }
            if sig == 2 {
                broke = True;
                break;
            }
        }
        if not broke and isinstance(nd.else_body, ElseStmt) {
            return self._exec_stmt(nd.else_body);
        }
        return 0;
    }

    def _exec_stmt(nd: UniNode) -> int {
        self.burn();
        if isinstance(nd, Semi) {
            return 0;
        }
        if isinstance(nd, Assignment) {
            return self._exec_assignment(nd);
        }
        if isinstance(nd, ExprStmt) {
            self.eval(nd.expr);
            return 0;
        }
        if isinstance(nd, IfStmt) {
            if self.truthy(nd.condition) {
                return self._exec_block(`list(nd.body));
            }
            if nd.else_body is not None {
                return self._exec_stmt(nd.else_body);
            }
            return 0;
        }
        if isinstance(nd, ElseStmt) {
            return self._exec_block(`list(nd.body));
        }
        if isinstance(nd, WhileStmt) {
            while self.truthy(nd.condition) {
                self.burn(2);
                sig = self._exec_block(`list(nd.body));
                if sig == 1 {
                    return 1;
                }
                if sig == 2 {
                    break;
                }
            }
            return 0;
        }
        if isinstance(nd, InForStmt) {
            return self._exec_for(nd);
        }
        if isinstance(nd, ReturnStmt) {
            self._ret = self.eval(nd.expr) if nd.expr is not None else CT_NONE;
            return 1;
        }
        if isinstance(nd, CtrlStmt) {
            word = nd.ctrl.name;
            if word == Tok.KW_BREAK.value {
                return 2;
            }
            if word == Tok.KW_CONTINUE.value {
                return 3;
            }
            raise CtError(f"'{nd.ctrl.value}' is not supported in comptime code");
        }
        if isinstance(nd, AssertStmt) {
            if not self.truthy(nd.condition) {
                msg = ct_str(self.eval(nd.error_msg))
                    if nd.error_msg is not None
                    else "";
                detail = ": " + msg if msg else "";
                raise CtError(f"assertion failed{detail}");
            }
            return 0;
        }
        if isinstance(nd, RaiseStmt) {
            if nd.cause is None {
                if self._handling {
                    raise CtRaise(exc=self._handling[-1], user=True);
                }
                raise CtRaise(
                    exc=CtExc(
                        kind="RuntimeError",
                        args=[mk_str("No active exception to reraise")]
                    ),
                    user=True
                );
            }
            raise CtRaise(exc=self._as_exception(self.eval(nd.cause)), user=True);
        }
        if isinstance(nd, TryStmt) {
            return self._exec_try(nd);
        }
        if isinstance(nd, GlobalVars) {
            raise CtError("'glob' inside a comptime function is not supported");
        }
        raise CtError(f"'{type(nd).__name__}' is not supported in comptime code");
    }

    def _as_exception(v: CtValue) -> CtExc {
        if isinstance(v, CtDeferred) {
            raise CtDeferredSignal();
        }
        if isinstance(v, CtExc) {
            return v;
        }
        if isinstance(v, CtType)
            and v.module == "builtins"
            and v.name in CT_BUILTIN_EXCEPTIONS {
            return CtExc(kind=v.name, args=[]);
        }
        return CtExc(kind="RuntimeError", args=[mk_str(ct_str(v))]);
    }

    def _exec_assignment(nd: Assignment) -> int {
        if nd.value is None {
            return 0;
        }
        val = self.eval(nd.value);
        if nd.aug_op is not None {
            sym = CT_AUG_OPS.get(nd.aug_op.name);
            if sym is None {
                raise CtError(f"'{nd.aug_op.value}' is not supported in comptime code");
            }
            cur = self.eval(nd.target[0]);
            if isinstance(cur, CtDeferred) or isinstance(val, CtDeferred) {
                raise CtDeferredSignal();
            }
            self._assign_target(nd.target[0], ct_inplace(sym, cur, val));
            return 0;
        }
        for t in nd.target {
            self._assign_target(t, val);
        }
        return 0;
    }

    def _binop_by_name(
        opn: str, l: CtValue, r: CtValue, display_name: (str | None) = None
    ) -> CtValue {
        sym = ct_symbol(opn);
        if sym == opn or sym in ("<", "<=", ">", ">=") {
            raise CtError(
                f"operator '{display_name
                    if display_name is not None
                    else opn}' is not supported in comptime code"
            );
        }
        return ct_binary(sym, l, r);
    }

    def _exc_matches(handler_type: CtValue, exc: CtExc) -> bool {
        if isinstance(handler_type, CtTuple) {
            for h in handler_type.items {
                if self._exc_matches(h, exc) {
                    return True;
                }
            }
            return False;
        }
        if isinstance(handler_type, CtType)
            and handler_type.module == "builtins"
            and handler_type.name in CT_BUILTIN_EXCEPTIONS {
            return ct_exc_is(exc.kind, handler_type.name);
        }
        return False;
    }

    def _exec_try(nd: TryStmt) -> int {
        pending: (CtRaise | None) = None;
        sig = 0;
        try {
            sig = self._exec_block(`list(nd.body));
            if sig == 0 and isinstance(nd.else_body, ElseStmt) {
                sig = self._exec_block(`list(nd.else_body.body));
            }
        } except CtRaise as raised {
            try {
                sig = self._run_handlers(nd, raised);
            } except CtRaise as again {
                pending = again;
            }
        }
        if nd.finally_body is not None {
            fin = self._exec_block(`list(nd.finally_body.body));
            if fin != 0 {
                return fin;
            }
        }
        if pending is not None {
            raise pending;
        }
        return sig;
    }

    def _run_handlers(nd: TryStmt, raised: CtRaise) -> int {
        exc = raised.exc;
        for h in nd.excepts {
            matched = True;
            if h.ex_type is not None {
                matched = self._exc_matches(self.eval(h.ex_type), exc);
            }
            if matched {
                self.push_frame();
                self._handling.append(exc);
                try {
                    if h.name is not None {
                        self.bind(h.name.value, exc);
                    }
                    return self._exec_block(`list(h.body));
                } finally {
                    self._handling.pop();
                    self.pop_frame();
                }
            }
        }
        raise raised;
    }

    def _attr_get(base: CtValue, name: str) -> CtValue {
        if isinstance(base, CtDeferred) {
            raise CtDeferredSignal();
        }
        if isinstance(base, CtRecord) {
            if name in base.fields {
                return base.fields[name];
            }
            rec_asn = self._class_binding(base.class_type, name);
            if rec_asn is not None and rec_asn.value is not None {
                self._note_producer(rec_asn.find_parent_of_type(Module), body=True);
                return self.eval_with_bindings(rec_asn.value, base.ct_args or {});
            }
            m = self._find_method(base.class_type, name);
            if m is not None {
                return CtBound(self_val=base, ability=m);
            }
            raise CtError(f"{base.class_name} has no field '{name}'");
        }
        if isinstance(base, CtEnumMember) {
            if name == "name" {
                return mk_str(base.member);
            }
            if name == "value" {
                return base.value;
            }
            if base.enum_name == "Codespace"
                and name in ("is_server", "is_client", "is_native") {
                return mk_bool(ct_eq(base.value, mk_str(name[3:])));
            }
            raise CtError(f"'{name}' is not available on enum member {ct_repr(base)}");
        }
        if isinstance(base, CtType) {
            node_ = self._arch_node_of(self._class_type_of(base));
            if isinstance(node_, Enum) {
                for m in self._enum_members(node_) {
                    if m.member == name {
                        return m;
                    }
                }
                raise CtError(f"{base.name} has no member '{name}'");
            }
            bound_asn = self._class_binding(self._class_type_of(base), name);
            if bound_asn is not None and bound_asn.value is not None {
                self._note_producer(bound_asn.find_parent_of_type(Module), body=True);
                return self.eval_with_bindings(bound_asn.value, base.ct_args or {});
            }
            meth = self._find_method(self._class_type_of(base), name);
            if meth is not None {
                return CtBound(self_val=base, ability=meth);
            }
            if base.module == "builtins"
                and base.name in CT_BUILTIN_TYPES
                and not name.startswith("_") {
                return ct_type_attr(base.name, name);
            }
            raise CtError(f"{base.name} has no comptime attribute '{name}'");
        }
        if isinstance(base, CtFunc) {
            raise CtError(f"functions have no comptime attributes ('{name}')");
        }
        if name.startswith("_") {
            raise CtError(f"access to '{name}' is not allowed in comptime code");
        }
        return ct_value_attr(base, name);
    }

    def _eval_trailer(nd: AtomTrailer) -> CtValue {
        base = self.eval(nd.target);
        if nd.is_null_ok and isinstance(base, CtNone) {
            return CT_NONE;
        }
        right = nd.right;
        if nd.is_attr and isinstance(right, Name) {
            return self._attr_get(base, right.value);
        }
        if isinstance(right, IndexSlice) {
            if isinstance(base, CtDeferred) {
                raise CtDeferredSignal();
            }
            if len(right.slices) != 1 {
                raise CtError(
                    "multi-dimensional indexing is not supported in comptime code"
                );
            }
            s0 = right.slices[0];
            if isinstance(base, CtType) and not right.is_range {
                return self._ct_subscript(base, s0.start);
            }
            if right.is_range {
                lo = self.eval(s0.start) if s0.start is not None else None;
                hi = self.eval(s0.stop) if s0.stop is not None else None;
                st = self.eval(s0.step) if s0.step is not None else None;
                return ct_getslice(base, lo, hi, st);
            }
            if s0.start is None {
                raise CtError("empty index in comptime code");
            }
            return ct_getitem(base, self.eval(s0.start));
        }
        if isinstance(right, FuncCall) {
            inner = right.target;
            if isinstance(inner, Name) {
                (args, kwargs) = self._call_args(right);
                return self._call_attr(base, inner.value, args, kwargs);
            }
            raise CtError("computed method calls are not supported in comptime code");
        }
        raise CtError(
            f"'{type(right).__name__}' trailer is not supported in comptime code"
        );
    }
}
