"""`@__preserve_none` gives C definitions and calls through C records'
function-pointer fields LLVM's preserve_none calling convention.

CPython's tail-call interpreter defines every instruction handler this way
and dispatches through a table of them; a Jac handler has to match it to take
a slot in that table and to tail-call the next handler."""
import ctypes;
import re;
import from tests.support { compile_native, compile_native_ir, get_func }
import from jaclang.compiler.driver.compile_options { CompileOptions }

"""The body of the function defined as `symbol` in `text`."""
def defined_body(text: str, symbol: str) -> str {
    found = re.search(
        r'^define [^\n]*@"?' + re.escape(symbol) + r'"?\(.*?\n}\n', text, re.S | re.M
    );
    assert found is not None , f"{symbol} is not defined in the IR";
    return found.group(0);
}

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
    text = compile_native_ir("clib_preserve_none.jac", options=options).llvm_ir();
    assert re.search(r'^define preserve_nonecc i64 @"?pn_count"?\(', text, re.M) , text;
    assert "musttail call preserve_nonecc i64 %" in text , text;
    assert re.search(r'(?<!musttail )call preserve_nonecc i64 %', text) , text;
}

test "preserve_none handlers tail-call each other in constant stack" {
    (engine, _) = compile_native("clib_preserve_none.jac");
    run = get_func(engine, "pn_run", ctypes.c_int64, ctypes.c_int64);
    assert run(100) == 5050 * 1000 + 100;
    # A million hops: only a frame-reusing tail call gets through this.
    steps = 1000000;
    assert run(steps) == (steps * (steps + 1) // 2) * 1000 + steps;
}

test "a tail call to a C function returning a pointer takes the caller's prototype" {
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
    text = compile_native_ir("clib_preserve_none_extern.jac", options=options).llvm_ir();
    # The Jac body keeps pointers as words, so the call is made through the
    # body's own prototype and nothing (no pointer-to-word conversion) follows.
    lines = text.splitlines();
    tails = [
        index
        for (index, line) in enumerate(lines)
        if "musttail call preserve_nonecc i64 " in line
    ];
    assert len(tails) == 2 , text;
    for index in tails {
        assert lines[index + 1].strip().startswith("ret i64 ") , "\n".join(
            lines[index - 2:index + 3]
        );
    }
}

test "a runtime build's handler body takes its C symbol" {
    options = CompileOptions(
        aot_mode=True,
        default_codespace="native",
        skip_native_engine=True,
        native_required=True,
        memory_profile="rc",
        no_ir_cache=True,
        native_target="x86_64-unknown-linux-gnu",
        native_tls=True,
        native_sjlj=True,
        native_unchecked_views=True,
        native_direct_c_entries=True
    );
    text = compile_native_ir("clib_preserve_none_mixed.jac", options=options).llvm_ir();
    # The handler's body takes its C symbol: no thunk jumps into a separate
    # Jac copy.
    assert re.search(r'^define preserve_nonecc i64 @"?pn_hop"?\(', text, re.M) , text;
    assert '@"pn_hop.jac"' not in text , text;
    defined_body(text, "plain_entry");
}
