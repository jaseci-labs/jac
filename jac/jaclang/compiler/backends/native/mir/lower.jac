import os;

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
         "RSHIFT_EQ": "RSHIFT"
     },
     SHIFT_MESSAGE: str = "shift count out of range",
     NEGATIVE_SHIFT_MESSAGE: str = "negative shift count",
     RANGE_STEP_MESSAGE: str = "range() arg 3 must not be zero",
     CLOSURE_CELLS_OFFSET: int = 16,
     KIND_INT: int = 0,
     KIND_FLOAT: int = 1,
     KIND_BOOL: int = 2,
     KIND_STR: int = 3,
     KIND_REF: int = 4,
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
     OSP_DIR_IN: int = 1,
     OSP_DIR_OUT: int = 2,
     OSP_DIR_ANY: int = 3,
     OSP_TAG_OFFSET: int = 8,
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
     MEMORY_ORDERS: list[str] = [
         "monotonic", "acquire", "acquire", "release", "acq_rel", "seq_cst"
     ],
     COMPARE_OPERATORS: dict[str, str] = {
         "EE": "eq",
         "NE": "ne",
         "LT": "lt",
         "GT": "gt",
         "LTE": "le",
         "GTE": "ge"
     };

obj MirLoopTarget {
    has head: MirBlock,
        after: MirBlock;
}

obj MirFnState {
    has fn: MirFunction,
        b: MirBuilder,
        self_value: (MirValue | None) = None,
        captured: dict[int, MirValue] = {},
        cell_types: dict[int, MirType] = {},
        env_cells: dict[int, int] = {},
        env: (MirValue | None) = None,
        locals: dict[int, MirValue] = {},
        loops: list[MirLoopTarget] = [],
        caught: list[tuple[MirValue, MirValue, MirValue]] = [],
        specials: dict[str, MirValue] = {};
}

obj MirDecl {
    has ability: uni.Ability,
        symbol: str,
        ret: MirType,
        params: list[MirType] = [],
        self_type: (MirType | None) = None,
        owner: (uni.Archetype | None) = None,
        event: str = "";
}

