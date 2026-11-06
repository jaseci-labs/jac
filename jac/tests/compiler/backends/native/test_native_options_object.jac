"""Native codegen driven by the compile-options object (#7871 workstream G).

The RC debug trace gate (#7854) must respond to CompileOptions.rc_debug_codegen
with no env var involved. The dependency IR cache the option fingerprint once
re-keyed is gone (#8943): a native unit's products live in its module JIR
under a `NativeStamp` that carries the codegen identity, so a flipped option
is a stamp mismatch the registry treats as an absent section.
"""

import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from unittest.mock { patch }
import from tests.support { cache_env }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.backends.native.link_plan {
    ArtifactKind,
    build_link_plan,
    link_artifact
}

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");


test "rc debug trace gate is driven by the options object, not env" {
    saved = os.environ.pop("JAC_RC_DEBUG_CODEGEN", None);
    try {
        for gate_on in [False, True] {
            with tempfile.TemporaryDirectory() as tmp {
                src = os.path.join(tmp, "rc_debug_trace.jac");
                shutil.copyfile(os.path.join(FIXTURES, "rc_debug_trace.jac"), src);
                opts = CompileOptions(
                    aot_mode=True,
                    skip_native_engine=True,
                    default_codespace='native',
                    na_gc_mode='cycles',
                    rc_debug_codegen=gate_on
                );
                prog = JacProgram();
                prog.options = opts;
                plan = build_link_plan(prog, [src], opts);
                assert not prog.errors_had , (
                    f"compile errors: {[str(e) for e in prog.errors_had]}"
                );
                binary = os.path.join(tmp, "rc_debug_trace");
                link_artifact(plan, binary, ArtifactKind.EXECUTABLE);
                run = subprocess.run(
                    [binary], capture_output=True, text=True, timeout=120
                );
                assert run.returncode == 0 , run.stderr[-800:];
                traced = "RC MALLOC" in run.stdout + run.stderr;
                if gate_on {
                    assert traced , "options-object gate ON compiled the trace out";
                } else {
                    assert not traced , (
                        "options-object gate OFF still compiled the trace in"
                    );
                }
            }
        }
    } finally {
        if saved is not None {
            os.environ["JAC_RC_DEBUG_CODEGEN"] = saved;
        }
    }
}
