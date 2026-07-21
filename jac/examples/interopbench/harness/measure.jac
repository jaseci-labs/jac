"""Measure enabled native-bridge interopbench cells.

Usage:
  jac run harness/measure.jac [--kernels iop_call,iop_cb,iop_symmetric,iop_view]
      [--variants <exact-oracle-group>] [--sizes empty|one|small|default]
      [--invocations N] [--out results/bridges_results.json]

Omit --variants to use each selected cell's catalogued oracle group.
Phase 4 cells require the explicit --experimental flag.
"""

import shutil;
import subprocess;
import sys;
import from pathlib { Path }
import from common {
    aggregate_runs,
    compare_oracle,
    DEFAULT_INVOCATIONS,
    run_command,
    SIZE_DEFAULT_CHURN,
    SIZE_SMALL_CHURN,
    SIZE_VIEW_DEFAULT,
    write_results,
}


glob BENCH = Path(str(__file__)).resolve().parent.parent,
     CLIB_SOURCE = BENCH / "kernels" / "support" / "interopbench.c",
     CLIB_BINARY = BENCH / "bin" / "libinteropbench.so",
     CLIB_EXPORTED_SYMBOLS = [
         "ib_vec4_make",
         "ib_vec4_sum",
         "ib_vec12_make",
         "ib_vec12_sum",
         "ib_vec16_make",
         "ib_vec16_sum",
         "ib_vec24_make",
         "ib_vec24_sum",
         "ib_vec44_make",
         "ib_vec44_sum",
         "ib_invoke_event",

     ],
     EXPERIMENTAL_KERNELS: set[str] = {
         "iop_ffi_scalar",
         "iop_ffi_struct",
         "iop_ffi_vtable",

     },
     CATALOG: dict[str, dict[str, object]] = {
         "iop_call": {
             "scenario": "scalar checksum call churn",
             "source": "kernels/iop_call.jac",
             "variants": ["free", "bridge"],
             "reference": "free",
             "sizes": {"small": SIZE_SMALL_CHURN, "default": SIZE_DEFAULT_CHURN,},
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
             "sizes": {"small": SIZE_SMALL_CHURN, "default": SIZE_DEFAULT_CHURN,},
             "metrics": ["invoke_ns"],
             "command_adapter": "mixed_jit_jac_run",
             "timing_source": "kernel_perf_counter_ns",
             "rss_scope": "not_recorded",

         },
         "iop_symmetric": {
             "scenario": "symmetric sv↔na scalar calls with callee-side LCG work",
             "source": "kernels/iop_symmetric.jac",
             "variants": ["sv_local", "sv_to_na", "na_local", "na_to_sv"],
             "reference": "sv_local",
             "sizes": {"small": SIZE_SMALL_CHURN, "default": SIZE_DEFAULT_CHURN,},
             "metrics": ["per_call_ns"],
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
                 "default": SIZE_VIEW_DEFAULT,

             },
             "metrics": ["view_ns", "materialise_ns"],
             "command_adapter": "full_native_view_driver",
             "timing_source": "driver_perf_counter_ns",
             "rss_scope": "not_recorded",

         },
         "iop_ffi_scalar": {
             "scenario": "libm sqrt extern call churn over perfect-square inputs",
             "source": "kernels/iop_ffi_scalar.na.jac",
             "variants": ["ref", "ffi"],
             "reference": "ref",
             "sizes": {
                 "one": ["1", "1"],
                 "small": SIZE_SMALL_CHURN,
                 "default": SIZE_DEFAULT_CHURN,

             },
             "metrics": ["per_ffi_call_ns"],
             "command_adapter": "clib_jit_jac_run",
             "requires_clib": False,
             "timing_source": "kernel_perf_counter_ns",
             "rss_scope": "not_recorded",

         },
         "iop_ffi_struct": {
             "scenario": "C ABI struct-by-value churn across INTEGER and MEMORY classes",
             "source": "kernels/iop_ffi_struct.na.jac",
             "variants": ["ref", "ffi"],
             "reference": "ref",
             "sizes": {
                 "one": ["1", "1"],
                 "small": SIZE_SMALL_CHURN,
                 "default": SIZE_DEFAULT_CHURN,

             },
             "metrics": ["per_ffi_call_ns"],
             "command_adapter": "clib_jit_jac_run",
             "requires_clib": True,
             "timing_source": "kernel_perf_counter_ns",
             "rss_scope": "not_recorded",

         },
         "iop_ffi_vtable": {
             "scenario": "C-invoked Jac callback through a __clibcb trampoline",
             "source": "kernels/iop_ffi_vtable.na.jac",
             "variants": ["ref", "ffi"],
             "reference": "ref",
             "sizes": {
                 "one": ["1", "1"],
                 "small": SIZE_SMALL_CHURN,
                 "default": SIZE_DEFAULT_CHURN,

             },
             "metrics": ["trampoline_call_ns"],
             "command_adapter": "clib_jit_jac_run",
             "requires_clib": True,
             "timing_source": "kernel_perf_counter_ns",
             "rss_scope": "not_recorded",

         },

     };


