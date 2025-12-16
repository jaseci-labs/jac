"""Passes for Jac."""

from jaclang.pycore.passes.ast_gen import BaseAstGenPass
from jaclang.pycore.passes.uni_pass import Transform, UniPass

__all__ = ["Transform", "UniPass", "BaseAstGenPass"]
