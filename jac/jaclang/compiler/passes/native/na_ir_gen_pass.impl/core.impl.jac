"""Core initialization and transform logic for native IR generation."""
"""Initialize the native IR generation pass."""
impl NaIRGenPass.init(
    ir_in: uni.Module, prog: object, cancel_token: (object | None) = None
) -> None {
    self.llvm_module = ir.Module(name="jac_native", context=ir.Context());
    self.builder: (ir.IRBuilder | None) = None;
    self.func_symtab: dict[(str, ir.Function)] = {};
    self.local_vars: dict[(str, ir.AllocaInstr)] = {};
    self.has_native_code = False;
    self.type_map: dict[(str, ir.Type)] = {
        "int": ir.IntType(64),
        "float": ir.DoubleType(),
        "bool": ir.IntType(1),
        "str": ir.IntType(8).as_pointer()
    };
    self._fmt_strings: dict[(str, ir.GlobalVariable)] = {};
    # External function cache (Phase 0)
    self.extern_funcs: dict[(str, ir.Function)] = {};
    # Enum support (Phase 1)
    self.enum_values: dict[(str, ir.Constant)] = {};
    self.enum_types: dict[(str, ir.IntType)] = {};
    # Loop stack for break/continue (Phase 1)
    self.loop_stack: list[tuple] = [];
    # String counter for unique global names (Phase 2)
    self._str_count: int = 0;
    # Object/struct support (Phase 3)
    self.struct_types: dict[(str, object)] = {};
    self.struct_field_indices: dict[(str, dict)] = {};
    self.struct_field_types: dict[(str, dict)] = {};
    self.struct_field_defaults: dict[(str, object)] = {};
    self.method_funcs: dict[(str, ir.Function)] = {};
    self.type_var_map: dict[(str, str)] = {};
    # List support (Phase 4)
    self.list_types: dict[(str, object)] = {};  # elem_type_name → list struct type
    self.list_helpers: dict[(str, dict)] = {};  # elem_type_name → {new, append, get, set, len}
    self.var_list_elem_type: dict[(str, str)] = {};  # var_name → elem_type_name
    # Jac-level type tracking for nested lists and ptr list element resolution
    self.field_type_node: dict[(str, dict)] = {};  # struct_name → {field → type AST node}
    self.var_type_node: dict[(str, object)] = {};  # var_name → type AST node
    self._list_type_hint: (str | None) = None;  # hint for empty list creation
    self._last_type_node_hint: (object | None) = None;  # Jac type AST of last evaluated expr
    # Inheritance / vtable support (Phase 5)
    self.class_hierarchy: dict[(str, str)] = {};  # child → parent
    self.has_vtable: dict[(str, bool)] = {};
    self.vtable_layouts: dict[(str, list[str])] = {};
    self.vtable_method_indices: dict[(str, dict)] = {};
    self.vtable_globals: dict[(str, ir.GlobalVariable)] = {};
    # Tuple support (Phase 9)
    self.tuple_types: dict[(str, object)] = {};  # type_key → LiteralStructType
    # Global variable support (Phase 11)
    self.global_vars: dict[(str, ir.GlobalVariable)] = {};  # name → global variable
    self.global_var_types: dict[(str, ir.Type)] = {};  # name → LLVM type
    # Dictionary support (Phase 12)
    self.dict_types: dict[(str, object)] = {};  # "key_type:val_type" → dict struct type
    self.dict_helpers: dict[(str, dict)] = {};  # "key_type:val_type" → {new, set, get, contains, len}
    self.var_dict_type: dict[(str, str)] = {};  # var_name → "key_type:val_type"
    # Set support (Phase 13)
    self.set_types: dict[(str, object)] = {};  # elem_type_name → set struct type
    self.set_helpers: dict[(str, dict)] = {};  # elem_type_name → {new, add, contains, len}
    self.var_set_elem_type: dict[(str, str)] = {};  # var_name → elem_type_name
    super.init(ir_in=ir_in, prog=prog, cancel_token=cancel_token);
}

# ─── Main Pass Logic ─────────────────────────────────────────
"""Forward-declare, codegen native abilities/entries, and store the LLVM module."""
impl NaIRGenPass.transform(ir_in: uni.Module) -> uni.Module {
    # Phase 0: Forward declarations (enums, archetypes, free functions, globals)
    self._register_enums(self.ir_in);
    self._register_globals(self.ir_in);
    self._register_archetypes(self.ir_in);
    # Phase 1: Codegen native abilities and entry blocks
    for stmt in self.ir_in.body {
        if isinstance(stmt, uni.NativeBlock) {
            for inner in stmt.body {
                if (
                    isinstance(inner, uni.Ability)
                    and isinstance(inner, uni.ContextAwareNode)
                    and inner.code_context == CodeContext.NATIVE
                    and inner.signature is not None
                    and isinstance(inner.signature, uni.FuncSignature)
                ) {
                    self._codegen_ability(inner);
                } elif (
                    isinstance(inner, uni.ModuleCode)
                    and isinstance(inner, uni.ContextAwareNode)
                    and inner.code_context == CodeContext.NATIVE
                ) {
                    self._codegen_entry(inner);
                }
            }
        } elif isinstance(stmt, uni.Ability) {
            if (
                isinstance(stmt, uni.ContextAwareNode)
                and stmt.code_context == CodeContext.NATIVE
                and stmt.signature is not None
                and isinstance(stmt.signature, uni.FuncSignature)
            ) {
                self._codegen_ability(stmt);
            }
        } elif isinstance(stmt, uni.ModuleCode) {
            if (
                isinstance(stmt, uni.ContextAwareNode)
                and stmt.code_context == CodeContext.NATIVE
            ) {
                self._codegen_entry(stmt);
            }
        }
    }
    # Store LLVM module on AST
    if self.has_native_code {
        self.ir_in.gen.llvm_ir = self.llvm_module;
    }
    return self.ir_in;
}
