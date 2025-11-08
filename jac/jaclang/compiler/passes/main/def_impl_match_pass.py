"""Declaration-Implementation Matching Pass for the Jac compiler.

This pass connects declarations (Decls) of Archetypes and Abilities with their separate
implementations (Defs) in the AST. It:

1. Establishes links between declarations in the main module and their implementations
   in separate .impl.jac files
2. Validates parameter matching between ability declarations and their implementations
3. Ensures proper inheritance of symbol tables between declarations and implementations
4. Performs validation checks on archetypes, including:
   - Proper ordering of default and non-default attributes
   - Presence of required postinit methods for deferred attributes
   - Abstract ability implementation validation

This pass is essential for Jac's separation of interface and implementation, allowing
developers to define archetype and ability interfaces in one file while implementing
their behavior in separate files.
"""

from typing import Sequence

import jaclang.compiler.unitree as uni
from jaclang.compiler.constant import Tokens as Tok
from jaclang.compiler.passes.transform import Transform
from jaclang.compiler.unitree import Symbol, UniScopeNode


class DeclImplMatchPass(Transform[uni.Module, uni.Module]):
    """Decls and Def matching pass."""

    def transform(self, ir_in: uni.Module) -> uni.Module:
        """Connect Decls and Defs."""
        self.cur_node = ir_in

        self.connect_impls(ir_in.sym_tab, ir_in.sym_tab)
        for impl_module in ir_in.impl_mod:
            self.connect_impls(impl_module.sym_tab, ir_in.sym_tab)

        self.check_archetypes(ir_in)
        return ir_in

    def defn_lookup(self, lookup: Symbol) -> uni.NameAtom | None:
        """Lookup a definition in a symbol table."""
        for defn in range(len(lookup.defn)):
            candidate = lookup.defn[len(lookup.defn) - (defn + 1)]
            if (
                isinstance(candidate.name_of, uni.AstImplNeedingNode)
                and candidate.name_of.needs_impl
            ):
                return candidate
        return None

    def connect_impls(
        self, source_sym_tab: UniScopeNode, target_sym_tab: UniScopeNode
    ) -> None:
        """Connect implementations from source symbol table to declarations in target symbol table.

        When source_sym_tab and target_sym_tab are the same, this connects within the same module.
        When different, it connects implementations from impl_mod to declarations in the main module.
        """
        # Process all symbols in the source symbol table
        for sym in source_sym_tab.names_in_scope.values():
            if not isinstance(sym.decl.name_of, uni.ImplDef):
                continue

            # Extract archetype references
            arch_refs = sym.sym_name.split(".")[1:]  # Remove the impl. prefix
            name_of_links: list[uni.NameAtom] = []  # to link archref names to decls

            # Look up the archetype in the target symbol table
            lookup = target_sym_tab.lookup(arch_refs[0])

            # Skip over local import name collisions
            if lookup and not isinstance(lookup.decl.name_of, uni.AstImplNeedingNode):
                lookup = (
                    target_sym_tab.parent_scope.lookup(arch_refs[0])
                    if target_sym_tab.parent_scope
                    else target_sym_tab.lookup(arch_refs[0])
                )

            decl_node = (
                self.defn_lookup(lookup)
                if len(arch_refs) == 1 and lookup
                else lookup.defn[-1] if lookup else None
            )
            name_of_links.append(decl_node) if decl_node else None

            for name in arch_refs[1:]:
                if decl_node:
                    lookup = (
                        decl_node.name_of.sym_tab.lookup(name, deep=False)
                        if decl_node.name_of.sym_tab
                        else None
                    )
                    decl_node = (
                        self.defn_lookup(lookup)
                        if len(arch_refs) == 1 and lookup
                        else lookup.defn[-1] if lookup else None
                    )
                    name_of_links.append(decl_node) if decl_node else None
                else:
                    break

            if not decl_node:
                # self.log_error(
                #     f"Implementation for '{sym.sym_name}' cannot be matched to any declaration.",
                #     sym.decl.name_of,
                # )
                continue
            elif isinstance(decl_node, uni.Ability) and decl_node.is_abstract:
                self.log_warning(
                    f"Abstract ability {decl_node.py_resolve_name()} should not have a definition.",
                    decl_node,
                )
                continue

            if not isinstance(
                valid_decl := decl_node.name_of, uni.AstImplNeedingNode
            ) or not (valid_decl.sym_tab and sym.decl.name_of.sym_tab):
                raise self.ice(
                    f"Expected AstImplNeedingNode, got {valid_decl.__class__.__name__}. Not possible."
                )

            # Ensure if it's an ability def impl, the parameters are matched.
            self.validate_params_match(sym, decl_node.name_of)

            valid_decl.body = sym.decl.name_of
            sym.decl.name_of.decl_link = valid_decl
            for idx, a in enumerate(sym.decl.name_of.target):
                if idx < len(name_of_links) and name_of_links[idx]:
                    a.name_spec.name_of = name_of_links[idx].name_of
                    a.name_spec.sym = name_of_links[idx].sym
            sym.decl.name_of.sym_tab.names_in_scope.update(
                valid_decl.sym_tab.names_in_scope
            )
            valid_decl.sym_tab.names_in_scope = sym.decl.name_of.sym_tab.names_in_scope

        # Process kid scopes recursively
        for source_scope in source_sym_tab.kid_scope:
            # If source and target are the same, process within the same scope
            if source_sym_tab is target_sym_tab:
                self.connect_impls(source_scope, source_scope)
            else:
                # Otherwise, try to find corresponding scopes by name
                for target_scope in target_sym_tab.kid_scope:
                    if source_scope.scope_name == target_scope.scope_name:
                        self.connect_impls(source_scope, target_scope)
                        break

    def validate_params_match(self, sym: Symbol, valid_decl: uni.AstSymbolNode) -> None:
        """Validate if the parameters match."""
        if (
            isinstance(valid_decl, uni.Ability)
            and isinstance(sym.decl.name_of, uni.ImplDef)
            and isinstance(valid_decl.signature, uni.FuncSignature)
            and isinstance(sym.decl.name_of.spec, uni.FuncSignature)
        ):

            params_decl = valid_decl.signature.params
            params_defn = sym.decl.name_of.spec.params

            if params_decl and params_defn:
                # Check if the parameter count is matched.
                if len(params_defn) != len(params_decl):
                    self.log_error(
                        f"Parameter count mismatch for ability {sym.sym_name}.",
                        sym.decl.name_of.name_spec,
                    )
                    self.log_error(
                        f"From the declaration of {valid_decl.name_spec.sym_name}.",
                        valid_decl.name_spec,
                    )
                else:
                    # Copy the parameter names from the declaration to the definition.
                    for idx in range(len(params_defn)):
                        if (par := params_decl[idx].parent) is not None:
                            loc_in_kid = par.kid.index(params_decl[idx])
                            par.kid[loc_in_kid] = params_defn[idx]
                        params_decl[idx] = params_defn[idx]

    def check_archetypes(self, ir_in: uni.Module) -> None:
        """Check all archetypes for issues with attributes and methods."""
        for node in ir_in.get_all_sub_nodes(uni.Archetype):
            self.check_archetype(node)

    def check_archetype(self, node: uni.Archetype) -> None:
        """Check a single archetype for issues."""
        if node.arch_type.name == Tok.KW_OBJECT and isinstance(node.body, Sequence):
            self.cur_node = node
            found_default_init = False
            for stmnt in node.body:
                if not isinstance(stmnt, uni.ArchHas):
                    continue
                for var in stmnt.vars:
                    if (var.value is not None) or (var.defer):
                        found_default_init = True
                    else:
                        if found_default_init:
                            self.log_error(
                                f"Non default attribute '{var.name.value}' follows default attribute",
                                node_override=var.name,
                            )
                            break

            post_init_vars: list[uni.HasVar] = []
            postinit_method: uni.Ability | None = None

            for item in node.body:

                if isinstance(item, uni.ArchHas):
                    for var in item.vars:
                        if var.defer:
                            post_init_vars.append(var)

                elif isinstance(item, uni.Ability):
                    if item.is_abstract:
                        continue
                    if (
                        isinstance(item.name_ref, uni.SpecialVarRef)
                        and item.name_ref.name == "KW_POST_INIT"
                    ):
                        postinit_method = item

            # Check if postinit needed and not provided.
            if len(post_init_vars) != 0 and (postinit_method is None):
                self.log_error(
                    'Missing "postinit" method required by un initialized attribute(s).',
                    node_override=post_init_vars[0].name_spec,
                )  # We show the error on the first uninitialized var.
