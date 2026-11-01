"""Lowered code is the same for every 64-bit release target (#10219).

What a C library spells, lays out or numbers per target lives in the runtime
floor (posix_floor.c, win_floor.c), so the LLVM IR the kernel emits for a
unit differs between targets only in its `target triple` and `target
datalayout` lines. That is what lets one builder lower the compiler kernel
for every release target. This gate lowers a probe that reaches each former
target-dependent site, and the bundled units the kernel imports, for every
release triple and compares them.
"""
import os;
import from pathlib { Path }
import from tests.support { compile_native_ir }
import from jaclang.compiler.driver.compile_options {
    CompileOptions,
    push_native_target,
    pop_native_target
}
import from jaclang.compiler.frontend.codeinfo { native_stdlib_root }

glob TRIPLES: list[str] = [
         "x86_64-unknown-linux-gnu",
         "aarch64-unknown-linux-gnu",
         "arm64-apple-macosx11.0.0",
         "x86_64-apple-macosx10.15.0"
     ],
     FIXTURES: Path = Path(__file__).resolve().parent / "fixtures";

def _lowered_ir(path: str, triple: str) -> str {
    prev = push_native_target(triple);
    try {
        fx = compile_native_ir(
            path,
            "",
            CompileOptions(
                aot_mode=True, default_codespace="native", native_target=triple
            )
        );
        text = fx.llvm_ir();
        assert text , f"{path} lowered no IR for {triple}";
    } finally {
        pop_native_target(prev);
    }
    return "\n".join(
        line
        for line in text.splitlines()
        if not line.startswith(("target triple", "target datalayout"))
    );
}

def _assert_neutral(path: str) {
    reference = _lowered_ir(path, TRIPLES[0]);
    for triple in TRIPLES[1:] {
        other = _lowered_ir(path, triple);
        if other != reference {
            import difflib;
            diff = "\n".join(
                list(
                    difflib.unified_diff(
                        reference.splitlines(),
                        other.splitlines(),
                        TRIPLES[0],
                        triple,
                        lineterm="",
                        n=1
                    )
                )[:60]
            );
            assert False , f"{os.path.basename(path)} lowers differently for {triple}:\n{diff}";
        }
    }
}

test "a probe of every former target-dependent site lowers identically" {
    _assert_neutral(str(FIXTURES / "target_neutral_probe.jac"));
}

test "the bundled units behind the floor lower identically" {
    stdlib = native_stdlib_root();
    assert stdlib is not None;
    for name in [
        "_time_native.jac",
        "_fd_native.jac",
        "_errno_platform.jac",
        "_dirent_native.jac",
        "_directory_native.jac",
        "_user_home.jac",
        "_math_fused.jac",
        "_digest.jac"
    ] {
        _assert_neutral(os.path.join(stdlib, name));
    }
}
