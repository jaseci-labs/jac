import os;
import sys;

impl NaIRGenPass._native_tls_on -> bool {
    opts = self.prog.options;
    return opts is not None and bool(opts.native_tls);
}

impl NaIRGenPass._native_sjlj_on -> bool {
    opts = self.prog.options;
    return opts is not None and bool(opts.native_sjlj);
}

impl NaIRGenPass._unchecked_views_on -> bool {
    opts = self.prog.options;
    return opts is not None and bool(opts.native_unchecked_views);
}

impl NaIRGenPass._heap_extern(kind: str) -> ir.Function {
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    opts = self.prog.options;
    name = kind;
    if opts is not None and opts.native_heap and self._gc_mode() != "none" {
        name = f"{opts.native_heap}_{kind}";
    }
    if kind == "free" {
        return self._get_or_declare_extern(name, ir.VoidType(), [i8p]);
    }
    if kind == "calloc" {
        return self._get_or_declare_extern(name, i8p, [i64, i64]);
    }
    if kind == "realloc" {
        return self._get_or_declare_extern(name, i8p, [i8p, i64]);
    }
    return self._get_or_declare_extern(name, i8p, [i64]);
}

impl NaIRGenPass._heap_usable_size(
    b: ir.IRBuilder, block: ir.Value, name: str
) -> ir.Value {
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    opts = self.prog.options;
    if opts is not None and opts.native_heap and self._gc_mode() != "none" {
        size_fn = self._get_or_declare_extern(
            f"{opts.native_heap}_usable_size", i64, [i8p]
        );
        return b.call(size_fn, [block], name=name);
    }
    return self._floor_call("__jac_malloc_size", i64, [block], name, b);
}

impl NaIRGenPass._direct_c_entry(fn: ir.Function) -> bool {
    if self._is_kernel_unit() {
        return True;
    }
    opts = self.prog.options;
    if opts is None {
        return False;
    }
    if opts.native_heap
        and fn.name
            in [
                f"{opts.native_heap}_{kind}"
                for kind in ("malloc", "calloc", "realloc", "free", "usable_size")
            ] {
        return True;
    }
    return bool(opts.native_direct_c_entries)
        and (fn.calling_convention or "") == "preserve_nonecc";
}

impl NaIRGenPass._na_debug_on -> bool {
    _opts = self.prog.options;
    return _opts is not None and bool(_opts.na_debug);
}

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
    } except Exception {}
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
                if isinstance(_instr, ir.Instruction)
                    and "dbg" not in _instr.metadata {
                    _instr.set_metadata("dbg", _fb_loc);
                }
            }
        }
    } except Exception {}
}

impl NaIRGenPass.finish with exit {
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
        } except Exception {}
    }

    for _fn in self.llvm_module.functions {
        for _blk in _fn.blocks {
            if not _blk.is_terminated {
                _ob = ir.IRBuilder(_blk);
                _ob.unreachable();
            }
        }
    }

    if self.prog.options.debug_ir {
        self._save_debug_ir(str(self.llvm_module));
    }
}

impl NaIRGenPass._save_debug_ir(ir_str: str) -> None {
    src_path = self.module.loc.mod_path;
    if src_path {
        active_host().save_native_debug_ir(src_path, ir_str);
    }
}
