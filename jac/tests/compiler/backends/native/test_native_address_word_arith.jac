"""`int(addressof(x)) + C` adds without an overflow check: a user-space address
is below 2**56, so a constant offset smaller than that cannot leave i64. An
offset that is not a constant keeps the check."""
import from tests.support { compile_mir }
import from jaclang.compiler.driver.compile_options { CompileOptions }

test "a constant offset from an address word is a plain add" {
    options = CompileOptions(
        aot_mode=True,
        default_codespace="native",
        skip_native_engine=True,
        native_required=True,
        memory_profile="rc",
        no_ir_cache=True,
        native_target="x86_64-unknown-linux-gnu"
    );
    fx = compile_mir("address_word_arith.jac", options=options);
    text = fx.mir();
    head = f"fn @{fx.symbol('addr_offset')}(";
    assert head in text , text;
    body = text[text.index(head):];
    body = body[:body.index("\n}")];
    assert body.count(" = bin add ") == 2 , body;
    assert body.count(" = ovf add ") == 1 , body;
}
