"""Compare serial, optimistic and dependency-scheduled fixed-topology walkers.

    jac run scripts/walker_dependency_bench.jac --rounds 3 --output /tmp/dependencies.json

Three binaries cover the same matrix of sharing, query sizes and body costs.
Build time is excluded; every measured run verifies the output checksum.
"""

import argparse;
import copy;
import hashlib;
import json;
import os;
import platform;
import statistics;
import subprocess;
import time;
import tempfile;
import from pathlib { Path }
import from jaclang.cli.commands.native_build { native_build }
import from jaclang.project.config { get_config, set_config }

glob COUNTERS: list[str] = [
         "attempts",
         "commits",
         "fallbacks",
         "validation_failures",
         "inspections",
         "unknown",
         "deferrals",
         "inspection_steps",
         "inspection_ns",
         "peak"
     ];

def main {
    parser = argparse.ArgumentParser(description=__doc__);
    parser.add_argument("--rounds", type=int, `default=3);
    parser.add_argument("--output", type=Path);
    parser.add_argument("--quick", action="store_true");
    args = parser.parse_args();
    if args.rounds < 1 {
        parser.error("rounds must be positive");
    }
    repo = Path(__file__).resolve().parent.parent;
    source = (
        repo
        / "jac/tests/compiler/backends/native/fixtures/perf_walker_dependencies.jac"
    ).read_text();
    stats = "\nimport from c {\n"
        + "\n".join("def __jac_spec_get_" + name + " -> int;" for name in COUNTERS)
        + "\n}\nwith entry { print(\"stats\", "
        + ", ".join("__jac_spec_get_" + name + "()" for name in COUNTERS)
        + "); }\n";
    libc = "\nimport from c { def getpid -> int; }\nwith entry { assert getpid() > 0; }\n";
    previous = get_config();
    assert previous is not None;
    cfg = copy.deepcopy(previous);
    cfg.native.debug = False;
    cfg.native.opt = 2;
    cfg.native.threads = 4;
    modes = [
        ("serial", "off", False),
        ("optimistic", "auto", False),
        ("dependencies", "auto", True)
    ];
    records: list[any] = [];
    try {
        set_config(cfg);
        with tempfile.TemporaryDirectory(prefix="jac-dependency-bench-") as tmp {
            binaries: dict[str, str] = {};
            for (name, mode, inspect) in modes {
                cfg.native.walker_speculation = mode;
                cfg.native.walker_dependency_inspection = inspect;
                path = Path(tmp) / (name + ".jac");
                path.write_text(source + libc + (stats if mode == "auto" else ""));
                binary = str(Path(tmp) / name);
                assert native_build(str(path), output=binary, memory="rc") == 0;
                binaries[name] = binary;
            }
            sizes = [1] if args.quick else [1, 4];
            costs = [20000] if args.quick else [20000, 200000];
            for groups in [16, 4, 1] {
                for size in sizes {
                    for cost in costs {
                        samples: dict[str, list[float]] = {
                            name: [] for (name, mode, inspect) in modes
                        };
                        counters: dict[str, any] = {};
                        inspection_samples: list[int] = [];
                        expected = "";
                        for iteration in range(-1, args.rounds) {
                            order = modes
                                if iteration % 2 == 0
                                else list(reversed(modes));
                            for (name, mode, inspect) in order {
                                start = time.perf_counter();
                                ran = subprocess.run(
                                    [binaries[name], str(groups), str(size), str(cost)],
                                    capture_output=True,
                                    text=True,
                                    timeout=120
                                );
                                elapsed = time.perf_counter() - start;
                                assert ran.returncode == 0 , ran.stderr;
                                lines = ran.stdout.splitlines();
                                if mode == "auto" {
                                    row = lines.pop().split();
                                    assert row[0] == "stats";
                                    counters[name] = dict(
                                        zip(COUNTERS, [int(v) for v in row[1:]])
                                    );
                                }
                                output = "\n".join(lines);
                                if not expected {
                                    expected = output;
                                }
                                assert output == expected , f"output mismatch: {name}";
                                if iteration >= 0 {
                                    samples[name].append(elapsed);
                                    if inspect {
                                        inspection_samples.append(
                                            counters[name]["inspection_ns"]
                                        );
                                    }
                                }
                            }
                        }
                        records.append(
                            {
                                "groups": groups,
                                "query_size": size,
                                "body_steps": cost,
                                "samples_seconds": samples,
                                "median_seconds": {
                                    name: statistics.median(values)
                                    for (name, values) in samples.items()
                                },
                                "counters": counters,
                                "inspection_samples_ns": inspection_samples,
                                "median_inspection_ns": statistics.median(
                                    inspection_samples
                                ),
                                "checksum": expected
                            }
                        );
                        print(
                            f"Measured groups={groups}, query={size}, steps={cost}",
                            flush=True
                        );
                    }
                }
            }
        }
    } finally {
        set_config(previous);
    }
    result = {
        "platform": platform.platform(),
        "logical_cpus": os.cpu_count(),
        "workers": 4,
        "jobs": 16,
        "rounds": args.rounds,
        "warmups": 1,
        "source_sha256": hashlib.sha256(source.encode()).hexdigest(),
        "build": {"backend": "native-aot", "memory": "rc", "opt": 2, "libc": "host"},
        "cases": records
    };
    encoded = json.dumps(result, indent=2);
    if args.output {
        args.output.write_text(encoded + "\n");
    }
    print(encoded);
}

with entry:__main__ {
    main();
}
