"""Measure enabled cross-runtime interopbench cells.

Usage:
  jac run harness/xbench.jac [--kernels xop_svc_split,xop_feed,xop_wasm_call]
      [--variants <exact-oracle-group>] [--sizes empty|one|small|default]
      [--invocations N] [--out results/xruntime_results.json] [--quick]

Omit --variants to use each selected cell's catalogued oracle group.
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
     CATALOG: dict[str, dict] = {
         "xop_svc_split": {
             "scenario": "sv-to-sv microservice RPC vs in-process dispatch",
             "kernel_dir": "kernels/xop_svc_split",
             "provider": "billing.jac",
             "provider_module": "billing",
             "variants": ["direct", "rpc"],
             "reference": "direct",
             "sizes": {"small": SIZE_SMALL_CHURN, "default": SIZE_DEFAULT_CHURN,},
             "metrics": ["per_call_ns"],
             "command_adapter": "sv_microservice_driver",
             "timing_source": "kernel_perf_counter_ns",
             "rss_scope": "not_recorded",

         },
         "xop_feed": {
             "scenario": "generated cl client feed checksum vs direct provider dispatch",
             "kernel_dir": "kernels/xop_feed",
             "provider": "feed_provider.jac",
             "provider_module": "feed_provider",
             "variants": ["direct", "client"],
             "reference": "direct",
             "sizes": {"small": SIZE_SMALL_CHURN, "default": SIZE_DEFAULT_CHURN,},
             "metrics": ["per_call_ns"],
             "command_adapter": "cl_sv_node_driver",
             "timing_source": "driver_perf_counter_ns",
             "rss_scope": "not_recorded",

         },
         "xop_wasm_call": {
             "scenario": "native vs wasm32 export for the same deterministic kernel",
             "kernel_dir": "kernels/xop_wasm_call",
             "source": "kernels/xop_wasm_call/bench_compute.na.jac",
             "variants": ["native", "wasm"],
             "reference": "native",
             "sizes": {"small": SIZE_SMALL_CHURN, "default": SIZE_DEFAULT_CHURN,},
             "metrics": ["per_call_ns"],
             "command_adapter": "wasm_node_driver",
             "timing_source": "kernel_perf_counter_ns",
             "rss_scope": "not_recorded",

         },

     };


"""Parse the cross-runtime benchmark CLI."""
def parse_opts(argv: list[str]) -> dict[str, str | int | bool] {
    opts: dict[str, str | int | bool] = {
        "kernels": "xop_svc_split,xop_feed,xop_wasm_call",
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
) -> subprocess.Popen {
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
def stop_provider(proc: subprocess.Popen | None) -> None {
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


"""Measure one catalogued variant."""
def measure_variant(
    spec: dict[str, object], variant: str, args: list[str], count: int
) -> dict[str, object] {
    timeout_s = 300;
    runs: list[dict] = [];
    adapter = spec["command_adapter"] as str;
    for _ in range(count) {
        if adapter in ("sv_microservice_driver", "cl_sv_node_driver") {
            runs.append(run_hosted_variant(spec, variant, args, timeout_s));
        } elif adapter == "wasm_node_driver" {
            runs.append(run_wasm_variant(spec, variant, args, timeout_s));
        } else {
            raise ValueError(f"unknown command adapter: {adapter}");
        }
    }
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
    cell["invocations"] = count;
    cell["command_adapter"] = adapter;
    cell["timing_source"] = spec["timing_source"] as str;
    cell["rss_scope"] = spec["rss_scope"] as str;
    return cell;
}


"""Run every selected cross-runtime cell and write schema-versioned JSON."""
def main(opts: dict[str, str | int | bool]) {
    kernels_csv = opts["kernels"] as str;
    variants_csv = opts["variants"] as str;
    kernels = [
        name
        for name in kernels_csv.split(",")
        if name
    ];
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
    cells: dict[str, dict] = {};
    for kernel in kernels {
        if kernel not in CATALOG {
            raise ValueError(f"unknown kernel: {kernel}");
        }
        spec = CATALOG[kernel] as dict[str, object];
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
        variants: dict[str, dict] = {};
        for variant in selected_variants {
            variants[variant] = measure_variant(spec, variant, args, invocations);
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
