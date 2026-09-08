import ctypes;
import from jaclang.compiler.frontend.unitree { Test }
import from jaclang.compiler.frontend.codeinfo { native_test_symbol }
import from jaclang.compiler.backends.native.lowering { native_lowering_issues }
import from tests.support { compile_native, get_func }

test "native test and entry scopes preserve module callable bindings" {
    (engine, module) = compile_native("native_test_scopes.jac");
    issues = native_lowering_issues(str(module.gen.llvm_ir));
    assert not issues , "\n".join(issue.detail for issue in issues);
    tests = module.get_all_sub_nodes(Test);
    assert len(tests) == 2;
    for item in tests {
        symbol = native_test_symbol(item.name.sym_name, item.loc.first_line);
        run_test = get_func(engine, symbol, ctypes.c_char_p);
        assert run_test() is None;
    }
    run_entry = get_func(engine, "jac_entry", None);
    run_entry();
}
