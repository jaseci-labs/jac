"""A released IR module is freed by reference counting alone."""
import gc;
import weakref;
import from jaclang.compiler.backends.native.llvm { ir }

test "a released module and its functions are freed without the cyclic collector" {
    module: ir.Module = ir.Module(context=ir.Context());
    i64: ir.IntType = ir.IntType(64);
    callee: ir.Function = ir.Function(
        module, ir.FunctionType(i64, [i64]), name="callee"
    );
    caller: ir.Function = ir.Function(
        module, ir.FunctionType(i64, [i64, i64]), name="caller"
    );
    block: ir.Block = caller.append_basic_block("entry");
    builder: ir.IRBuilder = ir.IRBuilder(block);
    total: ir.Value = builder.add(caller.args[0], caller.args[1]);
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
