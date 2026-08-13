"""Measure enabled cross-runtime interopbench cells.

Usage:
  jac run harness/xbench.jac [--kernels xop_svc_split,xop_feed,xop_wasm_call]
      [--variants <exact-oracle-group>] [--sizes empty|one|small|default]
      [--invocations N] [--out results/xruntime_results.json] [--quick]

Omit --variants to use each selected cell's catalogued oracle group.
All cross-runtime cells require the explicit --experimental flag.
"""

import os;
import shutil;
import socket;
import subprocess;
import sys;
import time;
import from pathlib { Path }
import from urllib.error { URLError }
import from urllib.request { urlopen }
import from common {
    aggregate_runs,
    compare_oracle,
    DEFAULT_INVOCATIONS,
    run_command,
    SIZE_DEFAULT_CHURN,
    SIZE_SMALL_CHURN,
    write_results,
}


glob BENCH = Path(str(__file__)).resolve().parent.parent,
     HARNESS = BENCH / "harness",
     EXPERIMENTAL_KERNELS: set[str] = {
         "xop_svc_split",
         "xop_feed",
         "xop_feed_payload",
         "xop_wasm_call",

     },
     CATALOG: dict[str, dict[str, object]] = {
         "xop_feed_payload": {
             "scenario": "payload-cardinality sweep: loopback sv-to-sv RPC returning list[N] ints vs in-process, fit t(N)=t0+b*N",
             "kernel_dir": "kernels/xop_feed_payload",
             "provider": "feedbatch.jac",
             "provider_module": "feedbatch",
             "variants": ["direct", "rpc"],
             "reference": "direct",
             "sizes": {
                 "p1": ["1", "20"],
                 "p10": ["10", "20"],
                 "p50": ["50", "20"],
                 "p100": ["100", "20"],
                 "p250": ["250", "20"],
                 "p500": ["500", "20"],
                 "p1000": ["1000", "20"],
                 "p2000": ["2000", "20"],
                 "p5000": ["5000", "20"],
                 "p10000": ["10000", "20"],
                 "p20000": ["20000", "20"],
                 "p30000": ["30000", "20"],
                 "p40000": ["40000", "20"],
                 "p50000": ["50000", "20"],
                 "p75000": ["75000", "20"],
                 "p100000": ["100000", "20"],

             },
             "metrics": ["per_call_ns"],
             "command_adapter": "sv_microservice_driver",
             "timing_source": "kernel_perf_counter_ns",
             "variant_timing_source": {
                 "direct": "kernel_perf_counter_ns",
                 "rpc": "kernel_perf_counter_ns",

             },
             "rss_scope": "not_recorded",

         },
         "xop_svc_split": {
             "scenario": "serial loopback sv-to-sv RPC floor vs in-process dispatch",
             "kernel_dir": "kernels/xop_svc_split",
             "provider": "billing.jac",
             "provider_module": "billing",
             "variants": ["direct", "rpc"],
             "reference": "direct",
             "sizes": {"small": SIZE_SMALL_CHURN, "default": SIZE_DEFAULT_CHURN,},
             "metrics": ["per_call_ns"],
             "command_adapter": "sv_microservice_driver",
             "timing_source": "kernel_perf_counter_ns",
             "variant_timing_source": {
                 "direct": "kernel_perf_counter_ns",
                 "rpc": "kernel_perf_counter_ns",

             },
             "rss_scope": "not_recorded",

         },
         "xop_feed": {
             "scenario": "serial scalar generated-client RPC floor vs direct provider dispatch (not a typed-feed or serialisation-scaling workload)",
             "kernel_dir": "kernels/xop_feed",
             "provider": "feed_provider.jac",
             "provider_module": "feed_provider",
             "variants": ["direct", "client"],
             "reference": "direct",
             "sizes": {"small": SIZE_SMALL_CHURN, "default": SIZE_DEFAULT_CHURN,},
             "metrics": ["per_call_ns"],
             "command_adapter": "cl_sv_node_driver",
             "timing_source": "mixed_per_variant",
             "variant_timing_source": {
                 "direct": "kernel_perf_counter_ns",
                 "client": "host_node_performance_now",

             },
             "rss_scope": "not_recorded",

         },
         "xop_wasm_call": {
             "scenario": "wasm32 export under a JS host loop vs native sv→na bridge under a Python host loop (asymmetric host loops, not same-source native-vs-wasm)",
             "kernel_dir": "kernels/xop_wasm_call",
             "source": "kernels/xop_wasm_call/bench_compute.na.jac",
             "variants": ["native", "wasm"],
             "reference": "native",
             "sizes": {"small": SIZE_SMALL_CHURN, "default": SIZE_DEFAULT_CHURN,},
             "metrics": ["per_call_ns"],
             "command_adapter": "wasm_node_driver",
             "timing_source": "mixed_per_variant",
             "variant_timing_source": {
                 "native": "kernel_perf_counter_ns",
                 "wasm": "host_node_performance_now",

             },
             "rss_scope": "not_recorded",

         },

     };


