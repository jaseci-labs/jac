impl JcirBytecodeGenPass._run_impl(ir_in: Module) -> Module {
    self.process_modules(ir_in);
    return ir_in;
}

impl JcirBytecodeGenPass.process_modules(root_module: Module) -> None {
    mods = [root_module] + root_module.get_all_sub_nodes(Module);
    for mod in mods {
        self.ctx.current_node = mod;
        self.transcribe_module(mod);
    }
}

impl JcirBytecodeGenPass.transcribe_module(mod: Module) -> None {
    import ast as ast3;
    import from jaclang.compiler.backends.py.codegen_shim { compile_ir }
    if not mod.gen.jcir {
        if not mod.gen.py_bytecode {
            self.ctx.emit(E5040, node_override=mod, path=mod.loc.mod_path);
        }
        return;
    }
    result = compile_ir(mod.gen.jcir);
    for d in result.diags {
        self.ctx.emit(E5043, node_override=mod, error=d.message);
    }
    if result.modules {
        compiled = result.modules[0];
        mod.gen.py_ast = [compiled.tree];
        mod.gen.py = ast3.unparse(compiled.tree);
        mod.gen.py_bytecode = compiled.bytecode;
    }
}

impl JcirBytecodeGenPass.run_walk with Module entry {
    self.module = self._run_impl(here);
}
