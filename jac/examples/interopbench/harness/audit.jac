"""Audit named native interop manifest and generated-wrapper facts.

Usage:
  jac run harness/audit.jac [--kernels iop_call,iop_cb,iop_symmetric]
      [--out results/interop_audit.json]
"""

import json;
import sys;
import from pathlib { Path }
import from jaclang.jac0core.program { JacProgram }


glob BENCH = Path(str(__file__)).resolve().parent.parent,
     CATALOG: dict[str, dict] = {
         "iop_call": {
             "audit_kind": "native_manifest",
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
             "audit_kind": "native_manifest",
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
         "iop_symmetric": {
             "audit_kind": "native_manifest",
             "source": "kernels/iop_symmetric.jac",
             "baseline_symbol": "run_sv_local",
             "native_imports": ["sv_lcg"],
             "native_exports": ["native_lcg", "run_na_local", "run_na_to_sv"],
             "markers": {
                 "export_address_lookup:native_lcg": {
                     "text": "get_function_address('native_lcg')",
                     "occurrences": 1,

                 },
                 "export_address_lookup:run_na_local": {
                     "text": "get_function_address('run_na_local')",
                     "occurrences": 1,

                 },
                 "export_address_lookup:run_na_to_sv": {
                     "text": "get_function_address('run_na_to_sv')",
                     "occurrences": 1,

                 },
                 "import_registration:sv_lcg": {
                     "text": "__jac_interop_py_funcs__['sv_lcg'] = sv_lcg",
                     "occurrences": 1,

                 },
                 "baseline_address_lookup:run_sv_local": {
                     "text": "get_function_address('run_sv_local')",
                     "occurrences": 0,

                 },

             },

         },
         "iop_ffi_scalar": {
             "audit_kind": "clib_ir",
             "source": "kernels/iop_ffi_scalar.na.jac",
             "clib_paths": ["/usr/lib/libm.so.6"],
             "extern_declares": ["sqrt"],
             "ir_markers": {
                 "extern_sqrt_declare": {"text": 'declare double @"sqrt"', "min": 1,},
                 "no_sqrt_definition": {"text": 'define double @"sqrt"', "max": 0,},
                 "no_trampoline": {"text": "__clibcb", "max": 0,},

             },

         },
         "iop_ffi_struct": {
             "audit_kind": "clib_ir",
             "source": "kernels/iop_ffi_struct.na.jac",
             "clib_paths": ["bin/libinteropbench.so"],
             "extern_declares": [
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

             ],
             "ir_markers": {
                 "integer_class_abi_load": {"text": "clib.arg.load", "min": 1,},
                 "integer_class_abi_cast": {"text": "clib.arg.cast", "min": 1,},
                 "memory_class_byval": {"text": "byval", "min": 1,},
                 "memory_class_sret": {"text": "sret", "min": 1,},
                 "no_trampoline": {"text": "__clibcb", "max": 0,},

             },

         },
         "iop_ffi_vtable": {
             "audit_kind": "clib_ir",
             "source": "kernels/iop_ffi_vtable.na.jac",
             "clib_paths": ["bin/libinteropbench.so"],
             "extern_declares": ["ib_invoke_event"],
             "ir_markers": {
                 "trampoline_emitted": {"text": "__clibcb", "min": 1,},
                 "trampoline_cached_once": {
                     "text": 'define internal i32 @"jac_callback.__clibcb.0"',
                     "min": 1,
                     "max": 1,

                 },
                 "no_duplicate_trampoline": {"text": ".__clibcb.1", "max": 0,},
                 "flat_vt_allocation": {"text": "clib.vt.raw", "min": 1,},

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
        audit_kind = spec.get("audit_kind", "native_manifest") as str;
        if audit_kind == "native_manifest" {
            cells[kernel] = audit_native_manifest(spec);
        } elif audit_kind == "clib_ir" {
            cells[kernel] = audit_clib_ir(spec);
        } else {
            raise ValueError(f"{kernel}: unknown audit_kind: {audit_kind}");
        }
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


"""Audit a Python↔native manifest cell (iop_call, iop_cb)."""
def audit_native_manifest(spec: dict) -> dict {
    source = spec["source"] as str;
    kernel = spec.get("scenario", source) as str;
    source_path = BENCH / source;
    program = JacProgram();
    ir = program.compile(str(source_path));
    if program.errors_had {
        raise RuntimeError(f"{source}: compile errors: {program.errors_had}");
    }
    manifest = ir.gen.interop_manifest;
    actual_imports = sorted([binding.name for binding in manifest.native_imports]);
    actual_exports = sorted([binding.name for binding in manifest.native_exports]);
    expected_imports = sorted(spec["native_imports"] as list[str]);
    expected_exports = sorted(spec["native_exports"] as list[str]);
    if actual_imports != expected_imports {
        raise ValueError(
            f"{source}: native imports {actual_imports} != {expected_imports}"
        );
    }
    if actual_exports != expected_exports {
        raise ValueError(
            f"{source}: native exports {actual_exports} != {expected_exports}"
        );
    }
    baseline_symbol = spec["baseline_symbol"] as str;
    all_bindings = set(actual_imports + actual_exports);
    if baseline_symbol in all_bindings {
        raise ValueError(
            f"{source}: baseline symbol unexpectedly has a native binding: "
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
                f"{source}: marker {marker_name} occurred {actual_count} times, "
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
    print(
        f"{source:34s} audit: OK "
        f"(imports={actual_imports}, exports={actual_exports})"
    );
    return {
        "audit_kind": "native_manifest",
        "source": source,
        "expected": {
            "native_imports": expected_imports,
            "native_exports": expected_exports,
            "baseline_without_native_binding": baseline_symbol,

        },
        "actual": {"native_imports": actual_imports, "native_exports": actual_exports,},
        "generated_wrapper_markers": marker_results,

    };
}


"""Audit a clib IR cell (iop_ffi_*): extern declares, ABI markers, trampoline."""
def audit_clib_ir(spec: dict) -> dict {
    source = spec["source"] as str;
    source_path = BENCH / source;
    program = JacProgram();
    ir = program.compile(str(source_path));
    if program.errors_had {
        raise RuntimeError(f"{source}: compile errors: {program.errors_had}");
    }
    ir_text = str(ir.gen.llvm_ir);
    actual_clib_paths = list(ir.gen._clib_paths or []);
    expected_clib_paths = spec["clib_paths"] as list[str];
    if actual_clib_paths != expected_clib_paths {
        raise ValueError(
            f"{source}: clib paths {actual_clib_paths} != {expected_clib_paths}"
        );
    }
    extern_results: dict[str, dict] = {};
    for sym in spec["extern_declares"] as list[str] {
        has_declare = f'declare %' in ir_text and f'@"{sym}"' in ir_text;
        declare_present = (
            f'declare ' in ir_text
            and any(
                line.strip().startswith("declare") and f'@"{sym}"' in line
                for line in ir_text.splitlines()
            )
        );
        has_define = any(
            line.strip().startswith("define") and f'@"{sym}"' in line
            for line in ir_text.splitlines()
        );
        if not declare_present or has_define {
            raise ValueError(
                f"{source}: extern '{sym}' must be a declare without a define "
                f"(declare_present={declare_present}, has_define={has_define})"
            );
        }
        extern_results[sym] = {"declare": True, "define": False};
    }
    marker_results: dict[str, dict] = {};
    markers = spec["ir_markers"] as dict[str, dict];
    for (marker_name, marker_spec) in markers.items() {
        text = marker_spec["text"] as str;
        actual = ir_text.count(text);
        min_count = marker_spec.get("min", 0) as int;
        max_count = marker_spec.get("max", 1 << 62) as int;
        ok = actual >= min_count and actual <= max_count;
        if not ok {
            raise ValueError(
                f"{source}: IR marker {marker_name} count={actual} "
                f"not in [{min_count}, {max_count}]"
            );
        }
        marker_results[marker_name] = {
            "text": text,
            "min": min_count,
            "max": max_count,
            "actual": actual,
            "matches": True,

        };
    }
    print(
        f"{source:34s} audit: OK "
        f"(clib_paths={actual_clib_paths}, "
        f"externs={spec["extern_declares"] as list[str]})"
    );
    return {
        "audit_kind": "clib_ir",
        "source": source,
        "expected": {
            "clib_paths": expected_clib_paths,
            "extern_declares": spec["extern_declares"],

        },
        "actual": {"clib_paths": actual_clib_paths,},
        "extern_results": extern_results,
        "ir_markers": marker_results,

    };
}


with entry {
    main(parse_opts(sys.argv));
}
