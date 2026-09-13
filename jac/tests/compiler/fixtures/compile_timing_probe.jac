"""One warm-compile measurement of a fixed corpus, printed as JSON rows.

Run by `tests/compiler/test_compile_timing.jac` as a subprocess, once against
the checkout under test and once against a snapshot of the pinned baseline ref.
The probe lives outside both trees and is addressed by absolute path; which
compiler measures it is decided entirely by the subprocess cwd, because
`_jac_finder` resolves `[dev] jaclang_source` from the nearest `jac.toml` above
the cwd. So the same file, byte for byte, drives both halves of the comparison
and neither tree needs to carry a copy.

Corpus paths name sources in the measured checkout. The normal compilation
request records phase timings in the executor; the probe reads those records
instead of maintaining a second pass schedule. Phase values include dependency
work and can overlap when one module requests another. They are not an additive
breakdown of wall time. `full` is the measured compilation's elapsed time, and
`check` is a fresh-program diagnostic request with interface replay enabled.

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
import from jaclang.compiler.session.options { CompileOptions }
import from jaclang.compiler.pipeline.schedule { CompilationPhase }
import from jaclang.compiler.session.session { JacProgram }

glob CORPUS: list[str] = [
         "jaclang/compiler/frontend/source_locations.jac",
         "jaclang/compiler/frontend/parser/tokens.jac",
         "jaclang/compiler/pipeline/uni_pass.jac",
         "jaclang/compiler/ir/enums.jac",
         "examples/chess/chess.jac"
     ],
     PHASES: list[str] = [
         "parse",
         "ir_gen",
         "analysis",
         "boundary",
         "codegen",
         "full",
         "check"
     ];

"""Time one pass of every phase over `src`, on programs nothing else has touched."""
def phase_row(src: str) -> dict {
    staged = JacProgram();
    t0 = time.perf_counter();
    staged.compile(
        file_path=src,
        options=CompileOptions(force_target_program=True, force_codespace='server')
    );
    elapsed = time.perf_counter() - t0;
    phases = dict(staged.analysis.phase_time);
    errors = len(staged.errors_had);
    staged.release_compile_closure();
    checker = JacProgram();
    check_opts = CompileOptions(
        no_cgen=True, native_parity=True, force_target_program=True
    );
    if hasattr(check_opts, "iface_ok") {
        check_opts.iface_ok = True;
    }
    t7 = time.perf_counter();
    checker.compile(file_path=src, options=check_opts);
    t8 = time.perf_counter();
    errors += len(checker.errors_had);
    checker.release_compile_closure();
    return {
        "parse": phases.get(CompilationPhase.PARSE.name, 0.0),
        "ir_gen": phases.get(CompilationPhase.IR.name, 0.0),
        "analysis": phases.get(CompilationPhase.ANALYSIS.name, 0.0),
        "boundary": phases.get(CompilationPhase.BOUNDARIES.name, 0.0),
        "codegen": phases.get(CompilationPhase.CODEGEN.name, 0.0),
        "full": elapsed,
        "check": t8 - t7,
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
