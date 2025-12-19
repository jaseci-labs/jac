"""Module Import Resolution Pass for the Jac compiler.

This pass handles the static resolution and loading of imported modules by:

1. Identifying import statements in the source code
2. Resolving module paths (both relative and absolute)
3. Loading and parsing the imported modules
4. Handling both Jac and Python imports with appropriate strategies
5. Managing import dependencies and preventing circular imports
6. Supporting various import styles:
   - Direct imports (import x)
   - From imports (from x import y)
   - Star imports (from x import *)
   - Aliased imports (import x as y)
7. Supporting cross-language imports:
   - JavaScript (.js) and TypeScript (.ts, .tsx, .jsx) files

The pass runs early in the compilation pipeline to ensure all symbols from imported
modules are available for subsequent passes like symbol table building and type checking.
"""
import os;
import jaclang.pycore.unitree as uni;
import from jaclang.pycore.passes { Transform, UniPass }
import from jaclang.pycore.log { logging }

glob logger = logging.getLogger(__name__);
"""Jac statically imports Jac modules."""
class JacImportDepsPass(Transform[(uni.Module, uni.Module)]) {
    def pre_transform(self: JacImportDepsPass) -> None;
    def transform(self: JacImportDepsPass, ir_in: uni.Module) -> uni.Module;
    def process_import(self: JacImportDepsPass, i: uni.ModulePath) -> None;
    def import_jac_module(self: JacImportDepsPass, <>node: uni.ModulePath) -> None;
    def load_mod(self: JacImportDepsPass, mod: uni.Module) -> None;
    def import_jac_mod_from_dir(self: JacImportDepsPass, target: str) -> uni.Module;
    def import_ts_module(self: JacImportDepsPass, <>node: uni.ModulePath) -> None;
}
