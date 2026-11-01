import ctypes;
import re;
import from tests.support { compile_mir, compile_native, get_func }

test "native test and entry scopes preserve module callable bindings" {
    (engine, fx) = compile_native("native_test_scopes.jac");
    demoted = compile_mir("native_test_scopes.jac").demoted();
    assert not demoted , str(demoted);
    symbols = sorted(
        set(
            re.findall(
                r'define [^@\n]*@"?([^"(\s]*__jac_test_[^"(\s]*)"?\(', fx.llvm_ir()
            )
        )
    );
    assert len(symbols) == 2 , str(symbols);
    for symbol in symbols {
        run_test = get_func(engine, symbol, ctypes.c_char_p);
        assert run_test() is None;
    }
    run_entry = get_func(engine, "jac_entry", None);
    run_entry();
}
