"""Jac Semantic Analysis Pass."""

import ast as ast3

import jaclang.compiler.unitree as uni
from jaclang.compiler.constant import Tokens as Tok
from jaclang.compiler.passes import UniPass


class SemanticAnalysisPass(UniPass):
    """Jac Semantic Analysis Pass."""

    def enter_archetype(self, node: uni.Archetype) -> None:
        def inform_from_walker(node: uni.UniNode) -> None:
            for i in (
                node.get_all_sub_nodes(uni.VisitStmt)
                + node.get_all_sub_nodes(uni.DisengageStmt)
                + node.get_all_sub_nodes(uni.EdgeOpRef)
                + node.get_all_sub_nodes(uni.EventSignature)
                + node.get_all_sub_nodes(uni.TypedCtxBlock)
            ):
                i.from_walker = True

        if node.arch_type.name == Tok.KW_WALKER:
            inform_from_walker(node)
            for i in self.get_all_sub_nodes(node, uni.Ability):
                if isinstance(i.body, uni.ImplDef):
                    inform_from_walker(i.body)

    # ------------context update methods---------------------------
    def _update_ctx(self, node: uni.UniNode) -> None:
        if isinstance(node, uni.AtomTrailer):
            self._change_atom_trailer_ctx(node)
        elif isinstance(node, uni.AstSymbolNode):
            node.sym_tab.update_py_ctx_for_def(node)
        else:
            self.log_error(f"Invalid target for context update: {type(node).__name__}")

    def enter_has_var(self, node: uni.HasVar) -> None:
        if isinstance(node.parent, uni.ArchHas):
            node.sym_tab.update_py_ctx_for_def(node)
        else:
            self.ice("HasVar should be under ArchHas")

    def enter_param_var(self, node: uni.ParamVar) -> None:
        node.sym_tab.update_py_ctx_for_def(node)

    def enter_assignment(self, node: uni.Assignment) -> None:
        for target in node.target:
            self._update_ctx(target)

    def enter_in_for_stmt(self, node: uni.InForStmt) -> None:
        self._update_ctx(node.target)

    def enter_expr_as_item(self, node: uni.ExprAsItem) -> None:
        if node.alias:
            self._update_ctx(node.alias)

    def enter_inner_compr(self, node: uni.InnerCompr) -> None:
        self._update_ctx(node.target)

    # ----------------------- Utilities -------------------------

    def _change_atom_trailer_ctx(self, node: uni.AtomTrailer) -> None:
        """Mark final element in trailer chain as a Store context."""
        last = node.right
        if isinstance(last, uni.AtomExpr):
            last.name_spec.py_ctx_func = ast3.Store
            if isinstance(last.name_spec, uni.AstSymbolNode):
                last.name_spec.py_ctx_func = ast3.Store
