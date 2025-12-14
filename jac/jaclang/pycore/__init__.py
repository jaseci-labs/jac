"""PyCore - Bootstrap-critical Python core for Jac.

This package contains the minimal Python code required to bootstrap the Jac
compiler. Everything else in the jaclang codebase can be written in Jac.

Modules:
- unitree: Core AST definitions
- constant: Constants and token definitions
- codeinfo: Code location info for AST nodes
- jac_parser: Jac parser using Lark
- tsparser: TypeScript/JavaScript parser
- lark_jac_parser: Generated Lark parser for Jac
- lark_ts_parser: Generated Lark parser for TypeScript
- passes/: Bootstrap-critical compiler passes
- runtime: Runtime bootstrap infrastructure
- helpers: Utility functions
- log: Logging utilities
- module_resolver: Module resolution utilities
- treeprinter: AST tree printing utilities
- settings: Configuration settings
- program: JacProgram class
"""

# Note: Don't eagerly import submodules here to avoid circular imports.
# Submodules are imported lazily when accessed.

__all__ = [
    "unitree",
    "constant",
    "codeinfo",
    "jac_parser",
    "tsparser",
    "lark_jac_parser",
    "lark_ts_parser",
    "passes",
    "runtime",
    "helpers",
    "log",
    "module_resolver",
    "treeprinter",
    "settings",
    "program",
]
