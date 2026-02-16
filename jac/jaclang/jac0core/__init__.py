"""Jac0Core - Bootstrap core modules for the Jac compiler.

This package contains the core Jac modules compiled by jac0 (the bootstrap
transpiler) during first-run setup. These modules form the compiler
infrastructure: AST definitions, passes, runtime, and utilities.

Modules:
- unitree: Core AST definitions
- constant: Constants and token definitions
- codeinfo: Code location info for AST nodes
- passes/: Bootstrap-critical compiler passes
- runtime: Runtime bootstrap infrastructure
- helpers: Utility functions
- log: Logging utilities
- modresolver: Module resolution utilities
- treeprinter: AST tree printing utilities
- settings: Configuration settings
- compiler: JacCompiler class (compilation singleton)
- program: JacProgram class (program state)
"""
