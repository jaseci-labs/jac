impl NaIRGenPass._enter_bindings(inherit: bool = False) -> NativeBindingState {
    state = NativeBindingState(
        local_vars=self.local_vars,
        param_vars=self.param_vars,
        nogc_no_free_vars=self.nogc_no_free_vars,
        nogc_owned_str_vars=self.nogc_owned_str_vars,
        region_handle_vars=self.region_handle_vars,
        var_list_elem_struct=self.var_list_elem_struct,
        closure_cell_vars=self.closure_cell_vars,
        closure_cell_handles=self.closure_cell_handles
    );
    self.local_vars = self.local_vars.copy() if inherit else {};
    self.param_vars = self.param_vars.copy() if inherit else set();
    self.nogc_no_free_vars = self.nogc_no_free_vars.copy() if inherit else set();
    self.nogc_owned_str_vars = self.nogc_owned_str_vars.copy() if inherit else set();
    self.region_handle_vars = self.region_handle_vars.copy() if inherit else set();
    self.var_list_elem_struct = self.var_list_elem_struct.copy() if inherit else {};
    self.closure_cell_vars = self.closure_cell_vars.copy() if inherit else set();
    self.closure_cell_handles = self.closure_cell_handles.copy() if inherit else {};
    return state;
}

impl NaIRGenPass._leave_bindings(
    state: NativeBindingState, release: bool = False
) -> None {
    if release {
        locals = [
            name
            for (name, slot) in self.local_vars.items()
            if state.local_vars.get(name) is not slot
        ];
        self._emit_loop_iter_cleanup(locals);
    }
    self.local_vars = state.local_vars;
    self.param_vars = state.param_vars;
    self.nogc_no_free_vars = state.nogc_no_free_vars;
    self.nogc_owned_str_vars = state.nogc_owned_str_vars;
    self.region_handle_vars = state.region_handle_vars;
    self.var_list_elem_struct = state.var_list_elem_struct;
    self.closure_cell_vars = state.closure_cell_vars;
    self.closure_cell_handles = state.closure_cell_handles;
}

impl NaIRGenPass._shadow_bindings(names: list[str]) -> None {
    for name in names {
        self.local_vars.pop(name, None);
        self.param_vars.discard(name);
        self.nogc_no_free_vars.discard(name);
        self.nogc_owned_str_vars.discard(name);
        self.region_handle_vars.discard(name);
        self.var_list_elem_struct.pop(name, None);
        self.closure_cell_vars.discard(name);
        self.closure_cell_handles.pop(name, None);
    }
}

impl NaIRGenPass._enter_function(func: ir.Function) -> NativeFunctionState {
    state = NativeFunctionState(
        bindings=self._enter_bindings(),
        _builder=self._builder,
        func_symtab=self.func_symtab,
        nested_captures=self.nested_captures,
        lambda_captures=self.lambda_captures,
        region_open_stack=self.region_open_stack,
        loop_stack=self.loop_stack,
        _self_owned=self._self_owned,
        _self_arch=self._self_arch,
        _di_current_sp=self._di_current_sp,
        _gen_ctx=self._gen_ctx,
        _gen_try_stack=self._gen_try_stack,
        _slot_try_stack=self._slot_try_stack,
        _finally_stack=self._finally_stack,
        _caught_error_stack=self._caught_error_stack
    );
    self._builder = ir.IRBuilder(func.append_basic_block("entry"));
    self.func_symtab = self.func_symtab.copy();
    self.nested_captures = self.nested_captures.copy();
    self.lambda_captures = self.lambda_captures.copy();
    self.region_open_stack = [];
    self.loop_stack = [];
    self._self_owned = False;
    self._di_current_sp = None;
    self._gen_ctx = None;
    self._gen_try_stack = [];
    self._slot_try_stack = [];
    self._finally_stack = [];
    self._caught_error_stack = [];
    return state;
}

impl NaIRGenPass._bind_function_parameter(
    name: str, value: ir.Value, borrowed: bool = True, rebound: bool = False
) -> None {
    if name in self.closure_cell_vars {
        slot = self._emit_closure_cell(name, value.type);
        self.builder.store(value, slot);
        self.local_vars[name] = slot;
        if borrowed and self._elem_kind(value.type) in ("rc_ptr", "str") {
            self._emit_rc_retain(value, op="param_cell", loc=name);
        }
        return;
    }
    slot = self._entry_alloca(value.type, name);
    self.builder.store(value, slot);
    self.local_vars[name] = slot;
    if rebound and self._elem_kind(value.type) in ("rc_ptr", "str") {
        self._emit_rc_retain(value, op="param_promote", loc=name);
    } elif borrowed {
        self.param_vars.add(name);
    }
}

impl NaIRGenPass._leave_function(state: NativeFunctionState) -> None {
    self._leave_bindings(state.bindings);
    self._builder = state._builder;
    self.func_symtab = state.func_symtab;
    self.nested_captures = state.nested_captures;
    self.lambda_captures = state.lambda_captures;
    self.region_open_stack = state.region_open_stack;
    self.loop_stack = state.loop_stack;
    self._self_owned = state._self_owned;
    self._self_arch = state._self_arch;
    self._di_current_sp = state._di_current_sp;
    self._gen_ctx = state._gen_ctx;
    self._gen_try_stack = state._gen_try_stack;
    self._slot_try_stack = state._slot_try_stack;
    self._finally_stack = state._finally_stack;
    self._caught_error_stack = state._caught_error_stack;
}
