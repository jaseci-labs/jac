import os;

glob CT_FUEL_DEFAULT: int = 50000000,
     CT_CALL_DEPTH_LIMIT: int = 200,
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

def ct_read_host_file(path: str) -> bytes;

def _norm_path(p: str) -> str;

def _is_comptime_module(mod: (Module | None)) -> bool;

def _mod_dotted(mod: (Module | None)) -> str;

def _scope_of(nd: UniNode) -> (UniScopeNode | None);

def _impl_body(nd: UniNode) -> list[UniNode];

def _is_builtin_name(name: str) -> bool;

obj CtEvaluator(CtCaller) {
    has evaluator: TypeEvaluator,
        env: CtEnvironment = CtEnvironment(),
        fuel: int = CT_FUEL_DEFAULT,
        call_depth: int = 0,
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

    def _enter_root(nd: UniNode) -> (Module | None);
    def _note_ct_path(path: str, body: bool = False);
    def _note_producer(home: (Module | None), body: bool = False);
    def _note_definition(nd: UniNode);
    def try_eval(nd: Expr, demand: bool = False) -> (CtValue | None);
    def eval_with_bindings(nd: Expr, bindings: dict[str, CtValue]) -> CtValue;
    def burn(n: int = 1);
    def push_frame(barrier: bool = False);
    def pop_frame;
    def bind(name: str, v: CtValue);
    def frame_lookup(name: str) -> (CtValue | None);
    def assign_name(name: str, v: CtValue);
    def eval(nd: UniNode) -> CtValue;
    def truthy(nd: UniNode) -> bool;
    def _eval_inner(nd: UniNode) -> CtValue;
    def _eval_special(nd: SpecialVarRef) -> CtValue;
    def _builtin_type(name: str) -> CtType;
    def _prefetched_class(name: str) -> (ClassType | None);
    def _eval_multistring(nd: MultiString) -> CtValue;
    def _eval_fstring(nd: FString) -> str;
    def _eval_dict(nd: DictVal) -> CtDict;
    def iterate(coll: CtValue) -> list[CtValue];
    def _compr_items(
        comprs: list[InnerCompr],
        depth: int,
        out_expr: (Expr | None),
        kv_pair: (KVPair | None)
    ) -> list[CtValue];

    def _unpack(v: CtValue, count: int) -> list[CtValue];
    def _bind_target(tgt: UniNode, v: CtValue);
    def _assign_target(tgt: UniNode, v: CtValue);
    def _tok_name(op: (UniNode | None)) -> str;
    def _eval_binary(nd: BinaryExpr) -> CtValue;
    def _cmp(opn: str, l: CtValue, r: CtValue) -> bool;
    def _eval_compare(nd: CompareExpr) -> CtValue;
    def _eval_bool(nd: BoolExpr) -> CtValue;
    def _eval_unary(nd: UnaryExpr) -> CtValue;
    def _eval_name(nd: Name) -> CtValue;
    def _builtin_value(name: str) -> (CtValue | None);
    def _is_stub_module(mod: (Module | None)) -> bool;
    def _demand_tree(sym: Symbol) -> Symbol;
    def _eval_symbol(sym: Symbol, use: UniNode) -> CtValue;
    def _module_value(mp: ModulePath) -> CtModule;
    def _symbol_via_module_item(item: ModuleItem) -> (Symbol | None);
    def _resolve_symbol_deep(sym: Symbol) -> Symbol;
    def _resolve_module_item(item: ModuleItem, use: UniNode) -> CtValue;
    def _is_comptime_glob(asn: Assignment, name: str) -> bool;
    def _ct_module_glob(name: str, use: UniNode) -> CtValue;
    def _is_comptime_loop_target(nd: Name) -> bool;
    def _eval_binding(asn: Assignment) -> CtValue;
    def _stamp_home(v: CtValue, asn: Assignment);
    def _type_of_arch(nd: Archetype) -> CtType;
    def _type_of_enum(nd: Enum) -> CtType;
    def _func_of(nd: Ability) -> CtFunc;
    def _enum_members(nd: Enum) -> list[CtEnumMember];
    def _enum_member_of(asn: Assignment) -> CtEnumMember;
    def _class_type_of(v: CtValue) -> (ClassType | None);
    def _arch_node_of(ct: (ClassType | None)) -> (Archetype | Enum | None);
    def ct_type_of_class(t: (TypeBase | None)) -> CtType;
    def ct_type_of_value(v: CtValue) -> CtType;
    def _builtin_isinstance(v: CtValue, name: str) -> bool;
    def ct_isinstance(v: CtValue, t: CtValue) -> bool;
    def _is_subtype(t: CtType, u: CtType) -> bool;
    def _has_vars_of(ct: ClassType) -> list[HasVar];
    def _field_type_of(hv: HasVar) -> (CtType | None);
    def _field_info(hv: HasVar, sym: (Symbol | None)) -> CtRecord;
    def intrinsic_fields(t: CtValue) -> CtList;
    def intrinsic_members(t: CtValue) -> CtList;
    def _semstr_of_name(nd: Name) -> str;
    def intrinsic_semstr(t: CtValue, field: str = "") -> CtValue;
    def _str_arg(v: CtValue, what: str) -> str;
    def _intrinsic(
        name: str, nd: FuncCall, args: list[CtValue], kwargs: dict[str, CtValue]
    ) -> CtValue;

    def _intrinsic_name_of(tgt: UniNode) -> (str | None);
    def _defining_module_of(nd: UniNode) -> (str | None);
    def _call_args(nd: FuncCall) -> tuple[list[CtValue], dict[str, CtValue]];
    def _eval_call(nd: FuncCall) -> CtValue;
    def _eval_call_counted(nd: FuncCall) -> CtValue;
    def _class_binding(ct: (ClassType | None), name: str) -> (Assignment | None);
    def _ct_subscript(base: CtType, head: (Expr | None)) -> CtType;
    def _find_method(ct: (ClassType | None), name: str) -> (Ability | None);
    def _call_attr(
        recv: CtValue, attr: str, args: list[CtValue], kwargs: dict[str, CtValue]
    ) -> CtValue;

    def call_value(
        callee: CtValue, args: list[CtValue], kwargs: dict[str, CtValue]
    ) -> CtValue;

    def _construct(
        t: CtType, args: list[CtValue], kwargs: dict[str, CtValue]
    ) -> CtValue;

    def _user_method(ct: ClassType, name: str) -> (Ability | None);
    def call_ability(
        ability: Ability,
        args: list[CtValue],
        kwargs: dict[str, CtValue],
        self_val: (CtValue | None) = None
    ) -> CtValue;

    def _embed(nd: FuncCall, rel: str, as_bytes: bool) -> CtValue;
    def _scalar_size_align(t: CtValue) -> (tuple[int, int] | None);
    def _size_align(t: CtValue) -> tuple[int, int];
    def _self_type_of(self_val: (CtValue | None), ability: Ability) -> (CtType | None);
    def _exec_block(stmts: list[UniNode]) -> int;
    def _for_item(coll: CtValue, items: list[CtValue], idx: int) -> (CtValue | None);
    def _exec_for(nd: InForStmt) -> int;
    def _exec_stmt(nd: UniNode) -> int;
    def _as_exception(v: CtValue) -> CtExc;
    def _exec_assignment(nd: Assignment) -> int;
    def _binop_by_name(
        opn: str, l: CtValue, r: CtValue, display_name: (str | None) = None
    ) -> CtValue;

    def _exc_matches(handler_type: CtValue, exc: CtExc) -> bool;
    def _exec_try(nd: TryStmt) -> int;
    def _run_handlers(nd: TryStmt, raised: CtRaise) -> int;
    def _attr_get(base: CtValue, name: str) -> CtValue;
    def _eval_trailer(nd: AtomTrailer) -> CtValue;
}
