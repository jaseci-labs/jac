"""Native exception frames arm with `_setjmp` and unwind with `_longjmp`.

Plain `setjmp`/`longjmp` save and restore the signal mask -- a `sigprocmask`
(and on Darwin a `sigaltstack`) syscall on every armed frame and every raise,
which showed up in walker-spawn profiles. Jac never changes the mask across a
frame, so on Darwin and Linux the frames use the mask-free pair. The pair has
to match: Darwin's `longjmp` restores the mask from a buffer slot `_setjmp`
never writes. Windows and wasm keep the portable names; nogc builds lower
exceptions to error slots and arm no frames at all.
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

test "frames armed and raised into repeatedly behave like Python" {
    source = str(Path(__file__).resolve().parent / "fixtures" / FIXTURE);
    out = assert_native_identity(source, profiles=["rc", "managed"]);
    assert "walker raises caught 1000" in out , out;
    assert "generator [3, 2, 1, 0] done" in out , out;
}
