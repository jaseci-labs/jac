"""`int(addressof(x)) + C` adds without an overflow check: a user-space address
is below 2**56, so a constant offset smaller than that cannot leave i64. An
offset that is not a constant keeps the check."""
import from tests.support { compile_native_ir }
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
    text = str(
        compile_native_ir("address_word_arith.jac", options=options).gen.llvm_ir
    );
    body = text[text.index('@"addr_offset"('):];
    body = body[:body.index("\n}\n")];
    assert "addr.add" in body , body;
    assert body.count("sadd.with.overflow") == 1 , body;
}
