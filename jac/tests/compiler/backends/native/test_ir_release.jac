"""A released IR module is freed by reference counting alone."""
import gc;
import weakref;
import from jaclang.compiler.backends.native.llvm { ir, binding as llvm }
import from jaclang.compiler.backends.native.na_compile_pass {
    unit_bitcode,
    unit_snapshot_text
}

test "a released module and its functions are freed without the cyclic collector" {
    module = ir.Module(context=ir.Context());
    i64 = ir.IntType(64);
    callee = ir.Function(module, ir.FunctionType(i64, [i64]), name="callee");
    caller = ir.Function(module, ir.FunctionType(i64, [i64, i64]), name="caller");
    builder = ir.IRBuilder(caller.append_basic_block("entry"));
    total = builder.add(caller.args[0], caller.args[1]);
    builder.ret(builder.call(callee, [total]));
    refs = [weakref.ref(module), weakref.ref(caller), weakref.ref(callee)];
    gc.disable();
    try {
        module.release();
        del module , callee , caller , builder , total;
        assert all(ref() is None for ref in refs) , [ref() for ref in refs];
    } finally {
        gc.enable();
    }
}

test "text snapshots preserve bitcode, symbols, and function counts" {
    module = ir.Module(name="snapshot_probe");
    i64 = ir.IntType(64);
    defined = ir.Function(module, ir.FunctionType(i64, []), name="defined");
    builder = ir.IRBuilder(defined.append_basic_block("entry"));
    builder.ret(ir.Constant(i64, 7));
    _ = ir.Function(module, ir.FunctionType(i64, []), name="declared");
    expected_bitcode = unit_bitcode(module);

    snapshot = unit_snapshot_text(str(module));
    assert snapshot.bitcode == expected_bitcode;
    assert snapshot.defined == {"defined"};
    assert snapshot.declared == {"declared"};
    assert snapshot.function_counts == (1, 1);
    restored = llvm.parse_bitcode(snapshot.bitcode);
    restored.verify();
    module.release();
}

test "target lookup restores the ctypes pointer signatures" {
    import ctypes;
    import jaclang.compiler.backends.native.llvm.binding.targets as targets;
    import from jaclang.compiler.backends.native.llvm.binding { Target, TargetMachine }
    llvm.initialize_native_target();
    get_target = targets.ffi.lib.LLVMPY_GetTargetFromTriple;
    create_machine = targets.ffi.lib.LLVMPY_CreateTargetMachine;
    create_data = targets.ffi.lib.LLVMPY_CreateTargetMachineData;
    previous_target_argtypes = get_target.argtypes;
    previous_target_restype = get_target.restype;
    previous_machine_argtypes = create_machine.argtypes;
    previous_machine_restype = create_machine.restype;
    previous_data_argtypes = create_data.argtypes;
    previous_data_restype = create_data.restype;
    try {
        get_target.argtypes = [];
        get_target.restype = ctypes.c_int;
        create_machine.argtypes = [];
        create_machine.restype = ctypes.c_int;
        create_data.argtypes = [];
        create_data.restype = ctypes.c_int;

        target = Target.from_default_triple();
        assert isinstance(target, Target);
        assert get_target.argtypes == previous_target_argtypes;
        assert get_target.restype is previous_target_restype;

        machine = target.create_target_machine();
        assert isinstance(machine, TargetMachine);
        assert create_machine.argtypes == previous_machine_argtypes;
        assert create_machine.restype is previous_machine_restype;

        data = machine.target_data;
        assert isinstance(data, targets.TargetData);
        assert create_data.argtypes == previous_data_argtypes;
        assert create_data.restype is previous_data_restype;
    } finally {
        get_target.argtypes = previous_target_argtypes;
        get_target.restype = previous_target_restype;
        create_machine.argtypes = previous_machine_argtypes;
        create_machine.restype = previous_machine_restype;
        create_data.argtypes = previous_data_argtypes;
        create_data.restype = previous_data_restype;
    }
}