obj MirLowering {
    has prog: JacProgram,
        module: uni.Module,
        mir: MirModule,
        decls: dict[int, MirDecl] = {},
        decl_syms: dict[int, int] = {},
        archetypes: dict[str, uni.Archetype] = {},
        c_struct_sites: dict[str, str] = {},
        trace_pairs: list[tuple[str, str]] = [],
        deferred_globals: list[tuple[MirGlobal, uni.Expr]] = [],
        nested: list[MirFunction] = [],
        adapters: dict[str, str] = {},
        fn_values: dict[int, MirDecl] = {},
        order: list[int] = [],
        refusals: dict[str, list[NativeRefusal]] = {},
        state: (MirFnState | None) = None,
        osp_model: (OspModel | None) = None,
        osp_setup: str = "",
        osp_thunks: dict[str, str] = {},
        osp_preds: int = 0;

    def lower -> MirModule;
    def settle;
    def callees_of(fn: MirFunction) -> list[str];
    def module_abilities -> list[uni.Ability];
    def declare(ab: uni.Ability);
    def symbol_of(ab: uni.Ability) -> str;
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
    def lower_stmt(nd: uni.UniNode);
    def lower_assignment(nd: uni.Assignment);
    def store_name(target: uni.Name, value: MirValue);
    def local_slot(sym: (uni.Symbol | None), site: uni.UniNode) -> MirValue;
    def lower_return(nd: uni.ReturnStmt);
    def lower_if(nd: (uni.IfStmt | uni.ElseIf));
    def lower_else(nd: (uni.ElseStmt | uni.ElseIf | None), done: MirBlock);
    def lower_while(nd: uni.WhileStmt);
    def lower_ctrl(nd: uni.CtrlStmt);
    def lower_for(nd: uni.InForStmt);
    def lower_range_for(nd: uni.InForStmt, bounds: list[uni.Expr]);
    def lower_if_else_expr(nd: uni.IfElseExpr) -> MirValue;
    def to_str(value: MirValue, site: uni.UniNode) -> MirValue;
    def lower_fstring(nd: uni.FString) -> MirValue;
    def lower_expr(nd: uni.UniNode) -> MirValue;
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
    def coerce(value: MirValue, to: MirType, site: uni.UniNode) -> MirValue;
    def unify_numeric(
        left: MirValue, right: MirValue, site: uni.UniNode
    ) -> tuple[MirValue, MirValue];

    def raise_if(cond: MirValue, exception: str, message: str);
    def type_of(
        t: (TypeBase | None), position: MirPosition, site: uni.UniNode
    ) -> MirType;

    def ensure_c_types(t: (TypeBase | None));
    def arch_fields(arch: uni.Archetype) -> list[uni.HasVar];
    def lower_place(nd: uni.UniNode) -> MirValue;
    def place_elem(place: MirValue) -> MirType;
    def lower_trailer(nd: uni.AtomTrailer) -> MirValue;
    def call_name(nd: uni.FuncCall) -> str;
    def c_call(nd: uni.FuncCall, callee: uni.Ability) -> MirValue;
    def import_call(nd: uni.FuncCall, callee: uni.Ability) -> (MirValue | None);
    def intrinsic_call(nd: uni.FuncCall, name: str) -> MirValue;
    def intrinsic_operand(arg: uni.Expr, spec: str) -> MirValue;
    def memory_order(nd: uni.FuncCall, arg: uni.Expr, kind: str) -> str;
    def type_call(nd: uni.FuncCall) -> (MirValue | None);
    def method_call(nd: uni.FuncCall, target: uni.AtomTrailer) -> (MirValue | None);
    def call_args(nd: uni.FuncCall) -> list[uni.Expr];
    def coerce_place(place: MirValue) -> MirValue;
    def global_place(nd: uni.Name) -> (MirValue | None);
    def global_declaration(sym: uni.Symbol) -> (uni.Assignment | None);
    def runtime(name: str, args: list[MirValue]) -> (MirValue | None);
    def temp_slot(type: MirType) -> MirValue;
    def spill(value: MirValue) -> MirValue;
    def lower_string(nd: (uni.String | uni.MultiString)) -> MirValue;
    def str_concat(left: MirValue, right: MirValue) -> MirValue;
    def str_compare(op: str, left: MirValue, right: MirValue) -> MirValue;
    def builtin_call(nd: uni.FuncCall, name: str) -> (MirValue | None);
    def lower_print(nd: uni.FuncCall) -> MirValue;
    def write_value(value: MirValue, site: uni.UniNode);
    def elem_kind(t: MirType, site: uni.UniNode) -> int;
    def to_bits(value: MirValue, elem: MirType, site: uni.UniNode) -> MirValue;
    def scalar_from_bits(bits: MirValue, elem: MirType) -> MirValue;
    def owned_element(handle: MirValue, elem: MirType) -> MirValue;
    def address_of(value: MirValue) -> MirValue;
    def container_len(value: MirValue) -> MirValue;
    def list_read(lst: MirValue, index: MirValue) -> MirValue;
    def list_index(lst: MirValue, index: MirValue, message: str) -> MirValue;
    def lower_list_literal(nd: uni.ListVal) -> MirValue;
    def lower_set_literal(nd: uni.SetVal) -> MirValue;
    def lower_dict_literal(nd: uni.DictVal) -> MirValue;
    def new_list(elem: MirType, capacity: int) -> MirValue;
    def new_dict(key: MirType, value: (MirType | None), result: MirType) -> MirValue;
    def container_get(base: MirValue, slice: uni.IndexSlice, site: uni.UniNode) -> MirValue;
    def container_set(
        base: MirValue, slice: uni.IndexSlice, value: MirValue, site: uni.UniNode
    );
    def dict_get(d: MirValue, key: MirValue, site: uni.UniNode) -> MirValue;
    def list_slice(lst: MirValue, part: uni.Slice, site: uni.UniNode) -> MirValue;
    def container_method(
        receiver: MirValue, name: str, nd: uni.FuncCall
    ) -> (MirValue | None);
    def list_method(lst: MirValue, name: str, nd: uni.FuncCall) -> (MirValue | None);
    def dict_method(d: MirValue, name: str, nd: uni.FuncCall) -> (MirValue | None);
    def set_method(s: MirValue, name: str, nd: uni.FuncCall) -> (MirValue | None);
    def contains(item: MirValue, holder: MirValue, site: uni.UniNode) -> MirValue;
    def container_eq(left: MirValue, right: MirValue) -> MirValue;
    def lower_for_container(nd: uni.InForStmt, holder: MirValue);
    def lower_delete(nd: uni.DeleteStmt);
    def module_archetypes -> list[uni.Archetype];
    def arch_of_type(t: (TypeBase | None)) -> (uni.Archetype | None);
    def object_def(arch: uni.Archetype) -> MirObjectDef;
    def object_type(arch: uni.Archetype) -> MirType;
    def arch_methods(arch: uni.Archetype) -> list[uni.Ability];
    def find_method(arch: uni.Archetype, name: str) -> (uni.Ability | None);
    def method_symbol(arch: uni.Archetype, name: str) -> str;
    def declare_archetype(arch: uni.Archetype);
    def lower_constructor(arch: uni.Archetype) -> (MirFunction | None);
    def lower_drop(obj_def: MirObjectDef) -> MirFunction;
    def lower_trace(obj_def: MirObjectDef) -> MirFunction;
    def constructor_params(arch: uni.Archetype) -> list[tuple[str, MirType, (uni.Expr | None)]];
    def object_call(nd: uni.FuncCall, arch: uni.Archetype) -> MirValue;
    def object_method(
        nd: uni.FuncCall, receiver: MirValue, arch: uni.Archetype, name: str
    ) -> (MirValue | None);
    def field_place(holder: MirValue, arch: uni.Archetype, name: str, site: uni.UniNode) -> MirValue;
    def isinstance_check(value: MirValue, arch: uni.Archetype) -> MirValue;
    def lower_module_init -> (MirFunction | None);
    def lower_module_entry -> (MirFunction | None);
    def none_value -> MirValue;
    def opt_wrap(value: MirValue, to: MirType) -> MirValue;
    def opt_present(value: MirValue) -> MirValue;
    def opt_get(value: MirValue) -> MirValue;
    def opt_begin(value: MirValue, result: MirType) -> tuple[MirValue, MirValue, MirBlock, MirBlock];
    def opt_switch(held: MirValue, present_value: MirValue, absent: MirBlock, done: MirBlock);
    def opt_end(held: MirValue, absent_value: MirValue, done: MirBlock) -> MirValue;
    def lower_tuple(nd: uni.TupleVal) -> MirValue;
    def tuple_get(value: MirValue, index: int) -> MirValue;
    def unpack_into(targets: list[uni.Expr], value: MirValue, site: uni.UniNode);
    def function_of(nd: uni.UniNode) -> (uni.UniNode | None);
    def names_within(nd: uni.UniNode) -> list[uni.Name];
    def captured_symbols(owner: uni.UniNode, body: Sequence[uni.UniNode]) -> list[uni.Symbol];
    def prepare_cells(owner: uni.UniNode, body: Sequence[uni.UniNode]);
    def cell_of(sym_id: int) -> (MirValue | None);
    def cell_read(cell: MirValue, value_type: MirType) -> MirValue;
    def cell_write(cell: MirValue, value: MirValue, value_type: MirType, site: uni.UniNode);
    def lower_closure(
        owner: uni.UniNode,
        signature: (uni.FuncSignature | None),
        body: (uni.Expr | Sequence[uni.UniNode]),
        fn_type: MirType,
        label: str
    ) -> MirValue;
    def closure_call(nd: uni.FuncCall, callee: MirValue) -> MirValue;
    def function_value(decl: MirDecl, to: MirType) -> MirValue;
    def lower_try(nd: uni.TryStmt);
    def lower_raise(nd: uni.RaiseStmt);
    def exception_matches(type_id: MirValue, clause: uni.Expr) -> MirValue;
    def exception_name(nd: uni.Expr) -> str;
    def any_tag(t: MirType, site: uni.UniNode) -> int;
    def any_box(value: MirValue, site: uni.UniNode) -> MirValue;
    def any_make(tag: MirValue, payload: MirValue) -> MirValue;
    def any_none -> MirValue;
    def any_unbox(value: MirValue, to: MirType, site: uni.UniNode) -> MirValue;
    def any_to_box(value: MirValue, site: uni.UniNode) -> MirValue;
    def any_from_box(handle: MirValue) -> MirValue;
    def identity(left: MirValue, right: MirValue, site: uni.UniNode) -> MirValue;
    def bound_args(nd: uni.FuncCall, ab: uni.Ability, method: bool) -> list[uni.Expr];
    def constant_default(value: (uni.Expr | None)) -> bool;
    def builtin_value(nd: uni.FuncCall, name: str) -> (MirValue | None);
    def list_concat(left: MirValue, right: MirValue) -> MirValue;
    def str_subscript(nd: uni.AtomTrailer) -> (MirValue | None);
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
        co: uni.ConnectOp, edge: (uni.Archetype | None), site: uni.UniNode
    ) -> dict[str, MirValue];

    def osp_edge_object(
        co: uni.ConnectOp,
        edge: (uni.Archetype | None),
        values: dict[str, MirValue],
        site: uni.UniNode
    ) -> MirValue;

    def lower_disconnect(nd: uni.BinaryExpr, dop: uni.DisconnectOp) -> MirValue;
    def osp_list_operand(nd: uni.Expr) -> bool;
    def lower_edge_handles(nd: uni.EdgeRefTrailer) -> MirValue;
    def lower_osp_filter(nd: uni.AtomTrailer) -> MirValue;
    def osp_filter_arch(f: uni.FilterCompr, holder: (uni.Expr | None)) -> (uni.Archetype | None);
    def osp_type_pred(tag: int) -> MirValue;
    def osp_field_pred(
        arch: uni.Archetype, compares: Sequence[uni.Expr], site: uni.UniNode
    ) -> MirValue;

    def osp_predicate(label: str) -> tuple[MirFunction, MirFnState];
    def osp_closure(
        symbol: str, code: MirType, captures: list[tuple[MirValue, MirType]], to: MirType
    ) -> MirValue;

    def osp_delete(target: uni.Expr) -> bool;
    def lower_jid(nd: uni.FuncCall) -> MirValue;
    def emit_value(
        op: MirOp,
        type: MirType,
        operands: list[MirValue],
        sub: str = "",
        callee: str = "",
        int_value: int = 0,
        str_value: str = ""
    ) -> MirValue;
}
