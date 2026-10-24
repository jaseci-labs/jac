"""A Jac def used as a C function pointer has one address.

C compares function pointers for identity: CPython's subtype_dealloc walks
the bases while `tp_dealloc == subtype_dealloc`. A def declared without
`-> T` returns a word while the C slot it fills says void, and each C-typed
use used to get its own trampoline, so the slot and `ptr(f)` differed and
that walk never ended.
"""
import from tests.support { compile_native_ir }
import from jaclang.compiler.driver.compile_options { CompileOptions }

test "a callback slot and ptr(f) agree on a def's and a C function's address" {
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
        compile_native_ir("clib_callback_identity.jac", options=options).gen.llvm_ir
    );
    trampolines = [
        line
        for line in text.splitlines()
        if line.startswith("define")
            and ".drop_item.__clibcb." in line
            and ".escape" not in line
    ];
    assert len(trampolines) == 1 , trampolines;
    assert "free.__clibcb" not in text;
}
