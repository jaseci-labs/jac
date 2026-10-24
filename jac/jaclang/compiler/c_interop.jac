glob C_BUILTIN_TYPES: tuple[str, ...] = ("ptr", "PtrView", "Pinned", "VaList");

def clib_import_of(nd: (UniNode | None)) -> (Import | None);

def clib_block_defines(imp: (UniNode | None)) -> bool;

def is_clib_archetype(arch: (UniNode | None)) -> bool;

def is_opaque_c_archetype(arch: (UniNode | None)) -> bool;

def is_foreign_struct_archetype(arch: (UniNode | None)) -> bool;

def _class_of(t: (TypeBase | None)) -> (ClassType | None);

def clib_archetype_of_type(t: (TypeBase | None)) -> (Archetype | None);

def foreign_struct_of_type(t: (TypeBase | None)) -> (Archetype | None);

def opaque_c_of_type(t: (TypeBase | None)) -> (Archetype | None);

def c_builtin_kind(t: (TypeBase | None)) -> str;

def is_ptr_type(t: (TypeBase | None)) -> bool;

def is_ptr_view_type(t: (TypeBase | None)) -> bool;

def is_pinned_type(t: (TypeBase | None)) -> bool;

def is_va_list_type(t: (TypeBase | None)) -> bool;

def c_variadic_param(sig: (UniNode | None)) -> (ParamVar | None);

def c_type_arg(t: (TypeBase | None)) -> (TypeBase | None);

def reads_foreign_storage(nd: (UniNode | None)) -> bool;

def foreign_field_of(nd: (UniNode | None)) -> (tuple[Archetype, int] | None);

def foreign_read_is_place(nd: UniNode) -> bool;

def foreign_read_copies(nd: (UniNode | None)) -> bool;

def _ambient_c_call_returns(
    call: (UniNode | None), name: str
) -> list[(TypeBase | None)];

def is_builtin_pin_call(call: (UniNode | None)) -> bool;

def is_builtin_addressof_call(call: (UniNode | None)) -> bool;

def is_c_value_type(t: (TypeBase | None)) -> bool;

def c_call_borrows_args(call: (UniNode | None)) -> bool;

def c_lent_elem(
    param_type: (TypeBase | None), operand_type: (TypeBase | None)
) -> (TypeBase | None);

def c_spec_same(a: any, b: any) -> bool;

def c_abi_callee(call: (UniNode | None)) -> (Ability | None);

def c_lent_arg_elem(arg: (UniNode | None)) -> (TypeBase | None);

def c_param_type(call: UniNode, param: ParamVar) -> (TypeBase | None);

def c_lent_param(arg: UniNode) -> (ParamVar | None);

glob _SPEC_SCALAR_ALIASES: dict[str, str] = {"int": "i64", "float": "f64"};

def c_type_spec(
    t: (TypeBase | None),
    annotation: (UniNode | None) = None,
    written_in: (UniNode | None) = None
) -> list[any];

def _spelled_c_type_name(arch: Archetype, written_in: (UniNode | None)) -> str;

def _spec_for_name(name: str) -> (list[any] | None);

def _annotation_name(annotation: (UniNode | None)) -> (str | None);

def clib_global_assignment(decl: (UniNode | None)) -> (Assignment | None);

def clib_global_of_symbol(sym: (Symbol | None)) -> (Assignment | None);

def clib_global_of_name(nd: (UniNode | None)) -> (Assignment | None);

def c_string_literal(expr: (UniNode | None)) -> (str | None);

def named_function_of(nd: (UniNode | None)) -> (UniNode | None);

def final_glob_value(nd: (UniNode | None)) -> (Expr | None);

def c_scalar_constant(expr: (UniNode | None), depth: int = 0) -> tuple[bool, any];

def _fold_with_finals(expr: UniNode, depth: int) -> tuple[bool, any];

def c_array_elem(t: (TypeBase | None)) -> (TypeBase | None);

def c_bytes_literal(expr: (UniNode | None)) -> (bytes | None);

def c_bytes_elem_shape(elem: (TypeBase | None)) -> (tuple[int, bool] | None);

def c_bytes_array_values(data: bytes, width: int, signed: bool) -> list[int];

def c_bytes_array_definition(assign: Assignment, ctype: (TypeBase | None)) -> bool;
