import os;
import hashlib;

glob OVERFLOW_MESSAGE: str = "integer overflow",
     ZERO_DIVISION_MESSAGE: str = "integer division or modulo by zero",
     FLOAT_ZERO_DIVISION_MESSAGE: str = "float division by zero",
     FLOAT_ZERO_MODULO_MESSAGE: str = "float modulo by zero",
     FLOAT_ZERO_FLOOR_MESSAGE: str = "float floor division by zero",
     AUG_OPERATORS: dict[str, str] = {
         "ADD_EQ": "PLUS",
         "SUB_EQ": "MINUS",
         "MUL_EQ": "STAR_MUL",
         "DIV_EQ": "DIV",
         "FLOOR_DIV_EQ": "FLOOR_DIV",
         "MOD_EQ": "MOD",
         "BW_AND_EQ": "BW_AND",
         "BW_OR_EQ": "BW_OR",
         "BW_XOR_EQ": "BW_XOR",
         "LSHIFT_EQ": "LSHIFT",
         "RSHIFT_EQ": "RSHIFT",
         "STAR_POW_EQ": "STAR_POW",
         "MATMUL_EQ": "DECOR_OP"
     },
     OPERATOR_SYMBOLS: dict[str, str] = {
         "PLUS": "+",
         "MINUS": "-",
         "STAR_MUL": "*",
         "DIV": "/",
         "FLOOR_DIV": "//",
         "MOD": "%",
         "STAR_POW": "**",
         "BW_AND": "&",
         "BW_OR": "|",
         "BW_XOR": "^",
         "LSHIFT": "<<",
         "RSHIFT": ">>"
     },
     OPERATOR_DUNDERS: dict[str, str] = {
         "PLUS": "add",
         "MINUS": "sub",
         "STAR_MUL": "mul",
         "DIV": "truediv",
         "FLOOR_DIV": "floordiv",
         "MOD": "mod",
         "STAR_POW": "pow",
         "BW_AND": "and",
         "BW_OR": "or",
         "BW_XOR": "xor",
         "LSHIFT": "lshift",
         "RSHIFT": "rshift",
         "DECOR_OP": "matmul"
     },
     SHIFT_MESSAGE: str = "shift count out of range",
     NEGATIVE_SHIFT_MESSAGE: str = "negative shift count",
     RANGE_STEP_MESSAGE: str = "range() arg 3 must not be zero",
     CLOSURE_CELLS_OFFSET: int = 16,
     RC_THREADED_FLAG: str = "__jac_rc_threaded",
     GEN_PENDING_TYPE: int = 8,
     TASK_THREAD: int = 0,
     TASK_STATE: int = 8,
     TASK_BITS: int = 16,
     TASK_KIND: int = 24,
     TASK_ERROR: int = 32,
     TASK_MESSAGE: int = 40,
     TASK_ORIGIN: int = 48,
     TASK_ARGS: int = 64,
     GEN_PENDING_MESSAGE: int = 16,
     GEN_PENDING_ORIGIN: int = 24,
     RC_DEBUG_OFF_NOTICE: str = "jac: RC debug tracing not compiled in (build with --debug or [native] debug = true)",
     KIND_INT: int = 0,
     KIND_FLOAT: int = 1,
     KIND_BOOL: int = 2,
     KIND_STR: int = 3,
     KIND_REF: int = 4,
     KIND_TUPLE: int = 5,
     KIND_ANY: int = 6,
     KIND_UINT: int = 7,
     KIND_NULL: int = 8,
     SORT_TAGGED_KIND: int = 16,
     TUPLE_BOX_MEMBERS: int = 8,
     NO_VALUE_KIND: int = -1,
     LIST_INDEX_MESSAGE: str = "list index out of range",
     LIST_ASSIGN_MESSAGE: str = "list assignment index out of range",
     POP_EMPTY_MESSAGE: str = "pop from empty list",
     KEY_MESSAGE: str = "key not found",
     LIST_VALUE_MESSAGE: str = "value is not in list",
     STR_INDEX_MESSAGE: str = "string index out of range",
     ANY_INT_TAG: int = 0,
     ANY_FLOAT_TAG: int = 1,
     ANY_STR_TAG: int = 2,
     ANY_LIST_TAG: int = 3,
     ANY_DICT_TAG: int = 4,
     ANY_SET_TAG: int = 5,
     ANY_OBJ_TAG: int = 6,
     ANY_BOOL_TAG: int = 7,
     ANY_NONE_TAG: int = 8,
     ANY_ENUM_TAG: int = 9,
     ANY_ELLIPSIS_TAG: int = 10,
     OSP_DIR_IN: int = 1,
     OSP_DIR_OUT: int = 2,
     OSP_DIR_ANY: int = 3,
     OSP_TAG_OFFSET: int = 8,
     OSP_REPORTS_OFFSET: int = 16,
     UNTYPED_OSP_TAG: int = -1,
     OSP_ROOT_HELP: str = "The native tier has no root node yet. Build the graph from a node of your own, or keep this module on the server codespace.",
     OSP_ROOT_CONNECT_HELP: str = "The native tier has no root node. A plain `root ++> node` is accepted as an anchor that nothing native can observe; one that names an edge, collects it, points at root, or sits in a module that follows edges backward would be missed.",
     OSP_PREDICATE_HELP: str = "edge attribute predicates need a named edge type (`->:E:field == value:->`) so the edge layout is known",
     OSP_FILTER_HELP: str = "This filter's element archetype is not statically known; put a type filter first (`[?:NodeType]`) so field predicates can resolve a layout, or filter with an explicit loop.",
     OSP_JID_HELP: str = "Native `jid()` takes one argument statically typed as a node or edge (narrow an optional one with `is not None` first); only nodes and edges have a graph identity.",
     OSP_SKIP_HELP: str = "`skip` ends an event ability (a void body); in a value-returning function use an explicit `return`.",
     OSP_FANOUT_HELP: str = "A connect lowers with a list of nodes on one side only, and not where it also collects the edges; connect in a loop.",
     OSP_DISCONNECT_LIST_HELP: str = "a disconnect with both list operands and attribute predicates is not lowered natively; loop over the nodes and disconnect each pair.",
     EXC_TYPE_OFFSET: int = 8,
     EXC_MESSAGE_OFFSET: int = 24,
     DROP_RC_SENTINEL: int = 9223372036854775807,
     MEMORY_ORDERS: list[str] = [
         "monotonic",
         "acquire",
         "acquire",
         "release",
         "acq_rel",
         "seq_cst"
     ],
     ANY_ORDER_CODES: dict[str, int] = {"lt": 0, "le": 1, "gt": 2, "ge": 3},
     ANY_ARITH_CODES: dict[str, int] = {
         "PLUS": 0,
         "MINUS": 1,
         "STAR_MUL": 2,
         "DIV": 3,
         "FLOOR_DIV": 4,
         "MOD": 5
     },
     ANY_UNARY_CODES: dict[str, int] = {"MINUS": 0, "PLUS": 1, "BW_NOT": 2},
     TEXT_THUNK_MODE: int = 8,
     TEXT_THUNK_RESULT: int = 16,
     COMPARE_OPERATORS: dict[str, str] = {
         "EE": "eq",
         "NE": "ne",
         "LT": "lt",
         "GT": "gt",
         "LTE": "le",
         "GTE": "ge"
     };

glob CTOR_MASK_BITS: int = 63;

glob ANY_TYPE_TAGS: dict[str, list[int]] = {
         "int": [0, 7],
         "bool": [7],
         "float": [1],
         "str": [2],
         "list": [3],
         "dict": [4],
         "set": [5],
         "frozenset": [5],
         "NoneType": [8],
         "EllipsisType": [10],
         "ellipsis": [10]
     },
     STATIC_TYPE_NAMES: dict[str, str] = {
         "int": "int",
         "float": "float",
         "str": "str",
         "str.ref": "str",
         "bool": "bool",
         "none": "NoneType",
         "list": "list",
         "dict": "dict",
         "set": "set",
         "tuple": "tuple",
         "range": "range",
         "bytes": "bytes",
         "bytearray": "bytearray",
         "fn": "function",
         "iter": "generator"
     };

glob ABSTRACT_TYPE_NAMES: dict[str, list[str]] = {
         "Sequence": ["list", "tuple", "str", "bytes", "bytearray", "range"],
         "MutableSequence": ["list", "bytearray"],
         "Mapping": ["dict"],
         "MutableMapping": ["dict"],
         "AbstractSet": ["set"],
         "MutableSet": ["set"]
     };

glob TEXT_CASES: dict[str, int] = {
         "upper": 0,
         "lower": 1,
         "casefold": 1,
         "swapcase": 2,
         "title": 3,
         "capitalize": 4
     },
     TEXT_TESTS: dict[str, int] = {
         "isdigit": 0,
         "isdecimal": 0,
         "isnumeric": 0,
         "isalpha": 1,
         "isspace": 2,
         "isalnum": 3,
         "isupper": 4,
         "islower": 5,
         "isascii": 6,
         "isidentifier": 7,
         "istitle": 8,
         "isprintable": 9
     },
     TEXT_STRIPS: dict[str, int] = {"strip": 0, "lstrip": 1, "rstrip": 2},
     TEXT_JUSTIFY: dict[str, int] = {"ljust": 0, "rjust": 1, "center": 2},
     TEXT_CODECS: dict[str, int] = {
         "utf-8": 0,
         "utf8": 0,
         "u8": 0,
         "utf": 0,
         "ascii": 1,
         "us-ascii": 1,
         "646": 1,
         "latin-1": 2,
         "latin1": 2,
         "iso-8859-1": 2,
         "iso8859-1": 2,
         "l1": 2
     },
     TEXT_ERRORS: dict[str, int] = {
         "strict": 0,
         "replace": 1,
         "ignore": 2,
         "surrogatepass": 3
     },
     TEXT_BUILTINS: list[str] = [
         "str",
         "len",
         "int",
         "float",
         "bool",
         "bytes",
         "bytearray",
         "repr",
         "ascii",
         "format",
         "hash",
         "ord",
         "chr",
         "hex",
         "oct",
         "bin",
         "abs",
         "min",
         "max",
         "round",
         "divmod",
         "pow"
     ],
     BUILTIN_STUBS: list[str] = [
         "builtins.pyi",
         "builtins.jac",
         "na_builtins.pyi",
         "jac_builtins.pyi",
         "builtin_overrides.pyi"
     ],
     TEXT_STOP: int = 4611686018427387904,
     FSTRING_STR: int = 115,
     FSTRING_REPR: int = 114,
     FSTRING_ASCII: int = 97;

