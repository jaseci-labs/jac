impl shim -> ctypes.CDLL {
    if _SHIM {
        return _SHIM[0];
    }
    lib = ctypes.CDLL(shim_path());
    lib.LLVMPY_DisposeString.argtypes = [c_char_p];
    lib.LLVMPY_AddSymbol.argtypes = [c_char_p, c_void_p];
    lib.LLVMPY_LoadLibraryPermanently.argtypes = [c_char_p, POINTER(c_char_p)];
    lib.LLVMPY_LoadLibraryPermanently.restype = c_bool;
    lib.LLVMPY_LinkInMCJIT.argtypes = [];
    lib.LLVMPY_CreateMCJITCompiler.argtypes = [
        c_void_p,
        c_void_p,
        c_bool,
        POINTER(c_char_p)
    ];
    lib.LLVMPY_CreateMCJITCompiler.restype = c_void_p;
    lib.LLVMPY_AddGlobalMapping.argtypes = [c_void_p, c_void_p, c_void_p];
    lib.LLVMPY_FinalizeObject.argtypes = [c_void_p];
    lib.LLVMPY_RunStaticConstructors.argtypes = [c_void_p];
    lib.LLVMPY_RunStaticDestructors.argtypes = [c_void_p];
    lib.LLVMPY_GetFunctionAddress.argtypes = [c_void_p, c_char_p];
    lib.LLVMPY_GetFunctionAddress.restype = c_uint64;
    lib.LLVMPY_GetGlobalValueAddress.argtypes = [c_void_p, c_char_p];
    lib.LLVMPY_GetGlobalValueAddress.restype = c_uint64;
    lib.LLVMPY_EnableJITEvents.argtypes = [c_void_p];
    lib.LLVMPY_EnableJITEvents.restype = c_bool;
    lib.LLVMPY_DisposeExecutionEngine.argtypes = [c_void_p];
    lib.LLVMPY_LinkInMCJIT();
    _SHIM.append(lib);
    return lib;
}

impl take_error(err: c_char_p) -> str {
    text = (err.value or b"").decode("utf-8", "replace");
    if err.value is not None {
        shim().LLVMPY_DisposeString(err);
    }
    return text;
}

impl add_symbol(name: str, address: int) {
    shim().LLVMPY_AddSymbol(name.encode("utf-8"), c_void_p(address));
}

impl load_library_permanently(filename: str) {
    err = c_char_p(None);
    if shim().LLVMPY_LoadLibraryPermanently(filename.encode("utf-8"), ctypes.byref(err)) {
        raise RuntimeError(take_error(err));
    }
}

impl create_mcjit_compiler(
    module: ModuleRef, target_machine: TargetMachine, use_lmm: (bool | None) = None
) -> ExecutionEngine {
    lmm = use_lmm if use_lmm is not None else platform.machine() in ("arm64", "aarch64");
    err = c_char_p(None);
    handle = shim().LLVMPY_CreateMCJITCompiler(
        c_void_p(int(module.live())),
        c_void_p(int(target_machine.live())),
        lmm,
        ctypes.byref(err)
    );
    if not handle {
        raise RuntimeError(take_error(err));
    }
    module.detach();
    target_machine.detach();
    return ExecutionEngine(handle);
}

impl ExecutionEngine.init(self: ExecutionEngine, handle: int) {
    self.handle = handle;
    self.static_init_symbols: list[str] = [];
    self.static_init_chained: set[str] = set();
    self._pinned = False;
}

impl ExecutionEngine.run_static_init(self: ExecutionEngine) {
    symbols = self.static_init_symbols;
    self.static_init_symbols = [];
    for symbol in symbols {
        address = shim().LLVMPY_GetFunctionAddress(self.handle, symbol.encode("ascii"));
        if address {
            CFUNCTYPE(None)(address)();
        }
    }
}

impl ExecutionEngine.get_function_address(self: ExecutionEngine, name: str) -> int {
    self._pin();
    if self.static_init_symbols and name not in self.static_init_chained {
        self.run_static_init();
    }
    return int(shim().LLVMPY_GetFunctionAddress(self.handle, name.encode("ascii")));
}

impl ExecutionEngine.get_global_value_address(self: ExecutionEngine, name: str) -> int {
    self._pin();
    return int(shim().LLVMPY_GetGlobalValueAddress(self.handle, name.encode("ascii")));
}

impl ExecutionEngine._pin(self: ExecutionEngine) {
    if not self._pinned {
        self._pinned = True;
        _PINNED_ENGINES.append(self);
    }
}

impl ExecutionEngine.add_global_mapping(
    self: ExecutionEngine, value: ValueRef, address: int
) {
    shim().LLVMPY_AddGlobalMapping(
        self.handle, c_void_p(int(value.live())), c_void_p(address)
    );
}

impl ExecutionEngine.finalize_object(self: ExecutionEngine) {
    shim().LLVMPY_FinalizeObject(self.handle);
}

impl ExecutionEngine.run_static_constructors(self: ExecutionEngine) {
    shim().LLVMPY_RunStaticConstructors(self.handle);
}

impl ExecutionEngine.run_static_destructors(self: ExecutionEngine) {
    shim().LLVMPY_RunStaticDestructors(self.handle);
}

impl ExecutionEngine.enable_jit_events(self: ExecutionEngine) -> bool {
    return bool(shim().LLVMPY_EnableJITEvents(self.handle));
}

impl ExecutionEngine.close(self: ExecutionEngine) {
    if self.handle and not self._pinned {
        shim().LLVMPY_DisposeExecutionEngine(self.handle);
        self.handle = 0;
    }
}
