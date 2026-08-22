"""One warm-compile measurement of a fixed corpus, printed as JSON rows.

Run by `tests/compiler/test_compile_timing.jac` as a subprocess, once against
the checkout under test and once against a snapshot of the pinned baseline ref.
The probe lives outside both trees and is addressed by absolute path; which
compiler measures it is decided entirely by the subprocess cwd, because
`_jac_finder` resolves `[dev] jaclang_source` from the nearest `jac.toml` above
the cwd. So the same file, byte for byte, drives both halves of the comparison
and neither tree needs to carry a copy.

Corpus paths are resolved against the cwd and so name the sources of whichever
tree is being measured. The four phases are the schedules `JacCompiler`
`_compile_once` itself runs for a plain Python-lane module, driven here one at a
time so each is attributable; `full` is the whole-closure `JacProgram.compile`
that a real `jac run` pays. Every phase is measured warm: `phase_row` is called
once before any sample is kept, and the on-disk JIR cache is populated by that
first call.

Each phase reports the MINIMUM across the samples, not the mean. On a loaded
developer machine the mean is dominated by whatever else the box was doing; the
minimum is the sample least contaminated by it, and it is what makes two
processes minutes apart comparable at all. `JAC_TIMING_REPS` sets the sample
count (default 6, which is where the corpus stopped moving between runs here).
"""

import json;
import os;
import time;

import from pathlib { Path }
import from jaclang.jac0core.compiler {
    get_boundary_analysis_sched,
    get_ir_gen_sched,
    get_py_code_gen
}
import from jaclang.jac0core.program { JacProgram }

glob CORPUS: list[str] = [
         "jaclang/jac0core/srcloc.jac",
         "jaclang/jac0core/parser/tokens.jac",
         "jaclang/jac0core/passes/uni_pass.jac",
         "jaclang/jac0core/constant.jac",
         "examples/chess/chess.jac"
     ],
     PHASES: list[str] = ["parse", "ir_gen", "boundary", "codegen", "full"];

"""Time one pass of every phase over `src`, on programs nothing else has touched."""
def phase_row(src: str) -> dict {
    text = Path(src).read_text(encoding="utf-8");
    staged = JacProgram();
    t0 = time.perf_counter();
    mod = staged.parse_str(text, src);
    t1 = time.perf_counter();
    staged.run_schedule(mod, get_ir_gen_sched());
    t2 = time.perf_counter();
    staged.run_schedule(mod, get_boundary_analysis_sched());
    t3 = time.perf_counter();
    staged.run_schedule(mod, get_py_code_gen(native=False));
    t4 = time.perf_counter();
    errors = len(staged.errors_had);
    staged.release_compile_closure();
    whole = JacProgram();
    t5 = time.perf_counter();
    whole.compile(file_path=src);
    t6 = time.perf_counter();
    errors += len(whole.errors_had);
    whole.release_compile_closure();
    return {
        "parse": t1 - t0,
        "ir_gen": t2 - t1,
        "boundary": t3 - t2,
        "codegen": t4 - t3,
        "full": t6 - t5,
        "errors": errors
    };
}

with entry {
    tree = Path(os.getcwd());
    reps = int(os.environ.get("JAC_TIMING_REPS", "6"));
    for rel in CORPUS {
        src = str(tree / rel);
        best = phase_row(src);
        for _ in range(reps) {
            row = phase_row(src);
            for phase in PHASES {
                if row[phase] < best[phase] {
                    best[phase] = row[phase];
                }
            }
            best["errors"] += row["errors"];
        }
        best["rel"] = rel;
        best["reps"] = reps;
        print("TIMING_ROW " + json.dumps(best, sort_keys=True));
    }
}
