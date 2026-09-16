"""Compare serial and speculative Native AOT walkers with RC and opt=2.

    jac run scripts/walker_speculation_bench.jac --rounds 7 --output /tmp/walker-speedup.json

Build time is excluded. Each binary gets two warmups, then measured executions
in alternating order. Process startup, traversal, commit and output are included.
Every run checks node fields and report order; stdout must match across modes.
This is a synthetic, conflict-free CPU workload, not a general speedup estimate.
"""

import argparse;
import copy;
import hashlib;
import json;
import os;
import platform;
import statistics;
import subprocess;
import tempfile;
import time;
import from pathlib { Path }
import from jaclang.cli.commands.native_build { native_build }
import from jaclang.project.config { get_config, set_config }

# Use the host libc in every case, including the serial binary. Otherwise the
# C imports for the speculation counters would switch only auto builds to it.
glob LIBC_PROBE = """
import from c { def getpid -> int; }
with entry {
    process_id: int = getpid();
    assert process_id > 0;
}
""";

glob STATS = """
import from c {
    def __jac_spec_get_peak -> int;
    def __jac_spec_get_commits -> int;
    def __jac_spec_get_fallbacks -> int;
}
with entry {
    print("speculation", __jac_spec_get_peak(), __jac_spec_get_commits(),
        __jac_spec_get_fallbacks());
}
""";

def main -> None {
    parser = argparse.ArgumentParser(description=__doc__);
    parser.add_argument("--rounds", type=int, `default=7);
    parser.add_argument("--output", type=Path);
    args = parser.parse_args();
    if args.rounds < 1 {
        parser.error("rounds must be positive");
    }
    repo = Path(__file__).resolve().parent.parent;
    fixture = repo
        / "jac/tests/compiler/backends/native/fixtures/perf_walker_speculation.jac";
    code = fixture.read_text();
    previous = get_config();
    assert previous is not None;
    cfg = copy.deepcopy(previous);
    cfg.native.debug = False;
    cfg.native.opt = 2;
    cases = [("off", "off", 4), ("auto2", "auto", 2), ("auto4", "auto", 4)];
    samples: dict[str, list[float]] = {name: [] for (name, mode, width) in cases};
    counters: dict[str, dict[str, int]] = {};
    expected = "";
    try {
        set_config(cfg);
        with tempfile.TemporaryDirectory(prefix="jac-walker-bench-") as directory {
            binaries: dict[str, str] = {};
            for (name, mode, width) in cases {
                cfg.native.walker_speculation = mode;
                cfg.native.threads = width;
                source = Path(directory) / (name + ".jac");
                source.write_text(
                    code + LIBC_PROBE + (STATS if mode == "auto" else "")
                );
                binary = Path(directory) / name;
                assert native_build(str(source), output=str(binary), memory="rc") == 0;
                binaries[name] = str(binary);
            }
            for round_number in range(-2, args.rounds) {
                order = cases if round_number % 2 == 0 else list(reversed(cases));
                for (name, mode, width) in order {
                    start = time.perf_counter();
                    ran = subprocess.run(
                        [binaries[name]], capture_output=True, text=True, timeout=60
                    );
                    elapsed = time.perf_counter() - start;
                    assert ran.returncode == 0 , ran.stderr;
                    lines = ran.stdout.splitlines(keepends=True);
                    if mode == "auto" {
                        stats = lines.pop().split();
                        assert stats[0] == "speculation" , ran.stdout;
                        (peak, commits, fallbacks) = [
                            int(value) for value in stats[1:]
                        ];
                        assert 2 <= peak <= width;
                        assert commits == 16 and fallbacks == 0 , stats;
                        counters[name] = {
                            "peak": peak,
                            "commits": commits,
                            "fallbacks": fallbacks
                        };
                    }
                    output = "".join(lines);
                    if not expected {
                        expected = output;
                    }
                    assert output == expected , f"output differs for {name}";
                    if round_number >= 0 {
                        samples[name].append(elapsed);
                    }
                }
                if round_number >= 0 {
                    print(
                        f"Measured round {round_number + 1}/{args.rounds}", flush=True
                    );
                }
            }
        }
    } finally {
        set_config(previous);
    }
    medians = {name: statistics.median(values) for (name, values) in samples.items()};
    result = {
        "platform": platform.platform(),
        "logical_cpus": os.cpu_count(),
        "build": {"backend": "native-aot", "memory": "rc", "opt": 2, "libc": "host"},
        "jobs": 16,
        "steps_per_job": 6400000,
        "warmups": 2,
        "rounds": args.rounds,
        "source_sha256": hashlib.sha256(code.encode()).hexdigest(),
        "samples_seconds": samples,
        "median_seconds": medians,
        "speedup": {
            name: medians["off"] / elapsed for (name, elapsed) in medians.items()
        },
        "counters": counters,
        "output": expected
    };
    result_json = json.dumps(result, indent=2);
    if args.output {
        args.output.write_text(result_json + "\n");
    }
    print(result_json);
}

with entry:__main__ {
    main();
}
