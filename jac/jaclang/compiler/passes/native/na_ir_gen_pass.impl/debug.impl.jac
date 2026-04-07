"""Debug helpers: post_transform dumps/validates the generated LLVM IR.

Environment variables
---------------------
JAC_DEBUG_IR=1        — save IR to .jac_ir/<stem>.ll next to the source file
JAC_VERIFY_IR=1       — run llvmlite parse_assembly to verify the IR
"""
import from jaclang.cli.console { console }
import from llvmlite { binding as llvm }
import os;
import sys;

"""Attach a DWARF DISubprogram to an LLVM function (JAC_NATIVE_DEBUG=1).

Creates DISubroutineType + DISubprogram metadata and sets it on the function.
Also marks the function as noinline so GDB sees real stack frames.
No-op when di_cu is None (debug mode disabled)."""
impl NaIRGenPass._attach_di_subprogram(
    func: ir.Function, name: str, line: int
) -> None {
    self._di_current_sp = None;
    if self.di_cu is None {
        return;
    }
    try {
        _di_sub_type = self.llvm_module.add_debug_info(
            "DISubroutineType", {"types": self.llvm_module.add_metadata([])}
        );
        _di_sp = self.llvm_module.add_debug_info(
            "DISubprogram",
            {
                "name": name,
                "file": self.di_file,
                "line": line,
                "isDefinition": True,
                "unit": self.di_cu,
                "type": _di_sub_type
            },
            is_distinct=True
        );
        func.set_metadata("dbg", _di_sp);
        self._di_current_sp = _di_sp;
    } except Exception {
        pass;
    }
    func.attributes.add("noinline");
}

"""Tag all instructions in a function that lack !dbg metadata with a fallback location.

LLVM verifier requires that all inlinable calls inside a function with
DISubprogram metadata carry a !dbg location.  This walks all blocks and
fills in a fallback DILocation for any untagged instruction.
No-op when _di_current_sp is None."""
impl NaIRGenPass._finalize_di_locations(func: ir.Function, fallback_line: int) -> None {
    if self._di_current_sp is None {
        return;
    }
    try {
        _fb_loc = self.llvm_module.add_debug_info(
            "DILocation",
            {"line": fallback_line, "column": 0, "scope": self._di_current_sp}
        );
        for _blk in func.blocks {
            for _instr in _blk.instructions {
                if "dbg" not in getattr(_instr, "metadata", {}) {
                    _instr.set_metadata("dbg", _fb_loc);
                }
            }
        }
    } except Exception {
        pass;
    }
}

"""Dump and/or validate the generated LLVM IR.  Called after transform()."""
impl NaIRGenPass.post_transform -> None {
    if not self.has_native_code {
        return;
    }

    # ── Emit DWARF compile-unit and required module flags (JAC_NATIVE_DEBUG) ──
    if self.di_cu is not None {
        try {
            self.llvm_module.add_named_metadata("llvm.dbg.cu").add(self.di_cu);
            _nm_flags = self.llvm_module.add_named_metadata("llvm.module.flags");
            _nm_flags.add(
                self.llvm_module.add_metadata(
                    [
                        ir.Constant(ir.IntType(32), 7),
                        "Dwarf Version",
                        ir.Constant(ir.IntType(32), 5)
                    ]
                )
            );
            _nm_flags.add(
                self.llvm_module.add_metadata(
                    [
                        ir.Constant(ir.IntType(32), 2),
                        "Debug Info Version",
                        ir.Constant(ir.IntType(32), 3)
                    ]
                )
            );
        } except Exception {
            pass;  # debug flags are best-effort
        }
    }

    ir_str = str(self.llvm_module);

    # ── Auto-save to .jac_ir/<stem>.ll when JAC_DEBUG_IR is set ─────────────
    if os.environ.get("JAC_DEBUG_IR", False) {
        src_path = self.ir_in.loc.mod_path;
        if src_path {
            src_dir = os.path.dirname(os.path.abspath(src_path));
            stem = os.path.splitext(os.path.basename(src_path))[0];
            ir_dir = os.path.join(src_dir, ".jac_ir");
            os.makedirs(ir_dir, exist_ok=True);
            auto_ir_path = os.path.join(ir_dir, stem + ".ll");
            with open(auto_ir_path, "w") as f {
                f.write(ir_str);
            }
            console.print(f"[JAC_DEBUG_IR] IR saved to: {auto_ir_path}");
        }
    }

    # ── Validate via parse_assembly ──────────────────────────────────────────
    if os.environ.get("JAC_VERIFY_IR", False) {
        console.print("[JAC_VERIFY_IR] Verifying LLVM IR ...");
        try {
            llvm.initialize();
            llvm.initialize_native_target();
            llvm.initialize_native_asmprinter();
            mod = llvm.parse_assembly(ir_str);
            mod.verify();
            console.print("[JAC_VERIFY_IR] OK — IR verified successfully.");
        } except Exception as exc {
            console.print(f"[JAC_VERIFY_IR] VERIFICATION FAILED: {exc}");
        }
    }
}
