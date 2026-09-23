"""Clock IDs follow the target libc even when cross compiling."""
import re;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

test "native clocks use the target libc clock IDs" {
    with tempfile.TemporaryDirectory() as directory {
        source = Path(directory) / "clocks.jac";
        source.write_text(
            "import time;\n"
            "def wall() -> float { return time.time(); }\n"
            "def mono() -> float { return time.monotonic(); }\n"
            "def perf() -> float { return time.perf_counter(); }\n"
            "def mono_ns() -> int { return time.monotonic_ns(); }\n"
            "def perf_ns() -> int { return time.perf_counter_ns(); }\n"
        );
        for (target, monotonic) in [
            ("x86_64-unknown-linux-gnu", "1"),
            ("aarch64-unknown-linux-gnu", "1"),
            ("x86_64-apple-darwin", "6"),
            ("arm64-apple-darwin", "6")
        ] {
            program = JacProgram();
            module = program.compile(
                str(source),
                options=CompileOptions(
                    native_target=target,
                    default_codespace="native",
                    skip_native_engine=True
                )
            );
            assert not program.errors_had , str(program.errors_had);
            clocks = re.findall(
                r'call i32 @"?clock_gettime"?\(i32 (\d+),', str(module.gen.llvm_ir)
            );
            assert sorted(clocks) == ["0"] + [monotonic] * 4 , f"{target}: {clocks}";
        }
    }
}
