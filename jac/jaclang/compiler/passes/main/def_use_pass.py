"""Definition-Use Analysis Pass for the Jac compiler.

This pass performs comprehensive symbol resolution by:
1. Populating symbol tables with additional symbols from various AST constructs:
   - Variable assignments and declarations
   - Function/ability parameters
   - Archetype reference chains
   - Loop variables and comprehension targets
   - With-statement variables

2. Establishing bidirectional links between:
   - Symbol definitions in the symbol table
   - Symbol uses throughout the AST

3. Handling special cases:
   - Inheriting symbol tables from base classes for archetypes
   - Setting appropriate context for symbols in different operations (e.g., delete statements)
   - Marking walker-specific statements (visit, ignore, disengage) when in walker context

This pass is crucial for type checking, access control validation, and code generation as it
creates the complete symbol resolution map for the program.
"""

import jaclang.compiler.unitree as uni
from jaclang.compiler.constant import Tokens as Tok
from jaclang.compiler.passes import UniPass


class DefUsePass(UniPass):
    """Jac Ast build pass."""

    def enter_archetype(self, node: uni.Archetype) -> None:
        node.sym_tab.inherit_baseclasses_sym(node)

        def inform_from_walker(node: uni.UniNode) -> None:
            for i in (
                node.get_all_sub_nodes(uni.VisitStmt)
                + node.get_all_sub_nodes(uni.DisengageStmt)
                + node.get_all_sub_nodes(uni.EdgeOpRef)
                + node.get_all_sub_nodes(uni.EventSignature)
            ):
                i.from_walker = True

        if node.arch_type.name == Tok.KW_WALKER:
            inform_from_walker(node)
            for i in self.get_all_sub_nodes(node, uni.Ability):
                if isinstance(i.body, uni.ImplDef):
                    inform_from_walker(i.body)

    def enter_enum(self, node: uni.Enum) -> None:
        node.sym_tab.inherit_baseclasses_sym(node)

    def enter_type_ref(self, node: uni.TypeRef) -> None:
        node.sym_tab.use_lookup(node)

    def enter_param_var(self, node: uni.ParamVar) -> None:
        node.sym_tab.def_insert(node)

    def enter_has_var(self, node: uni.HasVar) -> None:
        if isinstance(node.parent, uni.ArchHas):
            node.sym_tab.def_insert(
                node, single_decl="has var", access_spec=node.parent
            )
        else:
            self.ice("Inconsistency in AST, has var should be under arch has")

    def enter_assignment(self, node: uni.Assignment) -> None:
        for i in node.target:
            if isinstance(i, uni.AtomTrailer):
                i.sym_tab.chain_def_insert(i.as_attr_list)
            elif isinstance(i, uni.AstSymbolNode):
                i.sym_tab.def_insert(i)
            else:
                self.log_error("Assignment target not valid")

    def enter_inner_compr(self, node: uni.InnerCompr) -> None:
        if isinstance(node.target, uni.AtomTrailer):
            node.target.sym_tab.chain_def_insert(node.target.as_attr_list)

        elif isinstance(node.target, uni.AstSymbolNode):
            node.target.sym_tab.def_insert(node.target)
        else:
            self.log_error("Named target not valid")

    def enter_atom_trailer(self, node: uni.AtomTrailer) -> None:
        chain = node.as_attr_list
        node.sym_tab.chain_use_lookup(chain)

    def enter_special_var_ref(self, node: uni.SpecialVarRef) -> None:
        node.sym_tab.use_lookup(node)

    def enter_float(self, node: uni.Float) -> None:
        node.sym_tab.use_lookup(node)

    def enter_int(self, node: uni.Int) -> None:
        node.sym_tab.use_lookup(node)

    def enter_string(self, node: uni.String) -> None:
        node.sym_tab.use_lookup(node)

    def enter_bool(self, node: uni.Bool) -> None:
        node.sym_tab.use_lookup(node)

    def enter_builtin_type(self, node: uni.BuiltinType) -> None:
        node.sym_tab.use_lookup(node)

    def enter_name(self, node: uni.Name) -> None:
        if not isinstance(node.parent, uni.AtomTrailer):
            node.sym_tab.use_lookup(node)

    def enter_in_for_stmt(self, node: uni.InForStmt) -> None:
        if isinstance(node.target, uni.AtomTrailer):
            node.target.sym_tab.chain_def_insert(node.target.as_attr_list)
        elif isinstance(node.target, uni.AstSymbolNode):
            node.target.sym_tab.def_insert(node.target)
        else:
            self.log_error("For loop assignment target not valid")

    def enter_expr_as_item(self, node: uni.ExprAsItem) -> None:
        if node.alias:
            if isinstance(node.alias, uni.AtomTrailer):
                node.alias.sym_tab.chain_def_insert(node.alias.as_attr_list)
            elif isinstance(node.alias, uni.AstSymbolNode):
                node.alias.sym_tab.def_insert(node.alias)
            else:
                self.log_error("For expr as target not valid")
