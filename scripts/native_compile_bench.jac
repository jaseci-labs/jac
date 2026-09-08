"""Measure uncached AOT builds with a warm compiler.

    JAC_COMPILER_LIB=/path/to/kernel.so jac run scripts/native_compile_bench.jac \
        jac/examples/chess/chess.jac --rounds 5

Run each kernel in a fresh process. Compiler startup and warmup are excluded;
each measured build reparses the application and emits and links an executable.
Runtime-unit IR is rebuilt as part of each measured build.
"""

import argparse;
import gc;
import json;
import os;
import statistics;
import tempfile;
import time;
import from pathlib { Path }

def main -> None {
    parser = argparse.ArgumentParser(
        description="Measure uncached AOT builds with a warm compiler."
    );
    parser.add_argument("source", type=Path);
    parser.add_argument("--rounds", type=int, `default=5);
    parser.add_argument("--warmups", type=int, `default=2);
    parser.add_argument("--output", type=Path);
    args = parser.parse_args();
    if args.rounds < 1 or args.warmups < 1 {
        parser.error("rounds and warmups must be positive");
    }

    import from jaclang.cli.commands.native_build { native_build }
    import from jaclang.compiler.native_compiler { ensure_loaded }

    kernel = ensure_loaded();
    if kernel is None {
        parser.error("set JAC_COMPILER_LIB to a built compiler kernel");
        return;
    }
    times: list[float] = [];
    with tempfile.TemporaryDirectory(prefix="jac-compile-bench-") as directory {
        output = args.output or Path(directory) / "program";
        for round_number in range(-args.warmups, args.rounds) {
            gc.collect();
            start = time.perf_counter();
            result = native_build(
                str(args.source.resolve()), output=str(output), no_ir_cache=True
            );
            elapsed = time.perf_counter() - start;
            if result {
                raise RuntimeError(f"compile failed in round {round_number}");
            }
            print(json.dumps({"round": round_number, "seconds": elapsed}), flush=True);
            if round_number >= 0 {
                times.append(elapsed);
            }
        }
    }
    print(
        json.dumps(
            {
                "source": str(args.source),
                "kernel": os.environ.get("JAC_COMPILER_LIB", "auto"),
                "early_passes": kernel.supports_early,
                "seconds": times,
                "median_seconds": statistics.median(times),
                "min_seconds": min(times),
                "max_seconds": max(times)
            }
        ),
        flush=True
    );
}

with entry:__main__ {
    main();
}
