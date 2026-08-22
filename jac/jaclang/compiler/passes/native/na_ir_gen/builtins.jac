import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import from jaclang.jac0core.codeinfo { RC_SENTINEL, str_len_tag }
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.diagnostics { E5092 }
import jaclang.jac0core.unitree as uni;
import os;
import sys;
import from jaclang.jac0core.constant { OwnershipKind }

obj NaIRGenBuiltins(NaIRGenState) {
    def _get_or_declare_extern(
        name: str, ret_type: ir.Type, arg_types: list[ir.Type], var_arg: bool = False
    ) -> ir.Function;

    def _get_printf -> ir.Function;
    def _emit_print(nd: uni.FuncCall) -> (ir.Value | None);
    def _get_fmt_string(fmt: str) -> ir.GlobalVariable;
    def _get_snprintf_fmt(fmt: str) -> ir.GlobalVariable;
    def _codegen_multistring(nd: uni.MultiString) -> (ir.Value | None);
    def _codegen_string(nd: uni.String) -> (ir.Value | None);
    def _codegen_fstring(nd: uni.FString) -> (ir.Value | None);
    def _fstring_spec_text(spec: uni.Expr) -> (str | None);
    def _fstring_spec_to_printf(spec: str, kind: str) -> (tuple | None);
    def _emit_fstr_repr(val: ir.Value, part: uni.FormattedValue) -> (ir.Value | None);
    def _emit_dyn_spec_format(
        val: ir.Value, spec_val: ir.Value, part: uni.FormattedValue
    ) -> (ir.Value | None);

    def _static_str_struct_const(data: bytes) -> tuple;
    def _make_global_string(text: str, name_prefix: str = ".str") -> ir.Value;
    def _emit_optional_str(
        val: ir.Value, part: (uni.UniNode | None)
    ) -> (ir.Value | None);

    def _codegen_string_index(
        target_val: ir.Value, index_val: ir.Value, len_val: (ir.Value | None) = None
    ) -> (ir.Value | None);

    def _emit_is_strip_char(ch: ir.Value, charset: (ir.Value | None)) -> ir.Value;
    def _codegen_str_strip_chars(
        str_val: ir.Value, charset: (ir.Value | None), do_left: bool, do_right: bool
    ) -> (ir.Value | None);

    def _codegen_str_split(str_val: ir.Value, sep_val: ir.Value) -> (ir.Value | None);
    def _emit_norm_slice_bounds(
        slice_node: object, src_len: ir.Value
    ) -> (tuple | None);

    def _codegen_list_slice(
        target_val: ir.Value, slice_node: object, elem_type_name: str
    ) -> (ir.Value | None);

    def _codegen_string_slice(
        target_val: ir.Value, slice_node: object, base_node: object = None
    ) -> (ir.Value | None);

    def _hl_view_base_licensed(base_node: object) -> bool;
    def _emit_sys_argv -> (ir.Value | None);
    def _emit_sys_stream(stream: str) -> (ir.Value | None);
    def _emit_sys_exit(args: list[ir.Value]) -> (ir.Value | None);
    def _emit_float_repr(fv: ir.Value) -> ir.Value;
    def _emit_opt_repr(opt_val: ir.Value) -> (ir.Value | None);
    def _float_repr_fn -> ir.Function;
    def _emit_any_str(jacval: ir.Value) -> ir.Value;
}
