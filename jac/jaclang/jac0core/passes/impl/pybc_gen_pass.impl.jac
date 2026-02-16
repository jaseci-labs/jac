"""Implementation for pybc_gen_pass constructs."""

"""Transform AST into Python bytecode."""
impl PyBytecodeGenPass.transform(
    self: PyBytecodeGenPass, ir_in: uni.Module
) -> uni.Module {
    self.process_modules(ir_in);
    return ir_in;
}

"""Process all modules in the program."""
impl PyBytecodeGenPass.process_modules(
    self: PyBytecodeGenPass, root_module: uni.Module
) -> None {
    mods = [root_module] + root_module.get_all_sub_nodes(uni.Module);
    for mod in mods {
        self.cur_node = mod;
        self.compile_module_to_bytecode(mod);
    }
}

"""Compile a module to Python bytecode."""
impl PyBytecodeGenPass.compile_module_to_bytecode(
    self: PyBytecodeGenPass, mod: uni.Module
) -> None {
    if (not mod.gen.py_ast or not isinstance(mod.gen.py_ast[0], ast3.Module)) {
        self.log_error(f"Unable to find ast for module{mod.loc.mod_path}.");
        return;
    }
    root_node = mod.gen.py_ast[0];
    assert isinstance(root_node, ast3.Module);
    mod.gen.py_bytecode = marshal.dumps(
        compile(source=root_node, filename=mod.loc.mod_path, mode='exec')
    );
}
