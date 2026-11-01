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
        caught: list[tuple[MirValue, MirValue, MirValue]] = [];
}

obj MirDecl {
    has ability: uni.Ability,
        symbol: str,
        ret: MirType,
        params: list[MirType] = [],
        self_type: (MirType | None) = None,
        owner: (uni.Archetype | None) = None;
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
        state: (MirFnState | None) = None;

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
