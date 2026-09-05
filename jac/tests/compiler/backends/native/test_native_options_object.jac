"""Native codegen driven by the compile-options object (#7871 workstream G).

The RC debug trace gate (#7854) must respond to CompileOptions.rc_debug_codegen
with no env var involved. The dependency IR cache the option fingerprint once
re-keyed is gone (#8943): a native unit's products live in its module JIR
under a `NativeStamp` that carries the codegen identity, so a flipped option
is a stamp mismatch the registry treats as an absent section.
"""

import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");


test "rc debug trace gate is driven by the options object, not env" {
    saved = os.environ.pop("JAC_RC_DEBUG_CODEGEN", None);
    try {
        for gate_on in [False, True] {
            with tempfile.TemporaryDirectory() as tmp {
                src = os.path.join(tmp, "rc_debug_trace.jac");
                shutil.copyfile(os.path.join(FIXTURES, "rc_debug_trace.jac"), src);
                prog = JacProgram();
                ir_mod = prog.compile(
                    file_path=src,
                    options=CompileOptions(
                        aot_mode=True,
                        skip_native_engine=True,
                        default_codespace='native',
                        force_target_program=True,
                        na_gc_mode='cycles',
                        rc_debug_codegen=gate_on
                    )
                );
                assert not prog.errors_had , (
                    f"compile errors: {[str(e) for e in prog.errors_had]}"
                );
                assert ir_mod.gen.llvm_ir is not None;
                ir_text = str(ir_mod.gen.llvm_ir);
                if gate_on {
                    assert "RC MALLOC" in ir_text , (
                        "options-object gate ON compiled the trace out"
                    );
                } else {
                    assert "RC MALLOC" not in ir_text , (
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
