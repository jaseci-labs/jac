impl JcirBytecodeGenPass.transform(self: JcirBytecodeGenPass, ir_in: Module) -> Module {
    self.process_modules(ir_in);
    return ir_in;
}

impl JcirBytecodeGenPass.process_modules(
    self: JcirBytecodeGenPass, root_module: Module
) -> None {
    mods = [root_module] + root_module.get_all_sub_nodes(Module);
    for mod in mods {
        self.cur_node = mod;
        self.transcribe_module(mod);
    }
}

impl JcirBytecodeGenPass.transcribe_module(
    self: JcirBytecodeGenPass, mod: Module
) -> None {
    import ast as ast3;
    import from jaclang.jac0core.codegen_shim { compile_ir, transcribe }
    if not mod.gen.jcir {
        if not mod.gen.py_bytecode {
            self.emit(E5040, node_override=mod, path=mod.loc.mod_path);
        }
        return;
    }
    (tmods, diags) = transcribe(mod.gen.jcir);
    if tmods {
        mod.gen.py_ast = [tmods[0][1]];
        mod.gen.py = ast3.unparse(tmods[0][1]);
    }
    result = compile_ir(mod.gen.jcir);
    for d in result.diags {
        self.emit(E5043, node_override=mod, error=d.message);
    }
    if result.modules {
        mod.gen.py_bytecode = result.modules[0].bytecode;
    }
}