"""Parse the cross-runtime benchmark CLI."""
def parse_opts(argv: list[str]) -> dict[str, str | int | bool] {
    opts: dict[str, str | int | bool] = {
        "kernels": "",
        "experimental": False,
        "variants": "",
        "sizes": "default",
        "invocations": DEFAULT_INVOCATIONS,
        "out": str(BENCH / "results" / "xruntime_results.json"),
        "quick": False,

    };
    i = 1;
    while i < len(argv) {
        flag = argv[i];
        if flag == "--quick" {
            opts["quick"] = True;
            i += 1;
        } elif flag == "--experimental" {
            opts["experimental"] = True;
            i += 1;
        } elif flag in (
            "--kernels",
            "--variants",
            "--sizes",
            "--invocations",
            "--out",

        )
        and i + 1 < len(argv) {
            key = flag[2:];
            opts[key] = int(argv[i + 1]) if flag == "--invocations" else argv[i + 1];
            i += 2;
        } else {
            raise ValueError(f"unknown or incomplete option: {flag}\n{__doc__}");
        }
    }
    if opts["invocations"] < 1 {
        raise ValueError("--invocations must be positive");
    }
    if opts["quick"] {
        opts["sizes"] = "small";
        opts["invocations"] = 1;
    }
    return opts;
}


"""Allocate a free TCP port."""
def free_port -> int {
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM);
    sock.bind(("", 0));
    port = sock.getsockname()[1] as int;
    sock.close();
    return port;
}


"""Poll /healthz until the provider is ready or raise with log tail."""
def wait_healthz(base_url: str, timeout_s: int, log_path: Path | None = None) -> None {
    deadline = time.time() + timeout_s;
    last_err = "";
    while time.time() < deadline {
        try {
            resp = urlopen(f"{base_url}/healthz", timeout=1);
            try {
                if resp.status == 200 {
                    return;
                }
            } finally {
                resp.close();
            }
        } except (URLError, TimeoutError, OSError) as exc {
            last_err = str(exc);
            time.sleep(0.5);
        }
    }
    tail = "";
    if log_path is not None and log_path.exists() {
        tail = log_path.read_text()[-4000:];
    }
    raise RuntimeError(
        f"provider not healthy at {base_url}/healthz after {timeout_s}s: {last_err}\n{tail}"
    );
}


"""Start jac start for a kernel-local provider module."""
def start_provider(
    kernel_dir: Path, provider: str, port: int, log_path: Path
) -> subprocess.Popen[str] {
    log_fh = log_path.open("w", encoding="utf-8");
    proc = subprocess.Popen(
        [sys.executable, "-m", "jaclang", "start", provider, "--port", str(port)],
        cwd=str(kernel_dir),
        stdout=log_fh,
        stderr=subprocess.STDOUT,
        text=True,
        start_new_session=True,
    );
    return proc;
}


"""Terminate a provider process, escalating to kill when needed."""
def stop_provider(proc: subprocess.Popen[str] | None) -> None {
    if proc is None {
        return;
    }
    try {
        os.killpg(proc.pid, 15);
    } except ProcessLookupError {
        return;
    }
    try {
        proc.wait(timeout=15);
    } except subprocess.TimeoutExpired {
        try {
            os.killpg(proc.pid, 9);
        } except ProcessLookupError {
            return;
        }
        proc.wait(timeout=5);
    }
}


