"""Measure enabled native-bridge interopbench cells.

Usage:
  jac run harness/measure.jac [--kernels iop_call,iop_cb,iop_view]
      [--variants <exact-oracle-group>] [--sizes empty|one|small|default]
      [--invocations N] [--out results/bridges_results.json]

Omit --variants to use each selected cell's catalogued oracle group.
"""

import sys;
import from pathlib { Path }
import from common { aggregate_runs, compare_oracle, run_command, write_results, }


glob BENCH = Path(str(__file__)).resolve().parent.parent,
     CATALOG: dict[str, dict] = {
         "iop_call": {
             "scenario": "scalar checksum call churn",
             "source": "kernels/iop_call.jac",
             "variants": ["free", "bridge"],
             "reference": "free",
             "sizes": {"small": ["100", "10"], "default": ["1000", "100"],},
             "metrics": ["per_call_ns"],
             "command_adapter": "mixed_jit_jac_run",
             "timing_source": "kernel_perf_counter_ns",
             "rss_scope": "not_recorded",

         },
         "iop_cb": {
             "scenario": "scalar native-to-server callback churn",
             "source": "kernels/iop_cb.jac",
             "variants": ["free", "bridge"],
             "reference": "free",
             "sizes": {"small": ["100", "10"], "default": ["1000", "100"],},
             "metrics": ["invoke_ns"],
             "command_adapter": "mixed_jit_jac_run",
             "timing_source": "kernel_perf_counter_ns",
             "rss_scope": "not_recorded",

         },
         "iop_view": {
             "scenario": "zero-copy native list and struct view consumption",
             "source": "kernels/iop_view.na.jac",
             "driver": "harness/view_driver.jac",
             "variants": ["materialised", "view"],
             "reference": "materialised",
             "sizes": {
                 "empty": ["0"],
                 "one": ["1"],
                 "small": ["17"],
                 "default": ["1000"],

             },
             "metrics": ["view_ns", "materialise_ns"],
             "command_adapter": "full_native_view_driver",
             "timing_source": "driver_perf_counter_ns",
             "rss_scope": "not_recorded",

         },

     };


"""Parse the benchmark CLI."""
def parse_opts(argv: list[str]) -> dict[str, str | int] {
    opts: dict[str, str | int] = {
        "kernels": "iop_call,iop_cb,iop_view",
        "variants": "",
        "sizes": "default",
        "invocations": 10,
        "out": str(BENCH / "results" / "bridges_results.json"),

    };
    i = 1;
    while i < len(argv) {
        flag = argv[i];
        if flag in ("--kernels", "--variants", "--sizes", "--invocations", "--out", )
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
    return opts;
}


"""Build the exact command for one catalogued adapter."""
def build_command(spec: dict[str, object], variant: str, args: list[str]) -> list[str] {
    adapter = spec["command_adapter"] as str;
    source = spec["source"] as str;
    if adapter == "mixed_jit_jac_run" {
        entry = source;
    } elif adapter == "full_native_view_driver" {
        entry = spec["driver"] as str;
    } else {
        raise ValueError(f"unknown command adapter: {adapter}");
    }
    return [
        sys.executable,
        "-m",
        "jaclang",
        "run",
        str(BENCH / entry),
        variant,

    ] + args;
}


"""Measure one variant and attach adapter metadata."""
def measure_variant(
    spec: dict[str, object], variant: str, args: list[str], count: int
) -> dict[str, object] {
    command = build_command(spec, variant, args);
    runs = [run_command(command, 300) for _ in range(count)];
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
    cell["command"] = command;
    cell["command_adapter"] = spec["command_adapter"] as str;
    cell["timing_source"] = spec["timing_source"] as str;
    cell["rss_scope"] = spec["rss_scope"] as str;
    return cell;
}


"""Run every selected catalog cell and write schema-versioned JSON."""
def main(opts: dict[str, str | int]) {
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
                f"{kernel:12s} {variant:7s} median={cell['median_ns']}ns "
                f"digest={cell['digest']}"
            );
        }
        canonical = compare_oracle(kernel, variants);
        print(f"{kernel:12s} identity: OK ({canonical})");
        cells[kernel] = {
            "scenario": spec["scenario"] as str,
            "source": spec["source"] as str,
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
    write_results(out, "native_bridges", cells);
    print(f"wrote {out}");
}


with entry {
    main(parse_opts(sys.argv));
}
