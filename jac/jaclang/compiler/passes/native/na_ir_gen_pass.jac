"""Native LLVM IR generation pass for na {} blocks.

Compiles Jac AST nodes in NATIVE context to LLVM IR using llvmlite.
All code in na {} or .na.jac is guaranteed to compile to native LLVM IR.

Derives from Transform (not UniPass) because LLVM IR generation uses
manual tree-walking rather than the visitor pattern — instructions must
be emitted into specific basic blocks in order for control flow.
"""

import from llvmlite { ir }
import jaclang.pycore.unitree as uni;
import from jaclang.pycore.passes { Transform }
import from jaclang.pycore.constant { CodeContext, Tokens as Tok }

"""Compile na-context Jac AST to LLVM IR using llvmlite.

Uses manual tree-walking for function bodies to properly handle
control flow basic blocks (if/else, while loops).
"""
obj NaIRGenPass(Transform) {
    def init(
        ir_in: uni.Module, prog: object, cancel_token: (object | None) = None
    ) -> None;
    # Main pass logic
    def transform(ir_in: uni.Module) -> uni.Module;
    def _register_enums(module: uni.Module) -> None;
    def _forward_declare_functions(module: uni.Module) -> None;
    def _maybe_declare_ability(node: uni.ElementStmt) -> None;
    # Ability (function definition) - manual codegen
    def _codegen_ability(<>node: uni.Ability) -> None;
    # Body / statement codegen
    def _codegen_body(stmts: (list | tuple)) -> None;
    def _codegen_stmt(node: uni.UniNode) -> None;
    def _codegen_return(node: uni.ReturnStmt) -> None;
    def _codegen_if(node: uni.IfStmt) -> None;
    def _codegen_while(node: uni.WhileStmt) -> None;
    def _codegen_assignment(node: uni.Assignment) -> None;
    # Expression codegen
    def _codegen_expr(node: (uni.UniNode | None)) -> (ir.Value | None);
    def _codegen_name(node: uni.Name) -> (ir.Value | None);
    def _codegen_binary(node: uni.BinaryExpr) -> (ir.Value | None);
    def _codegen_compare(node: uni.CompareExpr) -> (ir.Value | None);
    def _codegen_unary(node: uni.UnaryExpr) -> (ir.Value | None);
    def _codegen_call(node: uni.FuncCall) -> (ir.Value | None);
    # External function support (Phase 0)
    def _get_or_declare_extern(
        name: str, ret_type: ir.Type, arg_types: list[ir.Type], var_arg: bool = False
    ) -> ir.Function;
    # Print support
    def _get_printf -> ir.Function;
    def _emit_print(node: uni.FuncCall) -> (ir.Value | None);
    def _get_fmt_string(fmt: str) -> ir.GlobalVariable;
    # Helper methods
    def _resolve_jac_type(type_expr: (uni.UniNode | None)) -> ir.Type;
    def _get_name(node: (uni.UniNode | None)) -> (str | None);
    def _to_bool(val: ir.Value) -> ir.Value;
    def _entry_alloca(var_type: ir.Type, name: str) -> ir.Value;
    def _coerce_type(val: ir.Value, target_type: ir.Type) -> ir.Value;
    def _promote_to_float(
        left: ir.Value, right: ir.Value
    ) -> tuple[(ir.Value, ir.Value)];

    def _emit_binary_op(op: str, left: ir.Value, right: ir.Value) -> (ir.Value | None);
    def _emit_comparison(
        op: str, left: ir.Value, right: ir.Value, is_float: bool
    ) -> (ir.Value | None);

    def _codegen_int_pow(base: ir.Value, exp: ir.Value) -> ir.Value;
    # Phase 1: Enums, BoolExpr, Break/Continue, For, Ternary
    def _codegen_enum(<>node: uni.Enum) -> None;
    def _codegen_atom_trailer(node: uni.AtomTrailer) -> (ir.Value | None);
    def _codegen_bool_expr(node: uni.BoolExpr) -> (ir.Value | None);
    def _codegen_ctrl(node: uni.CtrlStmt) -> None;
    def _codegen_for(node: uni.InForStmt) -> None;
    def _codegen_if_else_expr(node: uni.IfElseExpr) -> (ir.Value | None);
    # Phase 2: Strings and F-Strings
    def _codegen_multistring(node: uni.MultiString) -> (ir.Value | None);
    def _codegen_string(node: uni.String) -> (ir.Value | None);
    def _codegen_fstring(node: uni.FString) -> (ir.Value | None);
    def _make_global_string(text: str, name_prefix: str = ".str") -> ir.Value;
    # Phase 3: Objects, Fields, Methods, None
    def _register_archetypes(module: uni.Module) -> None;
    def _codegen_archetype(<>node: uni.Archetype) -> None;
    def _forward_declare_method(arch_name: str, method: uni.Ability) -> None;
    def _codegen_method(arch_name: str, method: uni.Ability) -> None;
    def _codegen_instantiation(node: uni.FuncCall) -> (ir.Value | None);
    def _codegen_method_call(node: uni.FuncCall) -> (ir.Value | None);
    def _codegen_field_access(
        obj_val: ir.Value, field_name: str, type_name: str
    ) -> (ir.Value | None);

    def _codegen_field_assign(target: uni.AtomTrailer, value: ir.Value) -> None;
    # Phase 4: Lists
    def _emit_list_helpers(elem_type_name: str, elem_type: ir.Type) -> None;
    def _codegen_list_val(node: uni.ListVal) -> (ir.Value | None);
    def _codegen_index(
        target_val: ir.Value, index_val: ir.Value, elem_type_name: str
    ) -> (ir.Value | None);

    def _codegen_index_set(
        target_val: ir.Value, index_val: ir.Value, value: ir.Value, elem_type_name: str
    ) -> None;
    # Phase 5: Inheritance and Vtables
    def _build_vtable(arch_name: str) -> None;
    def _emit_vtable_global(arch_name: str) -> None;
    def _codegen_virtual_call(
        obj_val: ir.Value, method_name: str, args: list[ir.Value], obj_type_name: str
    ) -> (ir.Value | None);

    def _generate_inherited_method_wrappers -> None;
    # Phase 6: Complex Chains and Type Inference
    def _infer_type_name(val: ir.Value) -> (str | None);
    def _infer_list_elem_type(val: ir.Value) -> (str | None);
    def _peel_list_type(type_node: (object | None)) -> tuple;
    def _get_list_elem_from_type_node(type_node: (object | None)) -> (str | None);
    def _resolve_for_loop_elem_type(
        coll_name: (str | None), coll_node: (object | None)
    ) -> (ir.Type | None);

    def _resolve_ptr_elem_cast_type(type_node: (object | None)) -> (ir.Type | None);
    # Phase 7: String Methods and Builtins
    def _codegen_string_index(
        target_val: ir.Value, index_val: ir.Value
    ) -> (ir.Value | None);

    def _codegen_str_strip(str_val: ir.Value) -> (ir.Value | None);
    def _codegen_str_split(str_val: ir.Value, sep_val: ir.Value) -> (ir.Value | None);
    # Phase 8: Entry Block
    def _codegen_entry(<>node: uni.ModuleCode) -> None;
    # Phase 9: Tuples
    def _codegen_tuple_val(node: uni.TupleVal) -> (ir.Value | None);
    def _codegen_tuple_unpack(
        targets: list, tuple_val: ir.Value, tuple_node: (object | None)
    ) -> None;

    def _codegen_tuple_index(
        tuple_val: ir.Value, idx_val: ir.Value, struct_type: ir.LiteralStructType
    ) -> (ir.Value | None);

    def _get_struct_size(struct_type: ir.LiteralStructType) -> int;
    # Phase 10: Comprehensions
    def _codegen_list_compr(node: uni.ListCompr) -> (ir.Value | None);
    def _codegen_compr_loops(
        comprs: list,
        idx: int,
        list_val: ir.Value,
        out_expr: uni.UniNode,
        elem_type_name: str
    ) -> None;

    def _codegen_compr_range_loop(
        inner: uni.InnerCompr,
        comprs: list,
        idx: int,
        list_val: ir.Value,
        out_expr: uni.UniNode,
        elem_type_name: str,
        conditionals: list
    ) -> None;

    def _codegen_dict_compr(node: uni.DictCompr) -> (ir.Value | None);
    def _codegen_dict_compr_loops(
        comprs: list,
        idx: int,
        dict_val: ir.Value,
        key_expr: uni.UniNode,
        val_expr: uni.UniNode,
        dict_key: str
    ) -> None;

    def _codegen_dict_compr_range_loop(
        inner: uni.InnerCompr,
        comprs: list,
        idx: int,
        dict_val: ir.Value,
        key_expr: uni.UniNode,
        val_expr: uni.UniNode,
        dict_key: str,
        conditionals: list
    ) -> None;

    def _codegen_set_compr(node: uni.SetCompr) -> (ir.Value | None);
    def _codegen_set_compr_loops(
        comprs: list,
        idx: int,
        set_val: ir.Value,
        out_expr: uni.UniNode,
        elem_type_name: str
    ) -> None;

    def _codegen_set_compr_range_loop(
        inner: uni.InnerCompr,
        comprs: list,
        idx: int,
        set_val: ir.Value,
        out_expr: uni.UniNode,
        elem_type_name: str,
        conditionals: list
    ) -> None;
    # Phase 11: Global Variables
    def _register_globals(module: uni.Module) -> None;
    def _codegen_global_vars(node: uni.GlobalVars) -> None;
    def _codegen_const_expr(
        node: uni.UniNode, target_type: ir.Type
    ) -> (ir.Constant | None);
    # Phase 12: Dictionaries
    def _emit_dict_helpers(
        key_type_name: str, val_type_name: str, key_type: ir.Type, val_type: ir.Type
    ) -> None;

    def _codegen_dict_val(node: uni.DictVal) -> (ir.Value | None);
    def _codegen_dict_access(
        target_val: ir.Value, key_val: ir.Value, key_type_name: str, val_type_name: str
    ) -> (ir.Value | None);

    def _codegen_dict_set(
        target_val: ir.Value,
        key_val: ir.Value,
        value: ir.Value,
        key_type_name: str,
        val_type_name: str
    ) -> None;

    def _infer_dict_type(val: ir.Value) -> (tuple | None);
    # Phase 13: Sets
    def _emit_set_helpers(
        elem_type_name: str, elem_type: ir.Type, elem_size: int = 0
    ) -> None;

    def _codegen_set_val(node: uni.SetVal) -> (ir.Value | None);
    def _codegen_set_contains(
        set_val: ir.Value, elem_val: ir.Value, elem_type_name: str
    ) -> (ir.Value | None);

    def _codegen_set_add(
        set_val: ir.Value, elem_val: ir.Value, elem_type_name: str
    ) -> None;
}
