"""Stack promotion of owned locals with frame-local borrows (#7857 Phase A).

An `own` local that is never moved out, never sealed, and whose only
call-position uses are checked borrows (`&`/`&mut` args to borrow-annotated
params with scalar returns) or attribute reads may live on the stack instead
of the heap. The escape facts come from RcFactsPass consuming the ownership
annotations; a returned owner stays on the heap. rc-stats reports the count
as `promoted=N`.
"""

import os;
import subprocess;
import from tests.support {
    KernelFixture,
    TESTS_DIR,
    compile_mir,
    compile_native_ir,
    jac_command,
    names_function
}
import from jaclang.compiler.driver.compile_options {
    CompileOptions,
    push_native_target,
    pop_native_target
}
import from jaclang.compiler.backends.native.mir.emit { RELEASE_SYMBOL }

glob FIXDIR = os.path.join(TESTS_DIR, "compiler", "backends", "native", "fixtures"),
     FIXTURE = os.path.join(FIXDIR, "stack_promotion.jac");

"""The decision step's verdict on the promotion fixture for a memory mode."""
def _compile_mir(gc_mode: str, enforce: bool) -> KernelFixture {
    prev = push_native_target("wasm32-unknown-unknown");
    try {
        return compile_mir(
            "stack_promotion.jac",
            FIXDIR,
            CompileOptions(aot_mode=True, na_gc_mode=gc_mode, nogc_enforce_all=enforce)
        );
    } finally {
        pop_native_target(prev);
    }
}

"""The MIR of function `name` in `fx`, as `MirFunction.render` prints it."""
def mir_function(fx: KernelFixture, name: str) -> str {
    text = fx.mir();
    head = f"fn @{fx.symbol(name)}(";
    assert head in text , f"{name} has no MIR in {fx.path}:\n{text}";
    body = text[text.index(head):];
    return body[:body.index("\n}") + 2];
}

"""Whether a function's MIR puts an object on the heap: a constructor call,
the runtime allocator, or a C allocation."""
def heap_allocates(body: str) -> bool {
    return any(
        marker in body
        for marker in (".__ctor", "@__jac_rt_alloc", "@malloc", "@calloc")
    );
}

test "managed mode: borrowed-only owner is stack-promoted" {
    body = mir_function(_compile_mir("cycles", False), "promoted_frame");
    assert not heap_allocates(body) , body;
}

test "managed mode: returned owner stays on the heap" {
    body = mir_function(_compile_mir("cycles", False), "escaping_frame");
    assert heap_allocates(body) , body;
}

test "headerless mode: borrowed-only owner is stack-promoted" {
    body = mir_function(_compile_mir("none", True), "promoted_frame");
    assert not heap_allocates(body) , body;
}

test "jac explain memory reports the promoted count" {
    res = subprocess.run(
        jac_command("explain", "memory", FIXTURE, "--memory", "rc"),
        capture_output=True,
        text=True
    );
    assert res.returncode == 0 , res.stderr;
    assert "promoted=1" in res.stderr , res.stderr;
}

test "a C record of raw pointers lent to C lives on the stack" {
    fx = compile_mir("stack_promotion_c.jac", FIXDIR, CompileOptions(aot_mode=True));
    body = mir_function(fx, "lend_slots");
    assert not heap_allocates(body) , body;
}

test "a local also bound to a heap record is still released" {
    fx = compile_native_ir("stack_promotion_c.jac", FIXDIR, CompileOptions(aot_mode=True));
    body = "";
    for block in fx.llvm_ir().split("\ndefine ")[1:] {
        if names_function(block.split("\n")[0], "rebind_slots") {
            body = block[:block.index("\n}")];
            break;
        }
    }
    assert body , "rebind_slots is not defined in the IR";
    assert RELEASE_SYMBOL in body , body;
}

test "a named function used as a Callable is a static closure" {
    fx = compile_mir("stack_promotion_c.jac", FIXDIR, CompileOptions(aot_mode=True));
    body = mir_function(fx, "apply_named");
    assert not heap_allocates(body) , body;
}
