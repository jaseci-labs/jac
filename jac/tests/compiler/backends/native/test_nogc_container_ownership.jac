"""Owned str containers under --memory nogc own their elements.

Fresh strings move into list/set/dict containers, named bindings and string
literals are copied in, and the headerless container drop frees the elements
it owns -- all with zero RC calls in the emitted IR (the zero-RC contract of
--memory nogc).
"""

import os;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { compile_native_ir, jac_command }
import from jaclang.compiler.driver.compile_options {
    CompileOptions,
    push_native_target,
    pop_native_target
}
import from jaclang.compiler.backends.native.mir.emit {
    RELEASE_ACYCLIC_SYMBOL,
    RELEASE_SYMBOL,
    RETAIN_SYMBOL
}

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures" / "nogc"),
     PROG = "str_container_prog.jac";

def _compile_ir(fixture: str) -> str {
    prev = push_native_target("wasm32-unknown-unknown");
    try {
        return compile_native_ir(
            fixture,
            FIXTURES,
            CompileOptions(aot_mode=True, memory_profile="nogc")
        ).llvm_ir();
    } finally {
        pop_native_target(prev);
    }
}

test "str containers compile RC-free" {
    ir = _compile_ir(PROG);
    assert ir , "no LLVM IR emitted for the nogc str container program";
    for symbol in (RETAIN_SYMBOL, RELEASE_SYMBOL, RELEASE_ACYCLIC_SYMBOL, "__rc_") {
        assert symbol not in ir , f"str container build re-entered the RC world: {symbol}";
    }
}

test "host binary runs str containers and passes assert-no-rc" {
    src = os.path.join(FIXTURES, PROG);
    out_bin = os.path.join(tempfile.mkdtemp(), "strcont.bin");
    comp = subprocess.run(
        jac_command("build", "--native", src, "--memory", "nogc", "-o", out_bin),
        capture_output=True,
        text=True,
        timeout=300
    );
    combined = (comp.stdout or "") + (comp.stderr or "");
    assert comp.returncode == 0 , f"nacompile failed: {combined[-900:]}";
    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=60);
    assert proc.returncode == 0 , f"binary failed: {proc.stderr[-400:]
        if proc.stderr
        else '(empty)'}";
    out = proc.stdout.strip().split("\n");
    assert out == ["4", "x0", "lit", "keep7", "v1", "w", "1"] , f"str container output mismatch: {out}";
}
