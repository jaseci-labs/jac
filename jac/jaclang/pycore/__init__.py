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
- modresolver: Module resolution utilities
- treeprinter: AST tree printing utilities
- settings: Configuration settings
- compiler: JacCompiler class (compilation singleton)
- program: JacProgram class (program state)
"""
