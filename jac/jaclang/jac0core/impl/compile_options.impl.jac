"""Implementation for CompileOptions."""

"""Return a copy with skip_native_engine set."""
impl CompileOptions.with_skip_native_engine(`skip: bool = True) -> CompileOptions {
    return CompileOptions(
        type_check=self.type_check,
        symtab_ir_only=self.symtab_ir_only,
        no_cgen=self.no_cgen,
        skip_native_engine=`skip,
        force_target_program=self.force_target_program,
        aot_mode=self.aot_mode,
        cancel_token=self.cancel_token
    );
}

"""Return a copy with aot_mode set."""
impl CompileOptions.with_aot_mode(mode: bool = True) -> CompileOptions {
    return CompileOptions(
        type_check=self.type_check,
        symtab_ir_only=self.symtab_ir_only,
        no_cgen=self.no_cgen,
        skip_native_engine=self.skip_native_engine,
        aot_mode=mode,
        cancel_token=self.cancel_token
    );
}