obj MirWithExit {
    has site: uni.UniNode,
        region_depth: (MirValue | None) = None,
        region_owned: (MirValue | None) = None,
        decl: (MirDecl | None) = None,
        held: (MirValue | None) = None,
        it: (MirValue | None) = None,
        out: (MirValue | None) = None,
        file: (MirValue | None) = None;
}

obj MirLoopTarget {
    has head: MirBlock,
        after: MirBlock;
}

obj MirIterCursor {
    has kind: str,
        elem: MirType,
        source: (MirValue | None) = None,
        position: (MirValue | None) = None,
        limit: (MirValue | None) = None,
        stride: (MirValue | None) = None,
        out: (MirValue | None) = None,
        payloads: list[int] = [],
        parts: list[MirIterCursor] = [],
        counter: (MirValue | None) = None,
        callee: (MirValue | None) = None,
        site: (uni.UniNode | None) = None;
}

obj MirGenInfo {
    has elem: MirType,
        frame: MirValue,
        out: MirValue;
}

obj MirFnState {
    has fn: MirFunction,
        b: MirBuilder,
        generator: (MirGenInfo | None) = None,
        self_value: (MirValue | None) = None,
        captured: dict[int, MirValue] = {},
        cell_types: dict[int, MirType] = {},
        env_cells: dict[int, int] = {},
        env: (MirValue | None) = None,
        locals: dict[int, MirValue] = {},
        local_names: dict[str, MirValue] = {},
        loops: list[MirLoopTarget] = [],
        caught: list[tuple[MirValue, MirValue, MirValue]] = [],
        bound_caught: dict[int, tuple[MirValue, MirValue, MirValue]] = {},
        tries: list[tuple[MirValue, MirBlock, int]] = [],
        in_test: bool = False,
        try_exits: dict[int, MirWithExit] = {},
        finals: list[tuple[list[uni.UniNode], int, int]] = [],
        specials: dict[str, MirValue] = {},
        region_slots: list[MirValue] = [],
        region_escape: (MirValue | None) = None,
        pinned: dict[int, MirValue] = {},
        user_loads: dict[int, str] = {};
}

obj MirBound {
    has value: MirValue,
        site: uni.UniNode,
        star: bool = False;
}

obj MirPacked {
    has items: list[(uni.Expr | MirBound)],
        site: uni.UniNode,
        keyword: bool = False,
        names: list[str] = [],
        bindable: list[str] = [],
        unique: bool = False;
}

obj MirDecl {
    has ability: uni.Ability,
        symbol: str,
        ret: MirType,
        params: list[MirType] = [],
        self_type: (MirType | None) = None,
        owner: (uni.Archetype | None) = None,
        event: str = "",
        env: dict[str, TypeBase] = {},
        c_variadic: bool = False,
        c_symbol: str = "";
}

def mono_symbol_text(text: str) -> str;

def mir_same_signature(left: MirDecl, right: MirDecl) -> bool;

