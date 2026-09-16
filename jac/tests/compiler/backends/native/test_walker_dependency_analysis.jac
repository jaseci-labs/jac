"""Inspection slices preserve target computations without executing body effects."""

import from types { SimpleNamespace }
import from jaclang.compiler.backends.native.llvm { ir, binding }
import from jaclang.compiler.backends.native.walker_speculation {
    NativeWalkerSpeculation
}
import from jaclang.compiler.backends.native.walker_dependencies {
    NativeDependencyInspection
}

def inspect(module: any, fn: any) -> any {
    host = NativeWalkerSpeculation(
        SimpleNamespace(llvm_module=module, osp_thunk_funcs={fn.name: fn})
    );
    result = NativeDependencyInspection(host, list(module.functions)).generate(
        fn, False
    );
    binding.parse_assembly(str(module)).verify();
    return result;
}

test "body-only pure computation is absent from the inspector" {
    module = ir.Module();
    word = ir.IntType(64);
    compute = ir.Function(module, ir.FunctionType(word, [word]), "compute");
    b = ir.IRBuilder(compute.append_basic_block("entry"));
    b.ret(b.mul(compute.args[0], compute.args[0]));
    fn = ir.Function(
        module,
        ir.FunctionType(ir.VoidType(), [word.as_pointer(), word.as_pointer()]),
        "step"
    );
    b = ir.IRBuilder(fn.append_basic_block("entry"));
    b.store(b.call(compute, [b.load(fn.args[0])]), fn.args[1]);
    b.ret_void();
    result = str(inspect(module, fn));
    assert "compute" not in result;
    assert "__jac_inspect_access" in result;
    assert "ret void" in result;
}

test "address helpers and their return aliases survive the slice" {
    module = ir.Module();
    word = ir.IntType(64);
    helper = ir.Function(
        module, ir.FunctionType(word.as_pointer(), [word.as_pointer()]), "alias"
    );
    b = ir.IRBuilder(helper.append_basic_block("entry"));
    b.ret(helper.args[0]);
    fn = ir.Function(
        module, ir.FunctionType(ir.VoidType(), [word.as_pointer()]), "step"
    );
    b = ir.IRBuilder(fn.append_basic_block("entry"));
    target = b.call(helper, [fn.args[0]]);
    b.store(ir.Constant(word, 7), target);
    b.ret_void();
    result = str(inspect(module, fn));
    assert "__jac_inspect_alias" in result;
    assert "__jac_inspect_write" in result;
}

test "an escaped local query argument retains its initialization" {
    module = ir.Module();
    word = ir.IntType(64);
    query = ir.Function(module, ir.FunctionType(word, [word.as_pointer()]), "query");
    b = ir.IRBuilder(query.append_basic_block("entry"));
    b.ret(b.load(query.args[0]));
    fn = ir.Function(
        module, ir.FunctionType(ir.VoidType(), [word.as_pointer()]), "step"
    );
    b = ir.IRBuilder(fn.append_basic_block("entry"));
    local = b.alloca(word);
    b.store(ir.Constant(word, 123), local);
    index = b.call(query, [local]);
    b.store(ir.Constant(word, 4), b.gep(fn.args[0], [index]));
    b.ret_void();
    result = str(inspect(module, fn));
    assert "store i64 123" in result;
    assert "__jac_inspect_query" in result;
}

test "recursive targets produce an unknown inspection without a recursive inspector" {
    module = ir.Module();
    word = ir.IntType(64);
    recursive = ir.Function(module, ir.FunctionType(word, [word]), "recursive");
    b = ir.IRBuilder(recursive.append_basic_block("entry"));
    b.ret(b.call(recursive, [recursive.args[0]]));
    fn = ir.Function(
        module, ir.FunctionType(ir.VoidType(), [word.as_pointer()]), "step"
    );
    b = ir.IRBuilder(fn.append_basic_block("entry"));
    index = b.call(recursive, [ir.Constant(word, 0)]);
    b.store(ir.Constant(word, 3), b.gep(fn.args[0], [index]));
    b.ret_void();
    inspect(module, fn);
    result = str(module.globals["__jac_inspect_recursive"]);
    assert "__jac_inspect_unknown" in result;
    assert "__jac_spec_abort" in result;
    assert "call i64 @\"__jac_inspect_recursive\"" not in result;
}

test "unknown external effects retain subsequent known access declarations" {
    module = ir.Module();
    word = ir.IntType(64);
    external = ir.Function(
        module, ir.FunctionType(ir.VoidType(), []), "external_effect"
    );
    fn = ir.Function(
        module, ir.FunctionType(ir.VoidType(), [word.as_pointer()]), "step"
    );
    b = ir.IRBuilder(fn.append_basic_block("entry"));
    b.call(external, []);
    b.store(ir.Constant(word, 5), fn.args[0]);
    b.ret_void();
    result = str(inspect(module, fn));
    assert "__jac_inspect_external_" in result;
    assert result.index("__jac_inspect_external_")
        < result.index("__jac_inspect_access\"");
    assert "call void @\"external_effect\"" not in result;
}

test "an unknown branch conservatively preserves argument targets from both arms" {
    module = ir.Module();
    word = ir.IntType(64);
    predicate = ir.Function(
        module, ir.FunctionType(ir.IntType(1), []), "unknown_predicate"
    );
    fn = ir.Function(
        module,
        ir.FunctionType(ir.VoidType(), [word.as_pointer(), word.as_pointer()]),
        "step"
    );
    b = ir.IRBuilder(fn.append_basic_block("entry"));
    yes = fn.append_basic_block("yes");
    no = fn.append_basic_block("no");
    b.cbranch(b.call(predicate, []), yes, no);
    b = ir.IRBuilder(yes);
    b.store(ir.Constant(word, 1), fn.args[0]);
    b.ret_void();
    b = ir.IRBuilder(no);
    b.store(ir.Constant(word, 2), fn.args[1]);
    b.ret_void();
    result = inspect(module, fn);
    declarations = [
        inst
        for inst in result.blocks[0].instructions
        if inst.opname == "call" and inst.callee.name == "__jac_inspect_access"
    ];
    assert len(declarations) == 2;
    assert "unknown_predicate\"()" not in str(result);
}