"""Run one sv-microservice or cl->sv invocation."""
def run_hosted_variant(
    spec: dict[str, object], variant: str, args: list[str], timeout_s: int
) -> dict[str, object] {
    kernel_dir = BENCH / (spec["kernel_dir"] as str);
    adapter = spec["command_adapter"] as str;
    if not (kernel_dir / "jac.toml").exists() {
        raise RuntimeError(f"missing project jac.toml in {kernel_dir}");
    }
    port = free_port();
    provider = spec["provider"] as str;
    log_path = kernel_dir / ".provider.log";
    proc = start_provider(kernel_dir, provider, port, log_path);
    base_url = f"http://127.0.0.1:{port}";
    try {
        wait_healthz(base_url, timeout_s // 2, log_path);
        if adapter == "sv_microservice_driver" {
            if variant == "direct" {
                command = [
                    sys.executable,
                    "-m",
                    "jaclang",
                    "run",
                    "direct_runner.jac",

                ] + args;
                return run_command(command, timeout_s, cwd=str(kernel_dir));
            }
            if variant == "rpc" {
                module = spec["provider_module"] as str;
                env = {f"JAC_SV_{module.upper()}_URL": base_url,};
                command = [
                    sys.executable,
                    "-m",
                    "jaclang",
                    "run",
                    "rpc_runner.jac",

                ] + args;
                return run_command(command, timeout_s, cwd=str(kernel_dir), env=env);
            }
            raise ValueError(f"unknown sv variant: {variant}");
        }
        if adapter == "cl_sv_node_driver" {
            if variant == "direct" {
                command = [
                    sys.executable,
                    "-m",
                    "jaclang",
                    "run",
                    "direct_driver.jac",

                ] + args;
                return run_command(command, timeout_s, cwd=str(kernel_dir));
            }
            if variant == "client" {
                node_bin = shutil.which("node");
                if not node_bin {
                    raise RuntimeError(
                        "node not found on PATH; required for xop_feed client"
                    );
                }
                command = [
                    node_bin,
                    str(HARNESS / "cl_host.mjs"),
                    str(kernel_dir),

                ] + args;
                env = {"JAC_API_BASE_URL": base_url};
                return run_command(command, timeout_s, cwd=str(BENCH), env=env);
            }
            raise ValueError(f"unknown cl variant: {variant}");
        }
        raise ValueError(f"unsupported hosted adapter: {adapter}");
    } finally {
        stop_provider(proc);
        if log_path.exists() {
            log_path.unlink();
        }
    }
}


"""Compile wasm once and reuse the artifact path."""
def ensure_wasm(kernel_dir: Path, source_name: str = "bench_compute.na.jac") -> Path {
    src = kernel_dir / source_name;
    out = kernel_dir / "bench_compute.wasm";
    if not src.exists() {
        raise RuntimeError(f"missing wasm source: {src}");
    }
    build = subprocess.run(
        [
            sys.executable,
            "-m",
            "jaclang",
            "nacompile",
            str(src),
            "--target",
            "wasm32",
            "-o",
            str(out),

        ],
        capture_output=True,
        text=True,
        timeout=300,
        cwd=str(kernel_dir),
    );
    if build.returncode != 0 {
        raise RuntimeError(
            f"nacompile wasm32 failed for {src}\nstdout:\n{build.stdout}\nstderr:\n{build.stderr}"
        );
    }
    if "vendored wasm libc not found" in build.stdout {
        raise RuntimeError(
            "vendored wasm libc not found; run `zig build vendor-wasm-libc` "
            "from the jac/ tree before measuring xop_wasm_call"
        );
    }
    if not out.exists() {
        raise RuntimeError(f"nacompile did not write {out}");
    }
    return out;
}


"""Run one wasm/native cross-runtime invocation."""
def run_wasm_variant(
    spec: dict[str, object], variant: str, args: list[str], timeout_s: int
) -> dict[str, object] {
    kernel_dir = BENCH / (spec["kernel_dir"] as str);
    if variant == "native" {
        command = [
            sys.executable,
            "-m",
            "jaclang",
            "run",
            "native_driver.jac",

        ] + args;
        return run_command(command, timeout_s, cwd=str(kernel_dir));
    }
    if variant == "wasm" {
        node_bin = shutil.which("node");
        if not node_bin {
            raise RuntimeError(
                "node not found on PATH; required for xop_wasm_call wasm"
            );
        }
        wasm_path = ensure_wasm(kernel_dir);
        command = [node_bin, str(HARNESS / "wasm_host.mjs"), str(wasm_path)] + args;
        return run_command(command, timeout_s, cwd=str(BENCH));
    }
    raise ValueError(f"unknown wasm variant: {variant}");
}


"""Run one invocation of a catalogued variant through its host adapter."""
def run_once(
    spec: dict[str, object], variant: str, args: list[str], timeout_s: int
) -> dict[str, object] {
    adapter = spec["command_adapter"] as str;
    if adapter in ("sv_microservice_driver", "cl_sv_node_driver") {
        return run_hosted_variant(spec, variant, args, timeout_s);
    }
    if adapter == "wasm_node_driver" {
        return run_wasm_variant(spec, variant, args, timeout_s);
    }
    raise ValueError(f"unknown command adapter: {adapter}");
}


"""Resolve the timing source for one variant, honouring per-variant labels.

Cross-runtime cells do not share a clock: a Python-side driver stamps
perf_counter_ns while a Node host stamps performance.now(). The catalog
records the true owner per variant so a wasm/client wall time is never
mislabelled as a kernel perf_counter reading."""
def variant_timing_source(spec: dict[str, object], variant: str) -> str {
    per_variant = spec.get("variant_timing_source") as dict[str, str] | None;
    if per_variant is not None and variant in per_variant {
        return per_variant[variant];
    }
    return spec["timing_source"] as str;
}


"""Aggregate one variant's collected runs and attach adapter metadata."""
def finalize_variant(
    spec: dict[str, object],
    variant: str,
    args: list[str],
    runs: list[dict[str, object]],
) -> dict[str, object] {
    cell = aggregate_runs(runs) as dict[str, object];
    actual_metrics = set((cell["metrics"] as dict[str, int]).keys());
    expected_metrics = set(spec["metrics"] as list[str]);
    if actual_metrics != expected_metrics {
        raise ValueError(
            f"metric keys {sorted(actual_metrics)} do not match catalog "
            f"{sorted(expected_metrics)}"
        );
    }
    cell["args"] = args;
    cell["invocations"] = len(runs);
    cell["command_adapter"] = spec["command_adapter"] as str;
    cell["timing_source"] = variant_timing_source(spec, variant);
    cell["rss_scope"] = spec["rss_scope"] as str;
    return cell;
}


"""Measure an oracle group with paired, interleaved invocation ordering."""
def measure_variants(
    spec: dict[str, object], selected_variants: list[str], args: list[str], count: int,
) -> dict[str, dict[str, object]] {
    timeout_s = 300;
    runs: dict[str, list[dict[str, object]]] = {
        variant: [] for variant in selected_variants
    };
    for _round in range(count) {
        for variant in selected_variants {
            runs[variant].append(run_once(spec, variant, args, timeout_s));
        }
    }
    return {
        variant: finalize_variant(spec, variant, args, runs[variant])
        for variant in selected_variants
    };
}


"""Run every selected cross-runtime cell and write schema-versioned JSON."""
def main(opts: dict[str, str | int | bool]) {
    kernels_csv = opts["kernels"] as str;
    variants_csv = opts["variants"] as str;
    kernels: list[str] = [
        name
        for name in kernels_csv.split(",")
        if name
    ];
    if not kernels and (opts["experimental"] as bool) {
        kernels = sorted(EXPERIMENTAL_KERNELS) as list[str];
    }
    if not kernels {
        raise ValueError(
            "no kernels selected; pass --experimental to enable cross-runtime cells"
        );
    }
    if not (opts["experimental"] as bool) {
        raise ValueError(
            "cross-runtime cells are experimental; rerun with --experimental"
        );
    }
    explicit_variants = [
        name
        for name in variants_csv.split(",")
        if name
    ];
    if len(explicit_variants) != len(set(explicit_variants)) {
        raise ValueError("--variants contains duplicate names");
    }
    if not kernels {
        raise ValueError("--kernels must select at least one kernel");
    }
    invocations = opts["invocations"] as int;
    cells: dict[str, dict[str, object]] = {};
    for kernel in kernels {
        if kernel not in CATALOG {
            raise ValueError(f"unknown kernel: {kernel}");
        }
        spec = CATALOG[kernel];
        size_name = opts["sizes"] as str;
        sizes = spec["sizes"] as dict[str, list[str]];
        if size_name not in sizes {
            raise ValueError(f"{kernel}: unknown size set: {size_name}");
        }
        args = sizes[size_name];
        enabled_variants = spec["variants"] as list[str];
        selected_variants = explicit_variants or enabled_variants;
        if set(selected_variants) != set(enabled_variants) {
            raise ValueError(
                f"{kernel}: --variants must select oracle group "
                f"{','.join(enabled_variants)}"
            );
        }
        variants = measure_variants(spec, selected_variants, args, invocations);
        for variant in selected_variants {
            cell = variants[variant];
            print(
                f"{kernel:16s} {variant:7s} median={cell['median_ns']}ns "
                f"digest={cell['digest']}"
            );
        }
        canonical = compare_oracle(kernel, variants);
        print(f"{kernel:16s} identity: OK ({canonical})");
        source = spec.get("source", spec.get("kernel_dir", "")) as str;
        cells[kernel] = {
            "scenario": spec["scenario"] as str,
            "source": source,
            "reference": spec["reference"] as str,
            "size_set": size_name,
            "oracle": {
                "variants": selected_variants,
                "canonical_digest": canonical,
                "identical": True,

            },
            "variants": variants,

        };
    }
    out = Path(opts["out"] as str);
    write_results(out, "cross_runtime", cells);
    print(f"wrote {out}");
}


with entry {
    main(parse_opts(sys.argv));
}
