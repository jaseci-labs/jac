"""Audit named native interop manifest and generated-wrapper facts.

Usage:
  jac run harness/audit.jac [--kernels iop_call,iop_cb]
      [--out results/interop_audit.json]
"""

import json;
import sys;
import from pathlib { Path }
import from jaclang.jac0core.program { JacProgram }


glob BENCH = Path(str(__file__)).resolve().parent.parent,
     CATALOG: dict[str, dict] = {
         "iop_call": {
             "source": "kernels/iop_call.jac",
             "baseline_symbol": "sv_checksum",
             "native_imports": [],
             "native_exports": ["native_checksum"],
             "markers": {
                 "export_address_lookup:native_checksum": {
                     "text": "get_function_address('native_checksum')",
                     "occurrences": 1,

                 },
                 "export_cfunctype:native_checksum": {
                     "text": (
                         "ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64, "
                         "ctypes.c_int64)(_addr)"
                     ),
                     "occurrences": 1,

                 },
                 "baseline_address_lookup:sv_checksum": {
                     "text": "get_function_address('sv_checksum')",
                     "occurrences": 0,

                 },

             },

         },
         "iop_cb": {
             "source": "kernels/iop_cb.jac",
             "baseline_symbol": "sv_direct_checksum",
             "native_imports": ["sv_callback_checksum"],
             "native_exports": ["native_invoke_callback"],
             "markers": {
                 "export_address_lookup:native_invoke_callback": {
                     "text": "get_function_address('native_invoke_callback')",
                     "occurrences": 1,

                 },
                 "export_cfunctype:native_invoke_callback": {
                     "text": (
                         "ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64, "
                         "ctypes.c_int64)(_addr)"
                     ),
                     "occurrences": 1,

                 },
                 "import_registration:sv_callback_checksum": {
                     "text": (
                         "__jac_interop_py_funcs__['sv_callback_checksum'] = "
                         "sv_callback_checksum"
                     ),
                     "occurrences": 1,

                 },
                 "baseline_address_lookup:sv_direct_checksum": {
                     "text": "get_function_address('sv_direct_checksum')",
                     "occurrences": 0,

                 },

             },

         },

     };


"""Parse the audit CLI."""
def parse_opts(argv: list[str]) -> dict[str, str] {
    opts: dict[str, str] = {
        "kernels": "iop_call,iop_cb",
        "out": str(BENCH / "results" / "interop_audit.json"),

    };
    i = 1;
    while i < len(argv) {
        flag = argv[i];
        if flag in ("--kernels", "--out") and i + 1 < len(argv) {
            opts[flag[2:]] = argv[i + 1];
            i += 2;
        } else {
            raise ValueError(f"unknown or incomplete option: {flag}\n{__doc__}");
        }
    }
    return opts;
}


"""Compile selected cells and require their exact named interop facts."""
def main(opts: dict[str, str]) {
    kernels = [
        name
        for name in (opts["kernels"] as str).split(",")
        if name
    ];
    if not kernels {
        raise ValueError("--kernels must select at least one kernel");
    }
    if len(kernels) != len(set(kernels)) {
        raise ValueError("--kernels contains duplicate names");
    }
    cells: dict[str, dict] = {};
    for kernel in kernels {
        if kernel not in CATALOG {
            raise ValueError(f"unknown kernel: {kernel}");
        }
        spec = CATALOG[kernel] as dict;
        source = spec["source"] as str;
        source_path = BENCH / source;
        program = JacProgram();
        ir = program.compile(str(source_path));
        if program.errors_had {
            raise RuntimeError(f"{kernel}: compile errors: {program.errors_had}");
        }
        manifest = ir.gen.interop_manifest;
        actual_imports = sorted([binding.name for binding in manifest.native_imports]);
        actual_exports = sorted([binding.name for binding in manifest.native_exports]);
        expected_imports = sorted(spec["native_imports"] as list[str]);
        expected_exports = sorted(spec["native_exports"] as list[str]);
        if actual_imports != expected_imports {
            raise ValueError(
                f"{kernel}: native imports {actual_imports} != {expected_imports}"
            );
        }
        if actual_exports != expected_exports {
            raise ValueError(
                f"{kernel}: native exports {actual_exports} != {expected_exports}"
            );
        }
        baseline_symbol = spec["baseline_symbol"] as str;
        all_bindings = set(actual_imports + actual_exports);
        if baseline_symbol in all_bindings {
            raise ValueError(
                f"{kernel}: baseline symbol unexpectedly has a native binding: "
                f"{baseline_symbol}"
            );
        }
        py_source = ir.gen.py;
        marker_results: dict[str, dict] = {};
        markers = spec["markers"] as dict[str, dict];
        for (marker_name, marker_spec) in markers.items() {
            marker_text = marker_spec["text"] as str;
            expected_count = marker_spec["occurrences"] as int;
            actual_count = py_source.count(marker_text);
            if actual_count != expected_count {
                raise ValueError(
                    f"{kernel}: marker {marker_name} occurred {actual_count} times, "
                    f"expected {expected_count}"
                );
            }
            marker_results[marker_name] = {
                "text": marker_text,
                "expected_occurrences": expected_count,
                "actual_occurrences": actual_count,
                "matches": True,

            };
        }
        cells[kernel] = {
            "source": source,
            "expected": {
                "native_imports": expected_imports,
                "native_exports": expected_exports,
                "baseline_without_native_binding": baseline_symbol,

            },
            "actual": {
                "native_imports": actual_imports,
                "native_exports": actual_exports,

            },
            "generated_wrapper_markers": marker_results,

        };
        print(
            f"{kernel:12s} audit: OK "
            f"(imports={actual_imports}, exports={actual_exports})"
        );
    }
    out = Path(opts["out"] as str);
    document = {
        "schema_version": 1,
        "suite": "interopbench",
        "audit": "native_interop_manifest_and_wrappers",
        "cells": cells,

    };
    out.parent.mkdir(parents=True, exist_ok=True);
    out.write_text(json.dumps(document, indent=2) + "\n");
    print(f"wrote {out}");
}


with entry {
    main(parse_opts(sys.argv));
}
