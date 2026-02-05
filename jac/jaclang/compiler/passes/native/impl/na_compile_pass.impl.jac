"""Initialize the native compile pass."""
impl NativeCompilePass.init(
    ir_in: uni.Module, prog: object, cancel_token: (object | None) = None
) -> None {
    llvm.initialize_native_target();
    llvm.initialize_native_asmprinter();
    super.init(ir_in=ir_in, prog=prog, cancel_token=cancel_token);
}

"""Compile the LLVM IR module if one was generated."""
impl NativeCompilePass.transform(ir_in: uni.Module) -> uni.Module {
    module = ir_in;
    if module.gen.llvm_ir is None {
        return ir_in;
    }
    llvm_ir_str = str(module.gen.llvm_ir);
    try {
        # Load shared libraries so MCJIT can resolve external symbols
        import ctypes as _ct;
        import ctypes.util;
        libc_name = ctypes.util.find_library("c");
        if libc_name {
            llvm.load_library_permanently(libc_name);
        }
        libgc_name = ctypes.util.find_library("gc");
        if libgc_name {
            llvm.load_library_permanently(libgc_name);
        } else {
            # Fallback: map GC_malloc/GC_init to libc malloc/noop
            libc = _ct.CDLL(libc_name);
            malloc_addr = _ct.cast(libc.malloc, _ct.c_void_p).value;
            llvm.add_symbol("GC_malloc", malloc_addr);
        }
        mod = llvm.parse_assembly(llvm_ir_str);
        mod.verify();
        target = llvm.Target.from_default_triple();
        target_machine = target.create_target_machine();
        engine = llvm.create_mcjit_compiler(mod, target_machine);
        module.gen.native_engine = engine;
    } except Exception as e {
        self.log_error(f"Native compilation failed: {e}");
    }
    return ir_in;
}
