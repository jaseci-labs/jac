import from jaclang.cli.console { console }
import from jaclang.compiler.passes.native.llvm { binding as llvm }
import os;
import sys;

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
    } except Exception { }
    func.attributes.add("noinline");
}

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
    } except Exception { }
}

impl NaIRGenPass.post_transform -> None {
    if not self.has_native_code {
        return;
    }

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
        } except Exception { }
    }

    ir_str = str(self.llvm_module);

    if os.environ.get("JAC_DEBUG_IR", "").strip().lower() in (
        "1",
        "true",
        "yes",
        "on"
    ) {
        import from jaclang.jac0core.jir { get_native_cache_dir }
        src_path = self.ir_in.loc.mod_path;
        if src_path {
            stem = os.path.splitext(os.path.basename(src_path))[0];
            ir_dir = str(get_native_cache_dir(src_path));
            os.makedirs(ir_dir, exist_ok=True);
            auto_ir_path = os.path.join(ir_dir, stem + ".ll");
            with open(auto_ir_path, "w") as f {
                f.write(ir_str);
            }
            console.print(f"[JAC_DEBUG_IR] IR saved to: {auto_ir_path}");
        }
    }
}
