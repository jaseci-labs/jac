"""A shared object built with native TLS and builtin setjmp agrees on both.

JacPython links one shared object whose units share the thread-local accessors
and the raise path, so no unit may reach a thread-local slot through a pthread
key, and on x86_64 no frame may arm through libc's setjmp. The runtime units
are part of that object too: the UTF-8 cursor cache once read its block
through pthread_getspecific, and the raise path jumped through libc's
_longjmp."""

import re;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.backends.native.link_glue { init_object_codegen }
import from jaclang.compiler.backends.native.link_plan {
    ArtifactKind,
    build_link_plan,
    whole_program_module,
    _platform_of
}
import from pathlib { Path }
import from tests.support { NATIVE_FIXTURES }

def _callers(ir_text: str, symbol: str) -> list[str] {
    found: list[str] = [];
    for function in re.finditer(
        r'^define [^\n]*?@"?([\w.$]+)"?\((.*?)^\}', ir_text, re.M | re.S
    ) {
        if re.search('@"?' + re.escape(symbol) + r'"?\(', function.group(2)) {
            found.append(function.group(1));
        }
    }
    return found;
}

test "a native-tls builtin-sjlj shared object calls neither pthread keys nor _setjmp" {
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
    program = JacProgram();
    plan = build_link_plan(
        program, [str(Path(NATIVE_FIXTURES) / "shared_tls_sjlj.jac")], options
    );
    assert not program.errors_had , [e.pretty_print() for e in program.errors_had];
    init_object_codegen();
    spec = plan.glue_spec(ArtifactKind.SHARED, _platform_of(plan.triple), False);
    (compiled, _) = whole_program_module(plan, spec);
    text = str(compiled);
    assert _callers(text, "pthread_getspecific") == [];
    assert _callers(text, "_setjmp") == [];
    assert _callers(text, "_longjmp") == [];
    assert "@llvm.eh.sjlj.setjmp(" in text;
    assert "@llvm.eh.sjlj.longjmp(" in text;
    # A dlopen'd object takes initial-exec TLS from a small static surplus, so
    # a large block must sit behind a pointer cell rather than in the TLS image.
    oversized = [
        m.group(1)
        for m in re.finditer(
            r'^@"?([\w.$]+)"? = [^\n]*thread_local\(initialexec\)[^\n]*\[(\d+) x i64\]',
            text,
            re.M
        )
        if int(m.group(2)) * 8 > 64
    ];
    assert oversized == [] , oversized;
    assert "jac_rt_dtoa.tlsp" in text;
    compiled.verify();
}