"""Parse the benchmark CLI."""
def parse_opts(argv: list[str]) -> dict[str, str | int | bool] {
    opts: dict[str, str | int | bool] = {
        "kernels": "iop_call,iop_cb,iop_symmetric,iop_view",
        "experimental": False,
        "variants": "",
        "sizes": "default",
        "invocations": DEFAULT_INVOCATIONS,
        "out": str(BENCH / "results" / "bridges_results.json"),

    };
    i = 1;
    while i < len(argv) {
        flag = argv[i];
        if flag == "--experimental" {
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
    return opts;
}


"""Build the Phase 4 C fixture into bin/ and verify its exported symbols.

The path is CWD-relative in the kernel source (`bin/libinteropbench.so`),
so the harness changes into the bench directory before invoking any
FFI kernel. We build deterministically: same source, same flags, same
output path, overwritten in place. Errors are actionable: missing cc,
failed compile, or missing symbols each raise a named message.

Linux x86_64 is the only runtime platform this adapter claims; the
failure mode on any other platform is a clear "cc unavailable" or
"build failed" message rather than a silent skip."""
def ensure_clib {
    if not CLIB_SOURCE.exists() {
        raise RuntimeError(f"C fixture source missing: {CLIB_SOURCE}");
    }
    cc = shutil.which("cc") or shutil.which("gcc");
    if not cc {
        raise RuntimeError(
            "no C compiler found on PATH (cc/gcc); required for iop_ffi_* kernels"
        );
    }
    CLIB_BINARY.parent.mkdir(parents=True, exist_ok=True);
    build = subprocess.run(
        [cc, "-shared", "-fPIC", "-O2", "-o", str(CLIB_BINARY), str(CLIB_SOURCE)],
        capture_output=True,
        text=True,
        timeout=60,
    );
    if build.returncode != 0 {
        raise RuntimeError(
            f"cc failed to build {CLIB_BINARY}\n"
            f"stdout:\n{build.stdout}\nstderr:\n{build.stderr}"
        );
    }
    verify = subprocess.run(
        ["nm", "-D", "--defined-only", str(CLIB_BINARY)],
        capture_output=True,
        text=True,
        timeout=30,
    );
    if verify.returncode != 0 {
        raise RuntimeError(
            f"nm failed to inspect {CLIB_BINARY}\n"
            f"stdout:\n{verify.stdout}\nstderr:\n{verify.stderr}"
        );
    }
    exported = {
        line.split()[-1]
        for line in verify.stdout.splitlines()
        if " T " in line
    };
    missing = [
        sym
        for sym in CLIB_EXPORTED_SYMBOLS
        if sym not in exported
    ];
    if missing {
        raise RuntimeError(
            f"{CLIB_BINARY} missing expected exports: {missing}; "
            f"got {sorted(exported)}"
        );
    }
}


"""Build the exact command for one catalogued adapter."""
def build_command(spec: dict[str, object], variant: str, args: list[str]) -> list[str] {
    adapter = spec["command_adapter"] as str;
    source = spec["source"] as str;
    if adapter in ("mixed_jit_jac_run", "clib_jit_jac_run") {
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


"""Aggregate one variant's collected runs and attach adapter metadata."""
def finalize_variant(
    spec: dict[str, object],
    variant: str,
    args: list[str],
    command: list[str],
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
    cell["command"] = command;
    cell["command_adapter"] = spec["command_adapter"] as str;
    cell["timing_source"] = spec["timing_source"] as str;
    cell["rss_scope"] = spec["rss_scope"] as str;
    return cell;
}


"""Measure an oracle group with paired, interleaved invocation ordering.

Each round runs one invocation of every variant before the next round,
so machine drift (frequency scaling, scheduler noise) hits both sides of
the differential comparison symmetrically rather than piling onto whichever
variant happened to run last."""
def measure_variants(
    spec: dict[str, object], selected_variants: list[str], args: list[str], count: int,
) -> dict[str, dict[str, object]] {
    commands = {
        variant: build_command(spec, variant, args) for variant in selected_variants
    };
    runs: dict[str, list[dict[str, object]]] = {
        variant: [] for variant in selected_variants
    };
    for _round in range(count) {
        for variant in selected_variants {
            runs[variant].append(run_command(commands[variant], 300, cwd=str(BENCH)));
        }
    }
    return {
        variant: finalize_variant(
            spec, variant, args, commands[variant], runs[variant]
        ) for variant in selected_variants
    };
}


"""Run every selected catalog cell and write schema-versioned JSON."""
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
    for kernel in kernels {
        if kernel not in CATALOG {
            raise ValueError(f"unknown kernel: {kernel}");
        }
        if kernel in EXPERIMENTAL_KERNELS and not (opts["experimental"] as bool) {
            raise ValueError(f"{kernel} is experimental; rerun with --experimental");
        }
    }
    needs_clib = any(CATALOG[k].get("requires_clib", False) as bool for k in kernels);
    if needs_clib {
        ensure_clib();
    }
    cells: dict[str, dict[str, object]] = {};
    for kernel in kernels {
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
