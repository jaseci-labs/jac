"""Whole-ability speculation is observationally equivalent to serial walkers."""

import json;
import os;
import platform;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { JAC_ROOT, TESTS_DIR, jac_command }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.project.config { NativeConfig }
import from jaclang.compiler.backends.native.walker_speculation {
    walker_speculation_enabled
}

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler/backends/native/fixtures/walker_speculation.jac"
     ),
     STATS = """
import from c {
    def __jac_spec_get_peak -> int;
    def __jac_spec_get_commits -> int;
    def __jac_spec_get_fallbacks -> int;
    def __jac_spec_get_active -> int;
}
with entry {
    print("speculation", __jac_spec_get_peak(), __jac_spec_get_commits(),
        __jac_spec_get_fallbacks(), __jac_spec_get_active());
}
""";

test "speculation gates and cache identities describe the actual execution mode" {
    default_options = CompileOptions(aot_mode=True, memory_profile="rc");
    assert NativeConfig().walker_speculation == "off";
    assert default_options.walker_speculation == "off";
    assert not walker_speculation_enabled(default_options, "x86_64-unknown-linux-gnu");
    enabled = CompileOptions(
        aot_mode=True, memory_profile="rc", walker_speculation="auto"
    );
    assert walker_speculation_enabled(enabled, "x86_64-unknown-linux-gnu");
    assert not walker_speculation_enabled(enabled, "wasm32-unknown-wasi");
    assert not walker_speculation_enabled(
        CompileOptions(memory_profile="rc", walker_speculation="auto"),
        "x86_64-unknown-linux-gnu"
    );
    assert not walker_speculation_enabled(
        CompileOptions(aot_mode=True, walker_speculation="auto"),
        "x86_64-unknown-linux-gnu"
    );
    disabled = CompileOptions(
        aot_mode=True, memory_profile="rc", walker_speculation="off"
    );
    assert not walker_speculation_enabled(disabled, "x86_64-unknown-linux-gnu");
    assert default_options.codegen_identity() == disabled.codegen_identity();
    assert enabled.codegen_identity() != disabled.codegen_identity();
    imported = enabled.clone_for_native_import();
    assert imported.walker_speculation == "auto";
    assert imported.native_threads == enabled.native_threads;
    try {
        CompileOptions(walker_speculation="invalid");
        assert False;
    } except ValueError {}
}

test "native reports aliases containers queries and fallback match serial execution" {
    if platform.system() != "Linux"
        or platform.machine() not in ("x86_64", "aarch64") {
        return;
    }
    with tempfile.TemporaryDirectory() as tmp {
        source = Path(tmp) / "walk.jac";
        outputs: list[str] = [];
        for (mode, width) in [("off", 4), ("auto", 1), ("auto", 2), ("auto", 4)] {
            code = Path(FIXTURE).read_text();
            if mode == "auto" {
                if width > 1 {
                    code = code.replace(
                        "allocation_root spawn allocator;",
                        "before_commits: int = __jac_spec_get_commits();\n"
                            + "allocation_root spawn allocator;\n"
                            + "after_commits: int = __jac_spec_get_commits();\n"
                            + "assert after_commits >= before_commits + 4;"
                    );
                }
                code += STATS;
            }
            source.write_text(code);
            (Path(tmp) / "jac.toml").write_text(
                "[dev]\njaclang_source = "
                    + json.dumps(JAC_ROOT)
                    + "\n[native]\nwalker_speculation = "
                    + json.dumps(mode)
                    + "\nthreads = "
                    + str(width)
                    + "\n"
            );
            binary = os.path.join(tmp, mode + str(width));
            built = subprocess.run(
                jac_command(
                    "build", "--native", "--memory", "rc", str(source), "-o", binary
                ),
                cwd=tmp,
                capture_output=True,
                text=True,
                timeout=600
            );
            assert built.returncode == 0 , built.stderr + built.stdout;
            ran = subprocess.run([binary], capture_output=True, text=True, timeout=30);
            assert ran.returncode == 0 , ran.stderr;
            output = ran.stdout;
            if mode == "auto" {
                lines = output.splitlines(keepends=True);
                stats = lines.pop().split();
                assert stats[0] == "speculation" , output;
                assert int(stats[4]) == 0;
                if width > 1 {
                    assert 2 <= int(stats[1]) <= width;
                    assert int(stats[2]) >= 4;
                    assert int(stats[3]) > 0;
                } else {
                    assert stats[1:] == ["0", "0", "0", "0"];
                }
                output = "".join(lines);
            }
            outputs.append(output);
        }
        assert all(output == outputs[0] for output in outputs);
        assert "external 2" in outputs[0];
        assert "10\n" in outputs[0];
        assert outputs[0].endswith("19 10\n");
    }
}

test "nogc walkers keep using the serial kernel" {
    if platform.system() != "Linux" {
        return;
    }
    with tempfile.TemporaryDirectory() as tmp {
        source = Path(FIXTURE).parent / "nogc/nogc_osp.jac";
        binary = os.path.join(tmp, "nogc");
        built = subprocess.run(
            jac_command(
                "build", "--native", "--memory", "nogc", str(source), "-o", binary
            ),
            capture_output=True,
            text=True,
            timeout=600
        );
        assert built.returncode == 0 , built.stderr + built.stdout;
        ran = subprocess.run([binary], capture_output=True, text=True, timeout=30);
        assert ran.returncode == 0 , ran.stderr;
        assert ran.stdout == "7\n";
    }
}
