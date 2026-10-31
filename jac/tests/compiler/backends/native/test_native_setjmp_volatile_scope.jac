"""A `try` keeps in memory only the locals a raise could leave stale.

A function that arms a setjmp frame used to keep every local written after
the arming volatile, so a hot loop sharing a function with one cold `try` ran
every access through the stack. A local is now volatile only when a protected
body writes it before a call that can raise, and the path a raise lands on
reads it before writing it.
"""

import re;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from tests.support { assert_native_identity, compile_native_ir, NATIVE_FIXTURES }

glob FIXTURE = "setjmp_volatile_scope.jac";

def function_ir(text: str, name: str) -> str {
    body = re.search(r'define [^\n]*\.' + name + r'"?\(.*?\n}', text, re.S);
    assert body is not None , f"no {name} in the IR";
    return body.group(0);
}

def scope_ir -> str {
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
    return str(compile_native_ir(FIXTURE, options=options).gen.llvm_ir);
}

test "locals a raise cannot leave stale stay promotable" {
    text = scope_ir();
    for name in ["loop_after_try", "loop_inside_try", "stored_after_call"] {
        body = function_ir(text, name);
        assert "llvm.eh.sjlj.setjmp" in body , body;
        assert not re.search(r"(load|store) volatile", body) , body;
    }
}

test "a local the handler reads after the body wrote it stays volatile" {
    body = function_ir(scope_ir(), "read_in_handler");
    assert re.search(r'store volatile i64 7, i64\* %"seen', body) , body;
}

test "the scoped functions behave like Python" {
    out = assert_native_identity(
        f"{NATIVE_FIXTURES}/{FIXTURE}", profiles=["rc", "managed"]
    );
    assert out == "450 0\n45\n7 9\n-1 6\n" , out;
}
