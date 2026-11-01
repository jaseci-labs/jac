"""`&mut x` lends the address of x even when the C declaration that fixed
the symbol's ABI takes a plain `ptr[ptr[T]]`: dict.jac defines PyDict_Pop
that way while cpython_api.jac declares the parameter `&mut T | None`, and
the whole-program plan follows the definition. Passing x's value instead left
`metaclass=` unread in __build_class__."""
import from tests.support { KernelFixture, compile_mir }
import from jaclang.compiler.driver.compile_options { CompileOptions }

"""The MIR of function `name` in `fx`, as `MirFunction.render` prints it."""
def mir_function(fx: KernelFixture, name: str) -> str {
    text = fx.mir();
    head = f"fn @{fx.symbol(name)}(";
    assert head in text , f"{name} has no MIR in {fx.path}:\n{text}";
    body = text[text.index(head):];
    return body[:body.index("\n}") + 2];
}

"""The C calls of `callee` in function `name`'s MIR. A lent local is its slot
(`%name`); a value read from a local is a numbered temporary."""
def c_calls(fx: KernelFixture, name: str, callee: str) -> list[str] {
    return [
        line.strip()
        for line in mir_function(fx, name).splitlines()
        if f"call.c @{callee} " in line
    ];
}

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
    fx = compile_mir("clib_lend_mut.jac", options=options);
    stores = c_calls(fx, "lend_run", "lend_store");
    assert stores , fx.mir();
    assert all(line.endswith(" %seen") for line in stores) , stores;
    boxes = c_calls(fx, "lend_box_run", "lend_box");
    assert boxes , fx.mir();
    assert not any(line.endswith(" %slots") for line in boxes) , boxes;
}
