"""Python Bytecode Generation Pass for the Jac compiler.

This pass compiles Python AST into executable bytecode by:

1. Processing all modules in the program, including the main module and its sub-modules
2. Converting Python AST nodes into Python bytecode using the standard Python compiler
3. Serializing the bytecode for efficient storage and execution
4. Handling error cases where AST nodes cannot be properly compiled

The bytecode generation is the final step in the compilation pipeline before execution,
transforming the high-level AST representation into an optimized form that can be
directly executed by the Python virtual machine.
"""

import ast as ast3
import marshal

import jaclang.pycore.unitree as uni
from jaclang.pycore.passes.transform import Transform


class PyBytecodeGenPass(Transform[uni.Module, uni.Module]):
    """Python and bytecode file printing pass."""

    def transform(self, ir_in: uni.Module) -> uni.Module:
        """Transform AST into Python bytecode."""
        self.process_modules(ir_in)
        return ir_in

    def process_modules(self, root_module: uni.Module) -> None:
        """Process all modules in the program."""
        mods = [root_module] + root_module.get_all_sub_nodes(uni.Module)

        for mod in mods:
            self.cur_node = mod
            self.compile_module_to_bytecode(mod)

    def compile_module_to_bytecode(self, mod: uni.Module) -> None:
        """Compile a module to Python bytecode."""
        if not mod.gen.py_ast or not isinstance(mod.gen.py_ast[0], ast3.Module):
            self.log_error(f"Unable to find ast for module {mod.loc.mod_path}.")
            return

        root_node = mod.gen.py_ast[0]
        assert isinstance(root_node, ast3.Module)

        mod.gen.py_bytecode = marshal.dumps(
            compile(source=root_node, filename=mod.loc.mod_path, mode="exec")
        )
