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

    (bitcode, definitions, declarations, counts) = unit_snapshot_text(str(module));
    assert bitcode == expected_bitcode;
    assert definitions == {"defined"};
    assert declarations == {"declared"};
    assert counts == (1, 1);
    restored = llvm.parse_bitcode(bitcode);
    restored.verify();
    module.release();
}
