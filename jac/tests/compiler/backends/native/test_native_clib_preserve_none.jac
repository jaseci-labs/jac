"""`@__preserve_none` gives C definitions and calls through C records'
function-pointer fields LLVM's preserve_none calling convention.

CPython's tail-call interpreter defines every instruction handler this way
and dispatches through a table of them; a Jac handler has to match it to take
a slot in that table and to tail-call the next handler."""
import ctypes;
import from tests.support { compile_native, compile_native_ir, get_func }
import from jaclang.compiler.driver.compile_options { CompileOptions }

test "preserve_none definitions and table calls lower with the convention" {
    options = CompileOptions(
        aot_mode=True,
        default_codespace="native",
        skip_native_engine=True,
        native_required=True,
        memory_profile="rc",
        no_ir_cache=True,
        native_target="x86_64-unknown-linux-gnu",
        native_tls=True,
        native_sjlj=True
    );
    text = str(
        compile_native_ir("clib_preserve_none.jac", options=options).gen.llvm_ir
    );
    assert 'define preserve_nonecc i64 @"pn_count"(' in text , text;
    assert "musttail call preserve_nonecc i64 %\"step.fn\"" in text , text;
    assert "call preserve_nonecc i64 %\"step.fn\"(" in text , text;
}

test "preserve_none handlers tail-call each other in constant stack" {
    (engine, _) = compile_native("clib_preserve_none.jac");
    run = get_func(engine, "pn_run", ctypes.c_int64, ctypes.c_int64);
    assert run(100) == 5050 * 1000 + 100;
    # A million hops: only a frame-reusing tail call gets through this.
    steps = 1000000;
    assert run(steps) == (steps * (steps + 1) // 2) * 1000 + steps;
}
