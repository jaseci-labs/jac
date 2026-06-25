"""C-to-Jac transpiler package.

Converts C source to Jac via: pycparser C-AST → CPython ast → PyastBuildPass → Jac.
For constructs with no faithful Python-AST analog (C-for, enums) the direct-IR path
builds uni nodes and splices them in via a placeholder-token scheme.

Public entry: from jaclang.compiler.c2jac.driver import transpile_c_str
"""
