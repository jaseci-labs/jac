"""`&mut x` lends the address of x even when the C declaration that fixed
the symbol's ABI takes a plain `ptr[ptr[T]]`: dict.jac defines PyDict_Pop
that way while cpython_api.jac declares the parameter `&mut T | None`, and
the whole-program plan follows the definition. Passing x's value instead left
`metaclass=` unread in __build_class__."""
import from tests.support { compile_native_ir }
import from jaclang.compiler.driver.compile_options { CompileOptions }

test "an &mut argument to a plain pointer parameter lends the variable's address" {
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
    text = str(compile_native_ir("clib_lend_mut.jac", options=options).gen.llvm_ir);
    calls = [
        line
        for line in text.split("\n")
        if "call i32 @\"lend_store\"(" in line
    ];
    assert calls , text;
    assert all("clib.lend." in line for line in calls) , calls;
    box_calls = [
        line
        for line in text.split("\n")
        if "@\"lend_box\"(" in line and "call " in line
    ];
    assert box_calls , text;
    assert not any("clib.lend." in line for line in box_calls) , box_calls;
}
