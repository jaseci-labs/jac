"""Implementation for CompileOptions."""

"""Return a copy with skip_native_engine set."""
impl CompileOptions.with_skip_native_engine(
    self: CompileOptions, `skip: bool = True
) -> CompileOptions {
    return CompileOptions(
        type_check=self.type_check,
        symtab_ir_only=self.symtab_ir_only,
        no_cgen=self.no_cgen,
        skip_native_engine=`skip,
        cancel_token=self.cancel_token
    );
}
