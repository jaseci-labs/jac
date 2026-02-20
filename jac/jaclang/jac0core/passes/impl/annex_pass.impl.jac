"""Implementation for annex_pass constructs."""

"""Load and attach annex modules to the given module."""
impl JacAnnexPass.transform(self: JacAnnexPass, ir_in: uni.Module) -> uni.Module {
    mod_path = ir_in.loc.mod_path;
    if (ir_in.stub_only or not mod_path.endswith('.jac') or ir_in.annexable_by) {
        return ir_in;
    }
    self._load_annexes(self.prog, ir_in, mod_path);
    return ir_in;
}

"""Parse and attach annex modules to the node."""
impl JacAnnexPass._load_annexes(
    self: JacAnnexPass, jac_program: JacProgram, nd: uni.Module, mod_path: str
) -> None {
    # Determine parent context and appropriate annex suffix
    # .cl.jac -> .impl.cl.jac, .sv.jac -> .impl.sv.jac, etc.
    is_client_parent = mod_path.endswith('.cl.jac');
    is_server_parent = mod_path.endswith('.sv.jac');
    is_native_parent = mod_path.endswith('.na.jac');

    if is_client_parent {
        impl_suffix = '.impl.cl.jac';
        test_suffix = '.test.cl.jac';
    } elif is_server_parent {
        impl_suffix = '.impl.sv.jac';
        test_suffix = '.test.sv.jac';
    } elif is_native_parent {
        impl_suffix = '.impl.na.jac';
        test_suffix = '.test.na.jac';
    } else {
        impl_suffix = '.impl.jac';
        test_suffix = '.test.jac';
    }

    # Lazy import to avoid circular dependency
    if is_client_parent or is_server_parent or is_native_parent {
        import from jaclang.jac0core.compiler {
            _coerce_client_module,
            _coerce_server_module,
            _coerce_native_module
        }
    }

    for path in discover_annex_files(mod_path, impl_suffix) {
        if (mod := jac_program.compile(file_path=path, no_cgen=True)) {
            # Coerce impl module to match parent context
            if is_client_parent {
                _coerce_client_module(mod);
            } elif is_server_parent {
                _coerce_server_module(mod);
            } elif is_native_parent {
                _coerce_native_module(mod);
            }
            nd.impl_mod.append(mod);
        }
    }
    for path in discover_annex_files(mod_path, test_suffix) {
        if (mod := jac_program.compile(file_path=path, no_cgen=True)) {
            # Coerce test module to match parent context
            if is_client_parent {
                _coerce_client_module(mod);
            } elif is_server_parent {
                _coerce_server_module(mod);
            } elif is_native_parent {
                _coerce_native_module(mod);
            }
            nd.test_mod.append(mod);
        }
    }
}
