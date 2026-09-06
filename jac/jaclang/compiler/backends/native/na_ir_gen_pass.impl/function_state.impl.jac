impl NaIRGenPass._enter_function(func: ir.Function) -> NativeFunctionState {
    state = NativeFunctionState(
        _builder=self._builder,
        local_vars=self.local_vars,
        param_vars=self.param_vars,
        nogc_no_free_vars=self.nogc_no_free_vars,
        nogc_owned_str_vars=self.nogc_owned_str_vars,
        region_handle_vars=self.region_handle_vars,
        region_open_stack=self.region_open_stack,
        loop_stack=self.loop_stack,
        var_list_elem_struct=self.var_list_elem_struct,
        closure_cell_vars=self.closure_cell_vars,
        closure_cell_handles=self.closure_cell_handles,
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
    self.local_vars = {};
    self.param_vars = set();
    self.nogc_no_free_vars = set();
    self.nogc_owned_str_vars = set();
    self.region_handle_vars = set();
    self.region_open_stack = [];
    self.loop_stack = [];
    self.var_list_elem_struct = {};
    self.closure_cell_vars = set();
    self.closure_cell_handles = {};
    self._self_owned = False;
    self._di_current_sp = None;
    self._gen_ctx = None;
    self._gen_try_stack = [];
    self._slot_try_stack = [];
    self._finally_stack = [];
    self._caught_error_stack = [];
    return state;
}

impl NaIRGenPass._leave_function(state: NativeFunctionState) -> None {
    self._builder = state._builder;
    self.local_vars = state.local_vars;
    self.param_vars = state.param_vars;
    self.nogc_no_free_vars = state.nogc_no_free_vars;
    self.nogc_owned_str_vars = state.nogc_owned_str_vars;
    self.region_handle_vars = state.region_handle_vars;
    self.region_open_stack = state.region_open_stack;
    self.loop_stack = state.loop_stack;
    self.var_list_elem_struct = state.var_list_elem_struct;
    self.closure_cell_vars = state.closure_cell_vars;
    self.closure_cell_handles = state.closure_cell_handles;
    self._self_owned = state._self_owned;
    self._self_arch = state._self_arch;
    self._di_current_sp = state._di_current_sp;
    self._gen_ctx = state._gen_ctx;
    self._gen_try_stack = state._gen_try_stack;
    self._slot_try_stack = state._slot_try_stack;
    self._finally_stack = state._finally_stack;
    self._caught_error_stack = state._caught_error_stack;
}
