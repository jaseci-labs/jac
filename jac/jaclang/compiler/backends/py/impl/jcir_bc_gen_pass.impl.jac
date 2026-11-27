impl JcirBytecodeGenPass._run_impl(ir_in: Module) -> Module {
    self.process_modules(ir_in);
    return ir_in;
}

impl JcirBytecodeGenPass.process_modules(root_module: Module) -> None {
    mods = [root_module] + root_module.get_all_sub_nodes(Module);
    for mod in mods {
        self.ctx.current_node = mod;
        self.compile_module(mod);
    }
}

impl JcirBytecodeGenPass.compile_module(mod: Module) -> None {
    tree = mod.gen.py_tree;
    if tree is None {
        if not mod.gen.py_bytecode {
            self.ctx.emit(E5040, node_override=mod, path=mod.loc.mod_path);
        }
        return;
    }
    try {
        code_obj = compile(tree, mod.loc.mod_path, "exec", dont_inherit=True);
    } except (ValueError, SyntaxError, TypeError) as e {
        self.ctx.emit(E5043, node_override=mod, error=str(e));
        return;
    }
    mod.gen.py_ast = [tree];
    mod.gen.py_text = None;
    mod.gen.py_bytecode = marshal.dumps(code_obj);
}

impl JcirBytecodeGenPass.run_walk with Module entry {
    self.module = self._run_impl(here);
}
