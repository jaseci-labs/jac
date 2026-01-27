"""Initialize the native compile pass."""
impl NativeCompilePass.init(
    ir_in: uni.Module, prog: object, cancel_token: (object | None) = None
) -> None {
    llvm.initialize_native_target();
    llvm.initialize_native_asmprinter();
    super.init(ir_in=ir_in, prog=prog, cancel_token=cancel_token);
}

"""Compile the LLVM IR module if one was generated."""
impl NativeCompilePass.before_pass -> None {
    module = self.ir_in;
    if module.gen.llvm_ir is None {
        return;
    }
    llvm_ir_str = str(module.gen.llvm_ir);
    try {
        mod = llvm.parse_assembly(llvm_ir_str);
        mod.verify();
        target = llvm.Target.from_default_triple();
        target_machine = target.create_target_machine();
        engine = llvm.create_mcjit_compiler(mod, target_machine);
        module.gen.native_engine = engine;
    } except Exception as e {
        self.log_error(f"Native compilation failed: {e}");
    }
}
