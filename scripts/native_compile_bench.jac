"""Measure uncached AOT builds with a warm compiler.

    jac native build kernel
    jac run scripts/native_compile_bench.jac jac/examples/chess/chess.jac --rounds 5

Compiler startup and warmup are excluded;
each measured build reparses the application and emits and links an executable.
Runtime-unit IR is rebuilt as part of each measured build.
"""

import argparse;
import gc;
import json;
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
    import from jaclang.compiler.driver.jir { scrub_cache_dirs }
    import from jaclang.compiler.native_compiler { ensure_loaded }

    kernel = ensure_loaded();
    if kernel is None {
        parser.error(
            "no compiler kernel is loaded; run `jac native build kernel` first"
        );
        return;
    }
    times: list[float] = [];
    with tempfile.TemporaryDirectory(prefix="jac-compile-bench-") as directory {
        output = args.output or Path(directory) / "program";
        for round_number in range(-args.warmups, args.rounds) {
            gc.collect();
            scrub_cache_dirs(str(args.source.resolve().parent));
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
                "kernel": kernel.lib_path,
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
