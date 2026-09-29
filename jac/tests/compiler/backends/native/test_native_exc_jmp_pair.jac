"""Native exception frames arm with `_setjmp` and unwind with `_longjmp`.

Plain `setjmp`/`longjmp` save and restore the signal mask -- a `sigprocmask`
(and on Darwin a `sigaltstack`) syscall on every armed frame and every raise,
which showed up in walker-spawn profiles. Jac never changes the mask across a
frame, so on Darwin and Linux the frames use the mask-free pair. The pair has
to match: Darwin's `longjmp` restores the mask from a buffer slot `_setjmp`
never writes. Windows and wasm keep the portable names; nogc builds lower
exceptions to error slots and arm no frames at all.

A frame's push and pop reach the thread's exception context, a per-thread
lookup; a function reads it once, at entry, and all its frames share it.
"""

import re;
import from pathlib { Path }
import from jaclang.compiler.driver.compile_options {
    push_native_target,
    pop_native_target
}
import from tests.support { assert_native_identity, program_ir }

glob FIXTURE = "exc_jmp_pair.jac";

def jmp_externs(triple: str) -> set[str] {
    prev = push_native_target(triple);
    try {
        ir_text = program_ir(FIXTURE, triple);
    } finally {
        pop_native_target(prev);
    }
    return set(re.findall(r'@"?(_?(?:set|long)jmp)"?\(', ir_text));
}

test "posix exception frames pair _setjmp with _longjmp" {
    for triple in ["aarch64-apple-darwin", "x86_64-unknown-linux-gnu"] {
        names = jmp_externs(triple);
        assert names == {"_setjmp", "_longjmp"} , f"{triple}: {sorted(names)}";
    }
}

test "windows exception frames keep setjmp with longjmp" {
    names = jmp_externs("x86_64-pc-windows-msvc");
    assert names == {"setjmp", "longjmp"} , sorted(names);
}

test "a function reads the exception context once for all its frames" {
    prev = push_native_target("aarch64-apple-darwin");
    try {
        ir_text = program_ir(FIXTURE, "aarch64-apple-darwin");
    } finally {
        pop_native_target(prev);
    }
    # `outer` arms two frames (its except and its finally).
    body = re.search(r'define [^\n]*\.outer"?\(.*?\n}', ir_text, re.S);
    assert body is not None , "no outer in the program IR";
    text = body.group(0);
    reads = re.findall(
        r'(%[\w."]+) = call [^\n]*@"?__jac_exception_context[.\d]*"?\(', text
    );
    assert len(reads) == 1 , text;
    # Every push and pop of its frames goes through that one read.
    frames = re.findall(
        r'call [^\n]*@"?__jac_exc_(?:push|pop)[.\d]*"?\(([^\n]*)\)', text
    );
    assert len(frames) >= 4 , text;
    for args in frames {
        assert args.endswith(f"ptr {reads[0]}") , args;
    }
}

test "frames armed and raised into repeatedly behave like Python" {
    source = str(Path(__file__).resolve().parent / "fixtures" / FIXTURE);
    out = assert_native_identity(source, profiles=["rc", "managed"]);
    assert "walker raises caught 1000" in out , out;
    assert "generator [3, 2, 1, 0] done" in out , out;
}