obj MirLowering {
    has prog: JacProgram,
        module: uni.Module,
        mir: MirModule,
        decls: dict[int, MirDecl] = {},
        decl_syms: dict[int, int] = {},
        archetypes: dict[str, uni.Archetype] = {},
        refused_objects: dict[str, MirRefused] = {},
        stdlib_units: dict[str, (uni.Module | None)] = {},
        manager_item: (uni.Expr | None) = None,
        c_struct_sites: dict[str, str] = {},
        layout_owners: set[int] = set(),
        variant_units: dict[str, (uni.Module | None)] = {},
        c_entries: dict[str, MirFunction] = {},
        c_conflicts: list[tuple[uni.Ability, str, str]] = [],
        trace_pairs: list[tuple[str, str]] = [],
        text_pairs: list[tuple[str, str]] = [],
        text_regs: dict[str, tuple[MirBlock, list[MirInstr]]] = {},
        class_entries: list[tuple[str, str, str]] = [],
        class_lineages: list[tuple[str, str]] = [],
        deferred_globals: list[tuple[MirGlobal, uni.Expr]] = [],
        entry_globals: dict[int, set[int]] = {},
        missing_imports: dict[int, (str | None)] = {},
        class_inits: list[tuple[int, str]] = [],
        class_global_refusals: dict[str, MirRefused] = {},
        nested: list[MirFunction] = [],
        adapters: dict[str, str] = {},
        fn_values: dict[int, MirDecl] = {},
        text_fns: dict[str, str] = {},
        text_serial: int = 0,
        enum_thunks: dict[str, str] = {},
        slot_cache: dict[str, dict[int, list[str]]] = {},
        named_archs: dict[str, uni.Archetype] = {},
        default_entries: list[tuple[str, str]] = [],
        indexed_units: set[int] = set(),
        order: list[int] = [],
        refusals: dict[str, list[NativeRefusal]] = {},
        osp_model: (OspModel | None) = None,
        osp_setup: str = "",
        osp_thunks: dict[str, str] = {},
        osp_preds: int = 0,
        type_env: dict[str, TypeBase] = {},
        templates: dict[int, uni.Ability] = {},
        instances: dict[str, MirDecl] = {},
        specials: dict[str, int] = {},
        pending: list[MirDecl] = [],
        enum_types: dict[str, TypeBase] = {},
        enum_methods: dict[str, MirDecl] = {},
        bindings: list[InteropBinding] = [],
        current: str = "",
        dep_verdicts: dict[str, (list[str] | None)] = {},
        erased_units: set[str] = set(),
        erased_archs: dict[int, bool] = {},
        imported_fns: dict[str, tuple[str, str]] = {},
        flow_sites: int = 0,
        tests: list[tuple[str, str, str, int]] = [],
        c_views: dict[int, MirGlobal] = {},
        owned_world: bool = False,
        ctor_consumes: dict[str, list[int]] = {},
        state: (MirFnState | None) = None;

    def lower -> MirModule;
    def stamp_ownership;
    def tag_ownership(tag: (uni.UniNode | None)) -> (OwnershipKind | None);
    def tag_borrows(tag: (uni.UniNode | None)) -> bool;
    def returns_borrow(ab: uni.Ability) -> bool;
    def reads_self(expr: (uni.UniNode | None), fields: bool) -> bool;
    def elements_borrowed(tag: (uni.UniNode | None)) -> bool;
    def lend_fresh(
        value: MirValue, tag: (uni.UniNode | None), source: (uni.UniNode | None)
    );

    def param_owns(pv: uni.ParamVar) -> bool;
    def field_consumes(arch: uni.Archetype, name: str) -> bool;
    def lower_unit -> MirModule;
    def declaration_types;
    def record_defaults;
    def settle;
    def settle_tests;
    def callees_of(fn: MirFunction) -> list[str];
    def module_abilities -> list[uni.Ability];
    def declare(ab: uni.Ability);
    def symbol_of(ab: uni.Ability) -> str;
    def c_exported(access: (uni.SubTag[uni.Token] | None), path: str) -> bool;
    def unit_symbol(
        name: str, access: (uni.SubTag[uni.Token] | None), path: str = ""
    ) -> str;

    def name_of(ab: uni.Ability) -> str;
    def ability_sym(ab: uni.Ability) -> uni.Symbol;
    def lower_function(decl: MirDecl) -> (MirFunction | None);
    def st -> MirFnState;
    def builder -> MirBuilder;
    def symbol_type(sym: (uni.Symbol | None), site: uni.UniNode) -> MirType;
    def expr_type(nd: uni.Expr) -> MirType;
    def lower_body(stmts: Sequence[uni.UniNode]);
    def drop_last_uses(stmt: uni.UniNode);
    def drop_consumed_args(nd: uni.FuncCall);
    def forget_slot(slot: MirValue);
    def lower_stmt(nd: uni.UniNode);
    def lower_assignment(nd: uni.Assignment);
    def assign_to(target: uni.UniNode, value: MirValue, nd: uni.Assignment);
    def store_name(target: uni.Name, value: MirValue);
    def exchange_place(arg: uni.Expr) -> MirValue;
    def place_exchange(nd: uni.FuncCall, name: str) -> (MirValue | None);
    def owned_exchange(
        nd: uni.FuncCall,
        name: str,
        args: list[uni.Expr],
        first: MirValue,
        elem: MirType,
        held: MirValue
    ) -> MirValue;

    def local_slot(sym: (uni.Symbol | None), site: uni.UniNode) -> MirValue;
    def encloses(scope: (uni.UniScopeNode | None), nd: uni.UniNode) -> bool;
    def first_iterable(nd: uni.UniNode) -> bool;
    def comprehension_scoped(sym: uni.Symbol) -> bool;
    def lower_return(nd: uni.ReturnStmt);
    def lower_if(nd: (uni.IfStmt | uni.ElseIf));
    def lower_else(nd: (uni.ElseStmt | uni.ElseIf | None), done: MirBlock);
    def lower_iter_for(nd: uni.IterForStmt);
    def lower_while(nd: uni.WhileStmt);
    def lower_forever(nd: uni.ForeverStmt);
    def lower_ctrl(nd: uni.CtrlStmt);
    def lower_for(nd: uni.InForStmt);
    def lower_for_core(nd: uni.InForStmt);
    def lower_range_for(nd: uni.InForStmt, bounds: list[uni.Expr]);
    def lower_if_else_effect(nd: uni.IfElseExpr);
    def lower_if_else_expr(nd: uni.IfElseExpr) -> MirValue;
    def to_str(value: MirValue, site: uni.UniNode) -> MirValue;
    def lower_fstring(nd: uni.FString) -> MirValue;
    def lower_expr(nd: uni.UniNode) -> MirValue;
    def literal_destination(nd: uni.Int) -> (str | None);
    def lower_name(nd: uni.Name) -> MirValue;
    def lower_binary(nd: uni.BinaryExpr) -> MirValue;
    def arith(op: str, left: MirValue, right: MirValue, site: uni.UniNode) -> MirValue;
    def shift(op: str, left: MirValue, right: MirValue) -> MirValue;
    def lower_compare(nd: uni.CompareExpr) -> MirValue;
    def compare_values(
        op: str, left: MirValue, right: MirValue, site: uni.UniNode
    ) -> MirValue;

    def lower_unary(nd: uni.UnaryExpr) -> MirValue;
    def lower_bool(nd: uni.BoolExpr) -> MirValue;
    def lower_call(nd: uni.FuncCall) -> MirValue;
    def truthy(value: MirValue, site: uni.UniNode) -> MirValue;
    def adopt_imported_layouts(target: (uni.Module | None) = None);
    def obj_extends(child: str, base: str) -> bool;
    def coerce(value: MirValue, to: MirType, site: uni.UniNode) -> MirValue;
    def const_zero(value: MirValue) -> bool;
    def unify_numeric(
        left: MirValue, right: MirValue, site: uni.UniNode
    ) -> tuple[MirValue, MirValue];

    def raise_if(cond: MirValue, exception: str, message: str);
    def type_of(
        t: (TypeBase | None), position: MirPosition, site: uni.UniNode
    ) -> MirType;

    def ensure_objects(t: (TypeBase | None));
    def ensure_c_types(t: (TypeBase | None));
    def c_struct_of(t: (TypeBase | None)) -> (uni.Archetype | None);
    def variant_struct(arch: uni.Archetype) -> uni.Archetype;
    def variant_unit(mod: uni.Module) -> (uni.Module | None);
    def variant_ability(callee: uni.Ability) -> uni.Ability;
    def variant_glob(nd: uni.Name) -> (uni.Name | None);
    def variant_value(nd: uni.Name, twin: uni.Name) -> (MirValue | None);
    def variant_declaration(declaration: uni.Assignment) -> (uni.Assignment | None);
    def foreign_c_declaration(name: str) -> (uni.Ability | None);
    def c_signature_text(params: list[MirType], ret: MirType) -> str;
    def c_declared_signature(decl: uni.Ability, site: uni.UniNode) -> (str | None);
    def c_entry(
        symbol: str, params: list[MirType], ret: MirType, target: uni.Ability
    ) -> str;

    def c_struct_same(arch: uni.Archetype, name: str) -> bool;
    def arch_fields(arch: uni.Archetype) -> list[uni.HasVar];
    def lower_place(nd: uni.UniNode) -> MirValue;
    def place_elem(place: MirValue) -> MirType;
    def lower_trailer(nd: uni.AtomTrailer) -> MirValue;
    def call_name(nd: uni.FuncCall) -> str;
    def c_extern(
        callee: uni.Ability, site: uni.UniNode
    ) -> tuple[str, list[tuple[MirType, str]], MirType, str, bool];

    def c_call(nd: uni.FuncCall, callee: uni.Ability) -> MirValue;
    def c_extern_address(nd: uni.Name) -> (MirValue | None);
    def c_param_borrowed(pv: uni.ParamVar) -> bool;
    def c_declared_type(
        declared: (TypeBase | None), fallback: (TypeBase | None)
    ) -> (TypeBase | None);

    def c_param_plan(
        pv: uni.ParamVar, fallback: (TypeBase | None), site: uni.UniNode
    ) -> tuple[MirType, str];

    def c_bare(nd: uni.Expr) -> uni.Expr;
    def c_borrow_operand(arg: uni.Expr) -> (uni.Expr | None);
    def c_same_storage(a: MirType, b: MirType) -> bool;
    def c_address(place: MirValue, to: MirType) -> MirValue;
    def c_lend(
        arg: uni.Expr,
        to: MirType,
        exact: bool,
        copybacks: list[tuple[MirValue, MirValue, MirType]]
    ) -> MirValue;

    def c_text_arg(value: MirValue, site: uni.UniNode) -> MirValue;
    def c_arg(
        arg: uni.Expr,
        to: MirType,
        plan: str,
        copybacks: list[tuple[MirValue, MirValue, MirType]]
    ) -> MirValue;

    def c_vararg(arg: uni.Expr) -> MirValue;
    def c_defines(decl: uni.UniNode) -> bool;
    def declare_c_definition(ab: uni.Ability);
    def va_arg(nd: uni.FuncCall, receiver: uni.Expr) -> MirValue;
    def region_call(name: str, args: list[MirValue]) -> MirValue;
    def lower_open(nd: uni.OpenStmt);
    def drop_regions;
    def fresh_block(size: MirValue) -> MirValue;
    def region_escape_entry;
    def region_value(value: MirValue) -> MirValue;
    def region_builtin(nd: uni.FuncCall, name: str) -> (MirValue | None);
    def region_alloc(
        size: MirValue, drop_symbol: str, local: bool, eligible: bool = True
    ) -> tuple[MirValue, MirValue];

    def list_extend_in_place(
        op: str, current: MirValue, value: MirValue, site: uni.UniNode
    ) -> (MirValue | None);

    def pointer_arith(
        op: str, left: MirValue, right: MirValue, site: uni.UniNode
    ) -> (MirValue | None);

    def later_local(nd: uni.Name) -> bool;
    def guard_unbound(fn: MirFunction);
    def lower_discarded(nd: uni.Expr);
    def condition(nd: uni.Expr) -> MirValue;
    def c_return_plan(
        sig: uni.FuncSignature, fallback: (TypeBase | None), site: uni.UniNode
    ) -> tuple[MirType, str];

    def import_call(nd: uni.FuncCall, callee: uni.Ability) -> (MirValue | None);
    def require_dep_native(path: str, symbol: str, site: uni.UniNode);
    def dep_verdict(path: str) -> (bool | None);
    def add_dep(path: str, name: str, site: (uni.UniNode | None));
    def intrinsic_call(nd: uni.FuncCall, name: str) -> MirValue;
    def intrinsic_operand(arg: uni.Expr, spec: str) -> MirValue;
    def memory_order(nd: uni.FuncCall, arg: uni.Expr, kind: str) -> str;
    def type_call(nd: uni.FuncCall) -> (MirValue | None);
    def method_call(nd: uni.FuncCall, target: uni.AtomTrailer) -> (MirValue | None);
    def call_args(nd: uni.FuncCall) -> list[uni.Expr];
    def coerce_place(place: MirValue) -> MirValue;
    def common_int(
        left: MirType, right: MirType, site: uni.UniNode
    ) -> (MirType | None);

    def struct_temp_place(nd: uni.Expr) -> MirValue;
    def declare_global(nd: uni.Name) -> (MirGlobal | None);
    def declare_c_data;
    def declare_clib_externs;
    def note_clib(imp: (uni.Import | None)) -> int;
    def declare_module_globals;
    def c_struct_call(nd: uni.FuncCall, struct_type: MirType) -> MirValue;
    def c_field_value(expr: uni.Expr, member: MirType) -> MirValue;
    def c_pin(nd: uni.FuncCall) -> MirValue;
    def c_alloca(size: uni.Expr) -> MirValue;
    def c_thread_local(nd: uni.FuncCall, name: str, args: list[uni.Expr]) -> MirValue;
    def c_function_value(expr: uni.Expr, member: MirType) -> MirValue;
    def declare_c_global(assign: uni.Assignment) -> MirGlobal;
    def c_array_count(value: uni.Expr, elem: TypeBase) -> int;
    def c_const(
        expr: uni.Expr, ctype: (TypeBase | None), target: MirType, count: int = -1
    ) -> MirConst;

    def c_const_refusal(expr: uni.UniNode) -> NativeRefusal;
    def c_const_struct(expr: uni.Expr, arch: uni.Archetype) -> MirConst;
    def c_const_address(expr: uni.Expr) -> MirConst;
    def c_function_symbol(expr: uni.Expr, from_c: bool = True) -> str;
    def c_addressed(nd: uni.FuncCall) -> MirGlobal;
    def c_addressof(nd: uni.FuncCall) -> MirValue;
    def c_global_settle;
    def c_const_lost(made: MirConst) -> str;
    def global_place(nd: uni.Name) -> (MirValue | None);
    def global_declaration(sym: uni.Symbol) -> (uni.Assignment | None);
    def entry_global(assign: uni.Assignment, sym: uni.Symbol) -> bool;
    def missing_import(nd: uni.Name) -> (str | None);
    def missing_import_of(item: uni.ModuleItem) -> (str | None);
    def runtime(name: str, args: list[MirValue]) -> (MirValue | None);
    def temp_slot(type: MirType) -> MirValue;
    def spill(value: MirValue) -> MirValue;
    def name_slot(target: uni.Name) -> MirValue;
    def bound_values(args: list[any], params: list[MirType]) -> list[MirValue];
    def lower_string(nd: (uni.String | uni.MultiString)) -> MirValue;
    def str_concat(left: MirValue, right: MirValue) -> MirValue;
    def str_compare(op: str, left: MirValue, right: MirValue) -> MirValue;
    def builtin_call(nd: uni.FuncCall, name: str) -> (MirValue | None);
    def builtin_callee(callee: (uni.UniNode | None)) -> bool;
    def lower_print(nd: uni.FuncCall) -> MirValue;
    def elem_kind(t: MirType, site: uni.UniNode) -> int;
    def to_bits(value: MirValue, elem: MirType, site: uni.UniNode) -> MirValue;
    def scalar_from_bits(bits: MirValue, elem: MirType) -> MirValue;
    def owned_element(handle: MirValue, elem: MirType) -> MirValue;
    def tuple_box(value: MirValue, site: uni.UniNode) -> MirValue;
    def tuple_unbox(handle: MirValue, t: MirType) -> MirValue;
    def address_of(value: MirValue) -> MirValue;
    def container_len(value: MirValue) -> MirValue;
    def list_read(lst: MirValue, index: MirValue) -> MirValue;
    def list_index(lst: MirValue, index: MirValue, message: str) -> MirValue;
    def lower_list_literal(nd: uni.ListVal) -> MirValue;
    def lower_set_literal(nd: uni.SetVal) -> MirValue;
    def lower_dict_literal(nd: uni.DictVal) -> MirValue;
    def new_list(elem: MirType, capacity: int) -> MirValue;
    def new_dict(key: MirType, value: (MirType | None), result: MirType) -> MirValue;
    def container_get(
        base: MirValue, slice: uni.IndexSlice, site: uni.UniNode
    ) -> MirValue;

    def container_set(
        base: MirValue, slice: uni.IndexSlice, value: MirValue, site: uni.UniNode
    );

    def dict_get(d: MirValue, key: MirValue, site: uni.UniNode) -> MirValue;
    def dict_entry_value(d: MirValue, at: MirValue, site: uni.UniNode) -> MirValue;
    def is_spread(item: uni.UniNode) -> bool;
    def each_begin(
        source: MirValue, site: uni.UniNode
    ) -> tuple[MirValue, MirIterCursor, MirBlock, MirBlock];

    def each_end(head: MirBlock, after: MirBlock);
    def container_add(made: MirValue, item: MirValue, site: uni.UniNode);
    def extend_from(made: MirValue, source: MirValue, site: uni.UniNode);
    def container_rebuild(value: MirValue, to: MirType, site: uni.UniNode) -> MirValue;
    def merge_dict(made: MirValue, source: MirValue, site: uni.UniNode, unique: bool);
    def list_slice(lst: MirValue, part: uni.Slice, site: uni.UniNode) -> MirValue;
    def dict_entry(
        d: MirValue, at: MirValue, part: MirType, is_key: bool, site: uni.UniNode
    ) -> MirValue;

    def list_sort(lst: MirValue, nd: uni.FuncCall) -> (MirValue | None);
    def key_function(key_nd: uni.Expr) -> MirValue;
    def key_slot_type(key_fn: MirValue, site: uni.UniNode) -> MirType;
    def keyed_sort(
        made: MirValue, key_fn: MirValue, flag: MirValue, site: uni.UniNode
    );

    def extreme_named(nd: uni.FuncCall, name: str) -> (MirValue | None);
    def sized_type_name(nd: uni.UniNode) -> (str | None);
    def int_bounds(t: MirType) -> tuple[int, int];
    def int_bits(value: int, t: MirType) -> int;
    def sized_bound(nd: uni.AtomTrailer) -> (MirValue | None);
    def sized_wrap(nd: uni.FuncCall, name: str) -> MirValue;
    def wrapping_call(nd: uni.FuncCall, name: str, args: list[uni.Expr]) -> MirValue;
    def checked_cast(value: MirValue, to: MirType, site: uni.UniNode) -> MirValue;
    def struct_call(nd: uni.FuncCall, name: str) -> MirValue;
    def int_bytes_call(
        nd: uni.FuncCall, target: uni.AtomTrailer, name: str
    ) -> (MirValue | None);

    def set_algebra(
        s: MirValue, other: MirValue, name: str, site: uni.UniNode
    ) -> MirValue;

    def set_operator(
        op: str, left: MirValue, right: MirValue, in_place: bool, site: uni.UniNode
    ) -> (MirValue | None);

    def nullable_payload(t: MirType) -> bool;
    def sort_kind(t: MirType, site: uni.UniNode) -> int;
    def container_method(
        receiver: MirValue, name: str, nd: uni.FuncCall
    ) -> (MirValue | None);

    def list_method(lst: MirValue, name: str, nd: uni.FuncCall) -> (MirValue | None);
    def dict_method(d: MirValue, name: str, nd: uni.FuncCall) -> (MirValue | None);
    def set_method(s: MirValue, name: str, nd: uni.FuncCall) -> (MirValue | None);
    def contains(item: MirValue, holder: MirValue, site: uni.UniNode) -> MirValue;
    def string_enum_ordinal(
        item: MirValue, elem: MirType, site: uni.UniNode
    ) -> MirValue;

    def container_eq(left: MirValue, right: MirValue) -> MirValue;
    def view_kind(nd: uni.Expr) -> str;
    def view_compare(
        op: str, left_nd: uni.Expr, left: MirValue, right_nd: uni.Expr, right: MirValue
    ) -> (MirValue | None);

    def object_compare(
        name: str, left: MirValue, right: MirValue, site: uni.UniNode
    ) -> MirValue;

    def dict_pairwise_eq(left: MirValue, right: MirValue) -> MirValue;
    def user_eq_elem(t: MirType) -> bool;
    def structural_elem(t: MirType) -> bool;
    def list_scan(
        lst: MirValue, item: MirValue, mode: str, site: uni.UniNode
    ) -> MirValue;

    def list_pairwise_eq(left: MirValue, right: MirValue) -> MirValue;
    def lower_for_container(nd: uni.InForStmt, holder: MirValue);
    def lower_delete(nd: uni.DeleteStmt);
    def unbind_local(target: uni.Expr) -> bool;
    def module_archetypes -> list[uni.Archetype];
    def arch_of_type(t: (TypeBase | None)) -> (uni.Archetype | None);
    def object_def(arch: uni.Archetype) -> MirObjectDef;
    def object_type(arch: uni.Archetype) -> MirType;
    def declared_field_type(decl: (uni.UniNode | None)) -> (TypeBase | None);
    def arch_methods(arch: uni.Archetype) -> list[uni.Ability];
    def lineage(arch: uni.Archetype) -> list[uni.Archetype];
    def find_method(arch: uni.Archetype, name: str) -> (uni.Ability | None);
    def method_symbol(arch: uni.Archetype, name: str) -> str;
    def foreign_method_decl(method: uni.Ability) -> (MirDecl | None);
    def owner_archetype(nd: uni.UniNode) -> (uni.Archetype | None);
    def live_unit(path: str) -> (uni.Module | None);
    def live_member(nd: uni.Ability) -> uni.Ability;
    def note_lineage(arch: uni.Archetype, obj_def: MirObjectDef);
    def foreign_static_decl(method: uni.Ability) -> (MirDecl | None);
    def method_decl_of(method: uni.Ability) -> (MirDecl | None);
    def holder_arch(expr: uni.Expr) -> (uni.Archetype | None);
    def settle_slots;
    def slot_root(arch: uni.Archetype, name: str) -> (MirDecl | None);
    def slot_adapter(decl: MirDecl, base: MirDecl) -> (MirFunction | None);
    def accessor_on(
        arch: uni.Archetype, name: str, kind: str, nd: uni.UniNode
    ) -> (tuple[uni.Archetype, MirDecl] | None);

    def union_accessor_get(nd: uni.AtomTrailer) -> (MirValue | None);
    def union_accessor_set(target: uni.AtomTrailer, nd: uni.Assignment) -> bool;
    def ref_word_side(value: MirValue) -> bool;
    def ref_word(value: MirValue) -> MirValue;
    def any_number(value: MirValue, whole: bool, site: uni.UniNode) -> MirValue;
    def foreign_accessor_decl(var: uni.HasVar, acc: uni.Ability) -> (MirDecl | None);
    def declare_archetype(arch: uni.Archetype);
    def special_methods(arch: uni.Archetype) -> dict[str, uni.Ability];
    def declare_specials(arch: uni.Archetype, self_type: MirType);
    def accessor_sig(acc: uni.Ability) -> (uni.FuncSignature | None);
    def declare_accessors(arch: uni.Archetype, self_type: MirType);
    def decl_label(decl: MirDecl) -> str;
    def refusal_key(decl: MirDecl) -> str;
    def member_owner(member: uni.Name) -> (uni.Archetype | None);
    def union_archetypes(t: (TypeBase | None)) -> list[uni.Archetype];
    def union_method_owner(
        nd: uni.FuncCall, receiver: uni.Expr
    ) -> (uni.Archetype | None);

    def is_class_operand(nd: (uni.UniNode | None)) -> bool;
    def checked_cross_cast(
        value: MirValue, to: MirType, site: uni.UniNode
    ) -> MirValue;

    def member_test(
        held: MirValue, view: MirValue, arch: uni.Archetype, site: uni.UniNode
    ) -> MirValue;

    def exact_class_test(
        named: MirValue, classes: list[str], site: uni.UniNode
    ) -> MirValue;

    def layout_registries(name: str) -> list[LayoutRegistry];
    def runtime_classes(target: str, seen_from: str) -> list[str];
    def slot_groups(
        target: str, seen_from: str, name: str, index: int, method: bool
    ) -> dict[int, list[str]];

    def arch_named(name: str, site: uni.UniNode) -> uni.Archetype;
    def union_field_place(
        holder: MirValue, members: list[uni.Archetype], name: str, site: uni.UniNode
    ) -> MirValue;

    def condition_only(nd: uni.Expr) -> bool;
    def union_field_read(nd: uni.AtomTrailer) -> (MirValue | None);
    def accessor_of(
        nd: uni.AtomTrailer, kind: str
    ) -> (tuple[uni.Archetype, MirDecl] | None);

    def accessor_get(nd: uni.AtomTrailer) -> (MirValue | None);
    def accessor_store(target: uni.AtomTrailer, value: MirValue) -> bool;
    def accessor_set(target: uni.AtomTrailer, nd: uni.Assignment) -> bool;
    def lower_constructor(arch: uni.Archetype) -> (MirFunction | None);
    def lower_drop(obj_def: MirObjectDef, arch: uni.Archetype) -> MirFunction;
    def lower_drop_glue(obj_def: MirObjectDef) -> MirFunction;
    def drop_through_glue(held: MirValue) -> bool;
    def drop_hook(arch: uni.Archetype, raw: MirValue);
    def lower_trace(obj_def: MirObjectDef) -> MirFunction;
    def lower_text_thunk(
        obj_def: MirObjectDef, arch: uni.Archetype
    ) -> (MirFunction | None);

    def constructor_params(
        arch: uni.Archetype
    ) -> list[tuple[str, MirType, (uni.Expr | None)]];

    def object_call(
        nd: uni.FuncCall, arch: uni.Archetype, leading: int = 0
    ) -> MirValue;

    def construct(
        symbol: str,
        obj_def: MirObjectDef,
        owner: uni.Module,
        params: list[tuple[str, MirType, (uni.Expr | None)]],
        values: list[MirValue],
        nd: uni.FuncCall
    ) -> MirValue;

    def object_method(
        nd: uni.FuncCall, receiver: MirValue, arch: uni.Archetype, name: str
    ) -> (MirValue | None);

    def unbound_method(
        nd: uni.FuncCall, arch: uni.Archetype, name: str
    ) -> (MirValue | None);

    def method_decl(
        arch: uni.Archetype, method: uni.Ability, name: str, site: uni.UniNode
    ) -> MirDecl;

    def method_receiver(
        decl: MirDecl, arch: uni.Archetype, receiver: MirValue, site: uni.UniNode
    ) -> MirValue;

    def invoke_method(
        decl: MirDecl, arch: uni.Archetype, name: str, values: list[MirValue]
    ) -> MirValue;

    def field_place(
        holder: MirValue, arch: uni.Archetype, name: str, site: uni.UniNode
    ) -> MirValue;

    def isinstance_check(value: MirValue, arch: uni.Archetype) -> MirValue;
    def host_only_type(t: (TypeBase | None)) -> bool;
    def erased_class(t: ClassType) -> bool;
    def note_erasures(t: (TypeBase | None));
    def erased_slot(t: (TypeBase | None)) -> bool;
    def class_reference(nd: uni.Expr) -> (uni.Archetype | None);
    def class_value(arch: uni.Archetype) -> MirValue;
    def placeholder(t: MirType) -> MirValue;
    def ctor_arguments(
        nd: uni.FuncCall,
        label: str,
        params: list[tuple[str, MirType, (uni.Expr | None)]],
        leading: int = 0
    ) -> list[MirValue];

    def class_value_call(nd: uni.FuncCall, bound: uni.Archetype) -> MirValue;
    def class_bound(t: (TypeBase | None)) -> (uni.Archetype | None);
    def nearest_has_var(arch: uni.Archetype, name: str) -> (uni.HasVar | None);
    def default_thunk(expr: uni.Expr) -> (tuple[str, str, MirType] | None);
    def default_value(expr: uni.Expr, to: MirType) -> MirValue;
    def default_thunks(arch: uni.Archetype) -> list[MirFunction];
    def function_default_thunks -> list[MirFunction];
    def make_default_thunks(defaults: list[uni.Expr]) -> list[MirFunction];
    def class_entry(arch: uni.Archetype, bound: uni.Archetype) -> (MirFunction | None);
    def ctor_takes_mask(params: list[tuple[str, MirType, (uni.Expr | None)]]) -> bool;
    def ctor_default(
        value: MirValue, given: MirValue, index: int, fallback: uni.Expr
    ) -> MirValue;

    def class_of(value: MirValue, site: uni.UniNode) -> MirValue;
    def class_isinstance(value: MirValue, kind: MirValue) -> MirValue;
    def class_list_isinstance(value: MirValue, kinds: MirValue) -> MirValue;
    def lower_module_init -> (MirFunction | None);
    def lower_module_entry -> (MirFunction | None);
    def none_value -> MirValue;
    def opt_recast(value: MirValue, to: MirType, site: uni.UniNode) -> MirValue;
    def opt_wrap(value: MirValue, to: MirType) -> MirValue;
    def opt_present(value: MirValue) -> MirValue;
    def opt_get(value: MirValue) -> MirValue;
    def opt_unwrap_checked(
        value: MirValue, message: str, error: str = "TypeError"
    ) -> MirValue;

    def narrowed_load(value: MirValue, nd: uni.Expr) -> MirValue;
    def narrow_down(value: MirValue, nd: uni.Expr) -> MirValue;
    def optional_eq(left: MirValue, right: MirValue, site: uni.UniNode) -> MirValue;
    def lower_cast(nd: uni.CastExpr) -> MirValue;
    def none_cast_error(nd: uni.CastExpr) -> tuple[str, str];
    def opt_begin(
        value: MirValue, result: MirType
    ) -> tuple[MirValue, MirValue, MirBlock, MirBlock];

    def opt_switch(
        held: MirValue, present_value: MirValue, absent: MirBlock, done: MirBlock
    );

    def opt_end(held: MirValue, absent_value: MirValue, done: MirBlock) -> MirValue;
    def lower_tuple(nd: uni.TupleVal) -> MirValue;
    def tuple_get(value: MirValue, index: int) -> MirValue;
    def tuple_compare(
        op: str, name: str, left: MirValue, right: MirValue, site: uni.UniNode
    ) -> MirValue;

    def store_unpacked(target: uni.Expr, part: MirValue, site: uni.UniNode);
    def unpack_into(targets: list[uni.Expr], value: MirValue, site: uni.UniNode);
    def function_of(nd: uni.UniNode) -> (uni.UniNode | None);
    def names_within(nd: uni.UniNode) -> list[uni.Name];
    def captured_symbols(
        owner: uni.UniNode, body: Sequence[uni.UniNode]
    ) -> list[uni.Symbol];

    def prepare_cells(owner: uni.UniNode, body: Sequence[uni.UniNode]);
    def cell_of(sym_id: int) -> (MirValue | None);
    def cell_read(cell: MirValue, value_type: MirType) -> MirValue;
    def cell_write(
        cell: MirValue, value: MirValue, value_type: MirType, site: uni.UniNode
    );

    def lower_closure(
        owner: uni.UniNode,
        signature: (uni.FuncSignature | None),
        body: (uni.Expr | Sequence[uni.UniNode]),
        fn_type: MirType,
        label: str
    ) -> MirValue;

    def closure_call(nd: uni.FuncCall, callee: MirValue) -> MirValue;
    def callee_value(target: uni.Expr) -> MirValue;
    def function_value(decl: MirDecl, to: MirType) -> MirValue;
    def lower_try(nd: uni.TryStmt);
    def caught_state(frame: MirValue) -> tuple[MirValue, MirValue, MirValue];
    def flush_stdio;
    def lower_test(nd: uni.Test) -> (MirFunction | None);
    def lower_assert(nd: uni.AssertStmt);
    def raise_named(name: str, message_nd: (uni.UniNode | None), nd: uni.UniNode);
    def lower_raise(nd: uni.RaiseStmt);
    def leave_tries(loop_depth: int, run_finals: bool = True);
    def rearm_tries;
    def exception_matches(type_id: MirValue, clause: uni.Expr) -> MirValue;
    def exception_name(nd: uni.Expr) -> str;
    def exception_target(nd: uni.Expr) -> tuple[str, (uni.Archetype | None)];
    def is_exception_arch(arch: uni.Archetype) -> bool;
    def exception_ancestors(arch: uni.Archetype) -> list[int];
    def raise_object(
        value: MirValue, arch: uni.Archetype, site: uni.UniNode, dynamic: bool = False
    );

    def register_exception(arch: uni.Archetype);
    def exception_message(value: MirValue, arch: uni.Archetype) -> MirValue;
    def exception_text(value: MirValue, arch: uni.Archetype) -> MirValue;
    def exception_object(nd: (uni.FuncCall | None), arch: uni.Archetype) -> MirValue;
    def any_tag(t: MirType, site: uni.UniNode) -> int;
    def any_box(value: MirValue, site: uni.UniNode) -> MirValue;
    def any_make(tag: MirValue, payload: MirValue) -> MirValue;
    def any_none -> MirValue;
    def any_unbox(value: MirValue, to: MirType, site: uni.UniNode) -> MirValue;
    def any_to_box(value: MirValue, site: uni.UniNode) -> MirValue;
    def any_from_box(handle: MirValue) -> MirValue;
    def identity(left: MirValue, right: MirValue, site: uni.UniNode) -> MirValue;
    def bound_args(
        nd: uni.FuncCall, ab: uni.Ability, method: bool, leading: int = 0
    ) -> list[(uni.Expr | MirPacked | MirBound)];

    def super_call(nd: uni.FuncCall, name: str) -> MirValue;
    def object_operator(
        op: str,
        left: MirValue,
        right: MirValue,
        site: uni.UniNode,
        inplace: bool = False
    ) -> (MirValue | None);

    def object_eq(left: MirValue, right: MirValue, site: uni.UniNode) -> MirValue;
    def aug_arith(
        op: str, current: MirValue, value: MirValue, site: uni.UniNode
    ) -> MirValue;

    def foreign_function_decl(callee: uni.Ability, site: uni.UniNode) -> MirDecl;
    def list_repeat(items: MirValue, times: MirValue, site: uni.UniNode) -> MirValue;
    def object_alloc(
        arch: uni.Archetype, obj_def: MirObjectDef, self_type: MirType
    ) -> MirValue;

    def object_copy(value: MirValue, site: uni.UniNode) -> MirValue;
    def list_bounds(
        lst: MirValue, part: uni.Slice, site: uni.UniNode
    ) -> tuple[MirValue, MirValue, MirValue];

    def list_replace_range(
        lst: MirValue, part: uni.Slice, values: (MirValue | None), site: uni.UniNode
    );

    def list_delete_range(lst: MirValue, part: uni.Slice, site: uni.UniNode);
    def direct_method_call(
        nd: uni.FuncCall,
        holder: uni.Archetype,
        method: uni.Ability,
        receiver: MirValue,
        leading: int
    ) -> MirValue;

    def has_spread(nd: uni.FuncCall) -> bool;
    def spread_args(
        nd: uni.FuncCall, ab: uni.Ability, sig: uni.FuncSignature, method: bool
    ) -> list[(uni.Expr | MirPacked | MirBound)];

    def bind_from_spreads(
        pv: uni.ParamVar,
        given: (MirBound | None),
        spreads: list[MirBound],
        matched: MirValue,
        ab: uni.Ability,
        nd: uni.FuncCall
    ) -> MirBound;

    def bind_by_name(
        ab: uni.Ability,
        pv: uni.ParamVar,
        named: dict[str, uni.Expr],
        keyword_ok: bool,
        nd: uni.FuncCall
    ) -> (uni.Expr | MirBound);

    def bound_value(
        arg: (uni.Expr | MirPacked | MirBound), ptype: MirType
    ) -> MirValue;

    def constant_default(value: (uni.Expr | None)) -> bool;
    def builtin_value(nd: uni.FuncCall, name: str) -> (MirValue | None);
    def identity_of(value: MirValue, site: uni.UniNode) -> MirValue;
    def list_concat(left: MirValue, right: MirValue) -> MirValue;
    def str_subscript(nd: uni.AtomTrailer) -> (MirValue | None);
    def sys_attr(nd: uni.AtomTrailer) -> (MirValue | None);
    def extern_global(symbol: str, t: MirType) -> MirValue;
    def input_call(nd: uni.FuncCall) -> MirValue;
    def sys_exit(nd: uni.FuncCall) -> MirValue;
    def str_enum_int(nd: uni.FuncCall) -> (MirValue | None);
    def rc_intrinsic(name: str) -> (MirValue | None);
    def mark_threaded;
    def flow_threaded -> bool;
    def lower_concurrent(nd: uni.ConcurrentExpr) -> MirValue;
    def flow_thunk(decl: MirDecl) -> str;
    def task_store(base: MirValue, offset: int, value: MirValue);
    def pipe_call(nd: uni.BinaryExpr) -> MirValue;
    def cstr_of(value: MirValue) -> MirValue;
    def open_call(nd: uni.FuncCall) -> MirValue;
    def file_method(
        handle: MirValue, name: str, nd: uni.FuncCall
    ) -> (MirValue | None);

    def osp_call(name: str, args: list[MirValue]) -> MirValue;
    def osp_hold(value: MirValue) -> MirValue;
    def osp_layout(arch: (uni.Archetype | None)) -> (ArchetypeLayout | None);
    def osp_arch_of(nd: (uni.UniNode | None)) -> (uni.Archetype | None);
    def osp_tag(arch: uni.Archetype) -> int;
    def osp_type_tag(nd: (uni.Expr | None), site: uni.UniNode) -> int;
    def osp_handle(value: MirValue, site: uni.UniNode) -> MirValue;
    def osp_handles(value: MirValue, site: uni.UniNode) -> MirValue;
    def osp_one(handle: MirValue) -> MirValue;
    def osp_typed(handles: MirValue, site: uni.Expr) -> MirValue;
    def osp_header_fields(made: MirObjectDef, layout: ArchetypeLayout);
    def osp_header(this: MirValue, obj_def: MirObjectDef);
    def osp_drop(obj_def: MirObjectDef, raw: MirValue);
    def osp_bases(arch: uni.Archetype) -> list[uni.Archetype];
    def osp_model_of -> OspModel;
    def declare_osp_abilities(arch: uni.Archetype);
    def lower_ability(decl: MirDecl) -> (MirFunction | None);
    def osp_thunk(owner: uni.Archetype, ability: str) -> str;
    def lower_osp_module;
    def osp_special(nd: uni.SpecialVarRef) -> MirValue;
    def osp_leave;
    def lower_osp_stmt(nd: uni.UniNode);
    def lower_osp_binary(nd: uni.BinaryExpr) -> MirValue;
    def lower_spawn(nd: uni.BinaryExpr) -> MirValue;
    def lower_connect(nd: uni.BinaryExpr, co: uni.ConnectOp) -> MirValue;
    def osp_root_anchor(nd: uni.BinaryExpr, co: uni.ConnectOp) -> MirValue;
    def osp_assign_values(
        co: uni.ConnectOp, edge_arch: (uni.Archetype | None), site: uni.UniNode
    ) -> dict[str, MirValue];

    def osp_edge_object(
        co: uni.ConnectOp,
        edge_arch: (uni.Archetype | None),
        values: dict[str, MirValue],
        site: uni.UniNode
    ) -> MirValue;

    def lower_disconnect(nd: uni.BinaryExpr, dop: uni.DisconnectOp) -> MirValue;
    def osp_list_operand(nd: uni.Expr) -> bool;
    def lower_edge_handles(nd: uni.EdgeRefTrailer) -> MirValue;
    def lower_osp_filter(nd: uni.AtomTrailer) -> MirValue;
    def osp_filter_arch(
        f: uni.FilterCompr, holder: (uni.Expr | None)
    ) -> (uni.Archetype | None);

    def osp_type_pred(tag: int) -> MirValue;
    def osp_field_pred(
        arch: uni.Archetype, compares: Sequence[uni.Expr], site: uni.UniNode
    ) -> MirValue;

    def osp_predicate(label: str) -> tuple[MirFunction, MirFnState];
    def osp_closure(
        symbol: str,
        code: MirType,
        captures: list[tuple[MirValue, MirType]],
        to: MirType
    ) -> MirValue;

    def osp_delete(target: uni.Expr) -> bool;
    def lower_jid(nd: uni.FuncCall) -> MirValue;
    def call_rt(name: str, args: list[MirValue]) -> MirValue;
    def text_const(text: str) -> tuple[MirValue, MirValue];
    def as_text(value: MirValue) -> MirValue;
    def owned_text(handle: MirValue) -> MirValue;
    def text_position(value: MirValue, to: MirType) -> (MirValue | None);
    def text_operands(left: MirValue, right: MirValue) -> tuple[MirValue, MirValue];
    def is_text(value: MirValue) -> bool;
    def is_byte_seq(value: MirValue) -> bool;
    def present(arg: (uni.Expr | None)) -> bool;
    def bind_args(nd: uni.FuncCall, names: list[str]) -> list[(uni.Expr | None)];
    def text_arg(arg: (uni.Expr | None), site: uni.UniNode) -> MirValue;
    def int_arg(arg: (uni.Expr | None), fallback: int) -> MirValue;
    def bool_arg(arg: (uni.Expr | None), fallback: bool) -> MirValue;
    def codec_arg(
        arg: (uni.Expr | None), table: dict[str, int], site: uni.UniNode
    ) -> MirValue;

    def codec_failure(exception: str) -> MirValue;
    def literal_text(nd: (uni.UniNode | None)) -> (str | None);
    def typed_handle(handle: MirValue, nd: uni.Expr) -> MirValue;
    def text_method(
        receiver: MirValue, name: str, nd: uni.FuncCall
    ) -> (MirValue | None);

    def text_partition(text: MirValue, sep: MirValue, reverse: bool) -> MirValue;
    def slice_operands(
        part: uni.Slice
    ) -> tuple[MirValue, MirValue, MirValue, MirValue];

    def text_subscript(
        holder: MirValue, slice: uni.IndexSlice, site: uni.UniNode
    ) -> MirValue;

    def text_contains(item: MirValue, holder: MirValue, site: uni.UniNode) -> MirValue;
    def text_binary(
        op: str, left: MirValue, right: MirValue, site: uni.UniNode
    ) -> (MirValue | None);

    def percent_format(template: str, values: MirValue, site: uni.UniNode) -> MirValue;
    def lower_for_text(nd: uni.InForStmt, holder: MirValue);
    def bytes_literal(nd: (uni.String | uni.MultiString)) -> (MirValue | None);
    def byte_parts(held: MirValue) -> tuple[MirValue, MirValue];
    def byte_at(data: MirValue, index: MirValue) -> MirValue;
    def byte_len(value: MirValue) -> MirValue;
    def to_bytearray(value: MirValue) -> MirValue;
    def byte_index(size: MirValue, index_nd: uni.Expr, message: str) -> MirValue;
    def bytes_subscript(
        held: MirValue, slice: uni.IndexSlice, site: uni.UniNode
    ) -> MirValue;

    def bytearray_store(
        target: uni.AtomTrailer, value_nd: uni.Expr, site: uni.UniNode
    );

    def optional_bytes_arg(
        arg: (uni.Expr | None), site: uni.UniNode
    ) -> tuple[MirValue, MirValue, MirValue];

    def bytes_arg(
        arg: (uni.Expr | None), site: uni.UniNode
    ) -> tuple[MirValue, MirValue];

    def bytes_method(held: MirValue, name: str, nd: uni.FuncCall) -> (MirValue | None);
    def str_value(value: MirValue, site: uni.UniNode) -> MirValue;
    def repr_of(value: MirValue, site: uni.UniNode) -> MirValue;
    def ascii_of(value: MirValue, site: uni.UniNode) -> MirValue;
    def object_text(
        value: MirValue, method: str, site: uni.UniNode, dispatch: bool = True
    ) -> MirValue;

    def subclass_text(
        value: MirValue, method: str, carriers: list[uni.Archetype], site: uni.UniNode
    ) -> MirValue;

    def text_fn(value_type: MirType, site: uni.UniNode) -> str;
    def sb_text(sb: MirValue, text: str);
    def sb_value(sb: MirValue, text: MirValue);
    def dict_part(d: MirValue, at: MirValue, part: MirType, is_key: bool) -> MirValue;
    def container_repr_body(param: MirValue, site: uni.UniNode);
    def object_repr_body(param: MirValue, site: uni.UniNode);
    def fstring_value(nd: uni.FString) -> MirValue;
    def str_format(template: str, nd: uni.FuncCall) -> MirValue;
    def format_value(
        value: MirValue, spec: (MirValue | None), site: uni.UniNode
    ) -> MirValue;

    def type_label(t: MirType) -> str;
    def print_call(nd: uni.FuncCall) -> MirValue;
    def stream_fd(nd: uni.Expr) -> int;
    def write_value(value: MirValue, fd: int, site: uni.UniNode);
    def text_builtin(nd: uni.FuncCall, name: str) -> (MirValue | None);
    def text_bytes(value: MirValue) -> tuple[MirValue, MirValue];
    def bytes_of_ints(source: MirValue, nd: uni.UniNode) -> MirValue;
    def bytes_from(args: list[uni.Expr], nd: uni.FuncCall) -> MirValue;
    def absolute(value: MirValue, site: uni.UniNode) -> MirValue;
    def extreme(
        first: MirValue, rest: list[uni.Expr], name: str, site: uni.UniNode
    ) -> MirValue;

    def rounded(
        value: MirValue, digits_nd: (uni.Expr | None), site: uni.UniNode
    ) -> MirValue;

    def divmod_value(left: MirValue, right: MirValue, site: uni.UniNode) -> MirValue;
    def power(left: MirValue, right: MirValue, site: uni.UniNode) -> MirValue;
    def pow_result(site: uni.UniNode) -> MirType;
    def hash_value(value: MirValue, site: uni.UniNode) -> MirValue;
    def emit_value(
        op: MirOp,
        type: MirType,
        operands: list[MirValue],
        sub: str = "",
        callee: str = "",
        int_value: int = 0,
        str_value: str = ""
    ) -> MirValue;

    def is_generator(ab: uni.Ability) -> bool;
    def ability_sig(ab: uni.Ability) -> (uni.FuncSignature | None);
    def lower_generator(decl: MirDecl) -> (MirFunction | None);
    def alias_twins(ab: uni.Ability, sig: uni.FuncSignature, skip_self: bool);
    def lower_yield(nd: uni.YieldExpr);
    def yield_value(value: MirValue, site: uni.UniNode);
    def yield_expression(nd: uni.YieldExpr) -> MirValue;
    def runtime_value(name: str, args: list[MirValue]) -> MirValue;
    def iter_open(value: MirValue, site: uni.UniNode) -> MirIterCursor;
    def iter_step(cursor: MirIterCursor, body: MirBlock, done: MirBlock) -> MirValue;
    def iter_advance(it: MirValue, out: MirValue) -> MirValue;
    def iter_throw(
        it: MirValue,
        out: MirValue,
        origin: MirValue,
        type_id: MirValue,
        message: MirValue
    ) -> MirValue;

    def raise_pending;
    def gen_close(it: MirValue) -> MirValue;
    def element_from_bits(bits: MirValue, elem: MirType) -> MirValue;
    def iter_value(value: MirValue, site: uni.UniNode) -> MirValue;
    def iter_coerce(value: MirValue, to: MirType, site: uni.UniNode) -> MirValue;
    def builtin_source(nd: uni.UniNode, names: list[str]) -> str;
    def is_special_source(nd: uni.Expr) -> bool;
    def open_sources(
        collection: uni.Expr
    ) -> tuple[list[MirIterCursor], (MirValue | None)];

    def step_sources(
        cursors: list[MirIterCursor], counter: (MirValue | None), done: MirBlock
    ) -> list[MirValue];

    def bind_values(target: uni.Expr, values: list[MirValue], site: uni.UniNode);
    def bind_target(target: uni.Expr, value: MirValue);
    def lower_for_sources(nd: uni.InForStmt, holder: (MirValue | None));
    def open_cursor(source: uni.Expr) -> MirIterCursor;
    def step_parts(
        parts: list[MirIterCursor],
        counter: (MirValue | None),
        body: MirBlock,
        done: MirBlock
    ) -> list[MirValue];

    def step_group(cursor: MirIterCursor, body: MirBlock, done: MirBlock) -> MirValue;
    def step_filter(cursor: MirIterCursor, body: MirBlock, done: MirBlock) -> MirValue;
    def step_user(cursor: MirIterCursor, body: MirBlock, done: MirBlock) -> MirValue;
    def null_ok_subclass_attr(nd: uni.AtomTrailer) -> (MirValue | None);
    def bound_method_value(nd: uni.AtomTrailer) -> (MirValue | None);
    def closure_adapter(value: MirValue, to: MirType, site: uni.UniNode) -> MirValue;
    def call_closure(
        callee: MirValue, values: list[MirValue], site: uni.UniNode
    ) -> MirValue;

    def iter_adapter(
        kind: str, elem: MirType, inputs: list[MirValue], site: uni.UniNode
    ) -> MirValue;

    def adapter_cursor(
        kind: str, elem: MirType, inputs: list[MirValue], site: uni.UniNode
    ) -> MirIterCursor;

    def adapter_value(nd: uni.FuncCall, name: str) -> MirValue;
    def adapter_callee(arg: uni.Expr, name: str) -> MirValue;
    def map_cursor(
        callee: MirValue, parts: list[MirIterCursor], site: uni.UniNode
    ) -> MirIterCursor;

    def filter_cursor(
        callee: (MirValue | None), part: MirIterCursor, site: uni.UniNode
    ) -> MirIterCursor;

    def user_cursor(value: MirValue, site: uni.UniNode) -> (MirIterCursor | None);
    def user_next(it: MirValue, site: uni.UniNode) -> MirIterCursor;
    def user_method(
        receiver: MirValue, name: str, site: uni.UniNode
    ) -> (MirValue | None);

    def tuple_items(value: MirValue, site: uni.UniNode) -> MirValue;
    def tuple_elem(value: MirValue, site: uni.UniNode) -> MirType;
    def tuple_cursor(value: MirValue, elem: MirType) -> MirIterCursor;
    def step_tuple(cursor: MirIterCursor, body: MirBlock, done: MirBlock) -> MirValue;
    def split_args(nd: uni.FuncCall) -> tuple[list[uni.Expr], dict[str, uni.Expr]];
    def iter_builtin(nd: uni.FuncCall, name: str) -> (MirValue | None);
    def builtin_next(nd: uni.FuncCall, args: list[uni.Expr]) -> MirValue;
    def builtin_sorted(
        nd: uni.FuncCall, args: list[uni.Expr], named: dict[str, uni.Expr]
    ) -> MirValue;

    def builtin_fold(
        nd: uni.FuncCall, name: str, source: uni.Expr, start: (uni.Expr | None) = None
    ) -> MirValue;

    def materialize_source(
        source: uni.Expr, elem: MirType, site: uni.UniNode
    ) -> MirValue;

    def drain(value: MirValue, elem: MirType, site: uni.UniNode) -> MirValue;
    def lower_comprehension(nd: (uni.ListCompr | uni.DictCompr)) -> MirValue;
    def compr_level(
        nd: (uni.ListCompr | uni.DictCompr),
        levels: list[uni.InnerCompr],
        index: int,
        made: MirValue
    );

    def compr_emit(nd: (uni.ListCompr | uni.DictCompr), made: MirValue);
    def is_absent(value: MirValue) -> MirValue;
    def value_truthy(value: MirValue, site: uni.UniNode) -> (MirValue | None);
    def hook_call(value: MirValue, arch: uni.Archetype, decl: MirDecl) -> MirValue;
    def any_to_str(value: MirValue, site: uni.UniNode) -> MirValue;
    def any_text(helper: str, value: MirValue) -> MirValue;
    def any_parts(value: MirValue) -> list[MirValue];
    def any_compare(
        name: str, left: MirValue, right: MirValue, site: uni.UniNode
    ) -> MirValue;

    def any_contains(item: MirValue, holder: MirValue, site: uni.UniNode) -> MirValue;
    def any_iter(value: MirValue) -> MirValue;
    def any_arith(
        op: str, left: MirValue, right: MirValue, site: uni.UniNode
    ) -> MirValue;

    def value_comparable(left: MirValue, right: MirValue, name: str) -> bool;
    def abstract_names(item: uni.Expr) -> list[str];
    def any_bind(held: MirValue, to: MirType, site: uni.UniNode) -> MirValue;
    def bind_family(t: MirType, site: uni.UniNode) -> int;
    def narrow(value: MirValue, nd: uni.Name) -> MirValue;
    def target_archetype(target: uni.Expr) -> (uni.Archetype | None);
    def isinstance_value(
        subject: uni.Expr, target: uni.Expr, site: uni.UniNode
    ) -> MirValue;

    def isinstance_test(
        value: MirValue, items: list[uni.Expr], site: uni.UniNode
    ) -> MirValue;

    def enum_box(value: MirValue, site: uni.UniNode) -> MirValue;
    def osp_class_tag(nd: uni.Expr) -> (MirValue | None);
    def osp_class_tag_ok(nd: uni.Expr) -> bool;
    def lower_dynamic_connect(nd: uni.BinaryExpr, co: uni.ConnectOp) -> MirValue;
    def default_entry(arch: uni.Archetype) -> (MirFunction | None);
    def is_walker_ref(nd: uni.Expr) -> bool;
    def lower_osp_walker_spawn(
        nd: uni.BinaryExpr, walker_nd: uni.Expr, place_nd: uni.Expr
    ) -> MirValue;

    def enum_desc(t: MirType, site: uni.UniNode) -> MirValue;
    def creation_kind(elem: MirType, site: uni.UniNode) -> MirValue;
    def enum_text_thunk(t: MirType, site: uni.UniNode) -> str;
    def headerless_type_value(value: MirValue, site: uni.UniNode) -> MirValue;
    def store_text_result(base: MirValue, text: MirValue);
    def refuse_opaque_abc(item: uni.Expr, arch: uni.Archetype, site: uni.UniNode);
    def refuse_partial_mro(value: MirValue, item: uni.Expr, site: uni.UniNode);
    def caught_type(subject: uni.Expr) -> (MirValue | None);
    def caught_class(caught: tuple[MirValue, MirValue, MirValue]) -> MirValue;
    def type_call_name(item: uni.Expr) -> (str | None);
    def any_isinstance(
        value: MirValue, target: uni.Expr, site: uni.UniNode
    ) -> MirValue;

    def value_builtin(nd: uni.FuncCall, name: str) -> (MirValue | None);
    def type_value(value: MirValue, site: uni.UniNode) -> MirValue;
    def class_name_str(value: MirValue) -> MirValue;
    def is_template(ab: uni.Ability) -> bool;
    def template_of(ab: uni.Ability) -> bool;
    def stdlib_module(expr: uni.UniNode) -> (uni.Module | None);
    def module_member(unit: uni.Module, name: str) -> (uni.UniNode | None);
    def getattr_member(call: uni.FuncCall) -> (tuple[uni.Module, str] | None);
    def alias_scope(nd: uni.UniNode) -> (uni.UniNode | None);
    def getattr_alias(sym: (uni.Symbol | None)) -> (tuple[uni.Module, str] | None);
    def alias_call(nd: uni.FuncCall) -> (MirValue | None);
    def stdlib_call(nd: uni.FuncCall, target: uni.AtomTrailer) -> (MirValue | None);
    def stdlib_attr(nd: uni.AtomTrailer) -> (MirValue | None);
    def class_attr_entry(
        arch: uni.Archetype, name: str
    ) -> (tuple[uni.Archetype, uni.Name, uni.Expr] | None);

    def arch_is_enum(arch: uni.Archetype) -> bool;
    def class_constant(arch: uni.Archetype, name: str) -> (uni.Expr | None);
    def class_global(
        holder: uni.Archetype, target: uni.Name, value: uni.Expr
    ) -> MirGlobal;

    def declare_class_globals;
    def class_global_init(held: MirGlobal, label: str, value: uni.Expr) -> None;
    def class_value_of(
        arch: uni.Archetype, name: str, wanted: MirType, site: uni.UniNode
    ) -> (MirValue | None);

    def class_dispatch(
        arch: uni.Archetype,
        name: str,
        wanted: MirType,
        site: uni.UniNode,
        matches: Callable[[uni.Archetype], MirValue]
    ) -> (MirValue | None);

    def class_attr(nd: uni.AtomTrailer) -> (MirValue | None);
    def constant_value(value: (uni.Expr | None)) -> bool;
    def subclass_archetypes(arch: uni.Archetype) -> list[uni.Archetype];
    def instance_class_attr(nd: uni.AtomTrailer) -> (MirValue | None);
    def mentions_typevar(t: (TypeBase | None)) -> bool;
    def resolved(t: (TypeBase | None)) -> (TypeBase | None);
    def unify(
        declared: (TypeBase | None),
        actual: (TypeBase | None),
        solution: dict[str, TypeBase]
    );

    def type_param_names(ab: uni.Ability) -> list[str];
    def generic_call(
        nd: uni.FuncCall,
        ab: uni.Ability,
        receiver: (MirValue | None),
        owner: (uni.Archetype | None)
    ) -> MirValue;

    def declare_instance(
        ab: uni.Ability,
        env: dict[str, TypeBase],
        symbol: str,
        owner: (uni.Archetype | None)
    ) -> MirDecl;

    def lower_instances;
    def body_types(ab: uni.Ability);
    def enum_layout(t: (TypeBase | None), site: uni.UniNode) -> EnumLayout;
    def enum_layout_of(value_type: MirType, site: uni.UniNode) -> EnumLayout;
    def enum_payload(layout: EnumLayout, member: EnumMemberLayout) -> int;
    def is_enum_class(nd: uni.UniNode) -> bool;
    def attr_special(nd: uni.AtomTrailer) -> (MirValue | None);
    def enum_member(nd: uni.AtomTrailer) -> (MirValue | None);
    def enum_attr(value: MirValue, name: str, site: uni.AtomTrailer) -> MirValue;
    def enum_select(value: MirValue, layout: EnumLayout, texts: list[str]) -> MirValue;
    def enum_str(value: MirValue, site: uni.UniNode) -> MirValue;
    def compare_special(
        op: str, left: MirValue, right: MirValue, site: uni.UniNode
    ) -> (MirValue | None);

    def enum_is_text(t: MirType) -> bool;
    def enum_self_type(decl: (uni.Archetype | uni.Enum)) -> (MirType | None);
    def declare_enum_methods(decl: (uni.Archetype | uni.Enum), self_type: MirType);
    def foreign_enum_method(enum_type: MirType, name: str) -> (MirDecl | None);
    def enum_method_call(
        nd: uni.FuncCall, receiver: MirValue, name: str
    ) -> (MirValue | None);

    def enum_as_int(value: MirValue, site: uni.UniNode) -> MirValue;
    def enum_coerce(value: MirValue, to: MirType, site: uni.UniNode) -> MirValue;
    def enum_call(nd: uni.FuncCall) -> (MirValue | None);
    def enum_cursor(collection: uni.Expr) -> MirIterCursor;
    def lower_with(nd: uni.WithStmt);
    def with_items(
        items: list[uni.ExprAsItem], index: int, body: Sequence[uni.CodeBlockStmt]
    );

    def with_guarded(
        items: list[uni.ExprAsItem],
        index: int,
        body: Sequence[uni.CodeBlockStmt],
        exit_action: MirWithExit
    );

    def with_generator(
        items: list[uni.ExprAsItem], index: int, body: Sequence[uni.CodeBlockStmt]
    );

    def call_exit(decl: MirDecl, held: MirValue, site: uni.UniNode) -> MirValue;
    def none_arg(ptype: MirType, site: uni.UniNode) -> MirValue;
    def guard_open -> tuple[MirValue, MirBlock];
    def guard_caught(frame: MirValue) -> tuple[MirValue, MirValue, MirValue];
    def run_with_exit(exit_action: MirWithExit) -> MirValue;
    def jumps_out(body: Sequence[uni.UniNode]) -> bool;
    def lower_match(nd: uni.MatchStmt);
    def lower_switch(nd: uni.SwitchStmt);
    def match_test(
        pat: uni.MatchPattern, subject: MirValue, fail: MirBlock, site: uni.UniNode
    );

    def match_star_sequence(
        pat: uni.MatchSequence, at: int, subject: MirValue, fail: MirBlock
    );

    def match_arch(pat: uni.MatchArch, subject: MirValue, fail: MirBlock);
    def branch_unless(cond: MirValue, fail: MirBlock);
    def python_call(nd: uni.FuncCall) -> (MirValue | None);
    def bridge_call(
        symbol: str, name: str, args: list[MirValue], ret: MirType, site: uni.UniNode
    ) -> MirValue;

    def bridge_type(t: MirType, site: uni.UniNode) -> MirType;
    def bridge_type_name(t: MirType) -> str;
    def bridge_symbol(symbol: str);
    def python_base_of(arch: uni.Archetype) -> (str | None);
    def param_nodes(sig: uni.FuncSignature, skip_self: bool) -> list[uni.ParamVar];
}
