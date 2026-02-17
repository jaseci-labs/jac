"""Core function to get the type of the expression."""
impl TypeEvaluator._get_type_of_expression_core(expr: uni.Expr) -> TypeBase {
    match expr {
        # ----------------------------------------------------------------------
        # Prefetched types: These types may not have prefetched and we need to
        # check if they are available, if the're not, we're inside builtins or
        # typeshed module itself and in that case we can just return unknown type.
        # ----------------------------------------------------------------------
        case uni.String() | uni.MultiString() | uni.FString():
            if self.prefetch {
                return self._convert_to_instance(self.prefetch.str_class);
            }

        case uni.Int():
            if self.prefetch {
                return self._convert_to_instance(self.get_type_of_int(expr));
            }

        case uni.Float():
            if self.prefetch {
                return self._convert_to_instance(self.get_type_of_float(expr));
            }

        case uni.Null():
            if self.prefetch and self.prefetch.none_type_class {
                return self._convert_to_instance(self.prefetch.none_type_class);
            }

        case uni.ListVal():
            if self.prefetch and self.prefetch.list_class {
                list_inst = self._convert_to_instance(self.prefetch.list_class);
                # Infer element type from the list literal's elements.
                if isinstance(list_inst, types.ClassType) and expr.values {
                    for _val in expr.values {
                        elem_type = self.get_type_of_expression(_val);
                        if isinstance(elem_type, types.ClassType) {
                            list_inst.private.type_args = [elem_type];
                            break;
                        }
                    }
                }
                return list_inst;
            }

        case uni.JsxElement():
            if self.prefetch and self.prefetch.jsx_element_class {
                return self._convert_to_instance(self.prefetch.jsx_element_class);
            }

        # TODO: Boolean literals.

        # ----------------------------------------------------------------------
        # End of prefetched types
        # ----------------------------------------------------------------------
        case uni.AtomTrailer():
            # NOTE: Pyright is using CFG to figure out the member type by narrowing the base
            # type and filtering the members. We're not doing that anytime sooner.
            base_type = self.get_type_of_expression(expr.target);

            if expr.is_attr {  # <expr>.member

                assert isinstance(expr.right, uni.Name);
                if isinstance(base_type, types.ModuleType) {
                    # getTypeOfMemberAccessWithBaseType()
                    if sym := type_utils.lookup_symtab(
                        base_type.symbol_table, expr.right.value, self.builtins_module
                    ) {
                        # Get the symbol's type first
                        sym_type = self.get_type_of_symbol(sym);
                        # Return prefetched special form type if both name and type match
                        if special_form := self._get_special_form_type(
                            sym.sym_name, sym_type
                        ) {
                            sym.add_use(expr.right);
                            expr.right.type = special_form;
                            return special_form;
                        }
                        # Not a special form, return the resolved type
                        sym.add_use(expr.right);
                        expr.right.type = sym_type;
                        return sym_type;
                    }
                    return types.UnknownType();
                } elif base_type.is_instantiable_class() {
                    assert isinstance(base_type, types.ClassType);
                    if member := self._lookup_class_member(base_type, expr.right.value) {
                        value = self._set_symbol_to_expr(expr.right, member.symbol);
                        # Handle direct enum member access (e.g., Color.RED)
                        if base_type.is_enum_class() {
                            member_name = expr.right.value;
                            # Return EnumMemberType for recognized enum members
                            if (
                                base_type.shared.enum_members
                                and member_name in base_type.shared.enum_members
                            ) {
                                member_info = base_type.shared.enum_members[
                                    member_name
                                ];
                                return types.EnumMemberType(
                                    enum_class=base_type,
                                    member_info=member_info,
                                    flags=types.TypeFlags.Instance
                                );
                            }
                            # Fallback for unrecognized enum members
                            return base_type.clone_as_instance();
                        }
                        return value;
                    }
                    return types.UnknownType();
                } elif base_type.is_class_instance() {
                    assert isinstance(base_type, types.ClassType);
                    if member := self._lookup_object_member(
                        base_type, expr.right.value
                    ) {
                        # For init method lookup: if the class is a data class and
                        # doesn't have an explicit init defined directly (not inherited),
                        # prefer the implicit dataclass init over inherited object.__init__.
                        # But only if the class or its ancestors have 'has' variables.
                        if (
                            expr.right.value in ('init', '__init__')
                            and base_type.is_data_class()
                        ) {
                            # Check if the class has explicit init in its own symbol table
                            has_explicit_init = (
                                'init' in base_type.shared.symbol_table.names_in_scope
                                or '__init__' in base_type.shared.symbol_table.names_in_scope
                            );
                            # Check if there are any 'has' vars in the class hierarchy
                            # (excluding object which has no has vars)
                            has_any_has_vars = any(
                                len(cls.shared.symbol_table.get_has_vars()) > 0
                                for cls in base_type.shared.mro
                                if cls.shared.class_name != "object"
                            );
                            # Only create implicit dataclass init if:
                            # 1. No explicit init in the class itself
                            # 2. There are 'has' vars somewhere in the hierarchy
                            if not has_explicit_init and has_any_has_vars {
                                implicit_init_type = self._create_dataclass_init_method(
                                    base_type
                                );
                                expr.right.type = implicit_init_type;
                                return implicit_init_type;
                            }
                        }
                        overloaded_ty: types.OverloadedType | None = None;
                        member_ty = self.get_type_of_symbol(member.symbol);
                        if isinstance(member_ty, types.FunctionType) {
                            member_ty = member_ty.specialize(base_type);
                            overloaded_fns: list[types.FunctionType] = [member_ty];
                            for overload in member.overloads {
                                overload_member_ty = self.get_type_of_symbol(overload);
                                if isinstance(overload_member_ty, types.FunctionType) {
                                    overload_member_ty = overload_member_ty.specialize(
                                        base_type
                                    );
                                    overloaded_fns.append(overload_member_ty);
                                }
                            }
                            if len(overloaded_fns) > 1 {
                                overloaded_ty = types.OverloadedType(
                                    overloads=overloaded_fns
                                );
                            }
                        }
                        # Check if this member is a property. If so, return the property's
                        # return type instead of the FunctionType.
                        if self._is_symbol_property(member.symbol) {
                            if overloaded_ty {
                                # For overloaded properties, use the return type from the first overload
                                # TODO: In the future, we might want to union the return types
                                if overloaded_ty.overloads
                                and len(overloaded_ty.overloads) > 0 {
                                    prop_return_type = overloaded_ty.overloads[0].return_type;
                                    if prop_return_type {
                                        member.symbol.add_use(expr.right);
                                        expr.right.type = prop_return_type;
                                        return expr.right.type;
                                    }
                                }
                            } elif isinstance(member_ty, types.FunctionType) {
                                prop_return_type = member_ty.return_type;
                                if prop_return_type {
                                    member.symbol.add_use(expr.right);
                                    expr.right.type = prop_return_type;
                                    return expr.right.type;
                                }
                            }
                        }
                        # NOTE: If this atom trailer is called `<atom_trailer>()` we can resolve
                        # which overload is being called based on the arguments, and update the type
                        # based on the call, maybe for future.
                        #
                        # This symbol.add_use is what makes the jump to definition work.
                        #
                        # expr_type = self._set_symbol_to_expr(expr.right, member.symbol);
                        member.symbol.add_use(expr.right);
                        expr.right.type = overloaded_ty or member_ty;
                        return expr.right.type;
                    }
                    # Fallback for implicit init method on data classes (classes with 'has' vars).
                    # When accessing .init on an instance and no explicit init is found,
                    # create an implicit init from the 'has' variables.
                    if (
                        expr.right.value in ('init', '__init__')
                        and base_type.is_data_class()
                    ) {
                        implicit_init_type = self._create_dataclass_init_method(
                            base_type
                        );
                        expr.right.type = implicit_init_type;
                        return implicit_init_type;
                    }
                    return types.UnknownType();
                } elif isinstance(base_type, types.EnumMemberType) {
                    # Handle member access on enum member instances (e.g., Color.RED.name, Color.RED.value)
                    member_name = expr.right.value;
                    enum_cls = base_type.enum_class;
                    # Access to .name or ._name_ returns string
                    if member_name in ('name', '_name_') {
                        return self._convert_to_instance(self.prefetch.str_class);
                    }
                    # Access to .value or ._value_ returns the member's value type
                    if member_name in ('value', '_value_') {
                        return self._convert_to_instance(base_type.get_value_type());
                    }
                    # Access to another enum member (e.g., Color.RED.BLUE)
                    if (
                        enum_cls.shared.enum_members
                        and member_name in enum_cls.shared.enum_members
                    ) {
                        return types.EnumMemberType(
                            enum_class=enum_cls,
                            member_info=enum_cls.shared.enum_members[member_name],
                            flags=types.TypeFlags.Instance
                        );
                    }
                    # Unknown member access
                    return types.UnknownType();
                }
            } elif expr.is_null_ok {
                # TODO:
                # <expr>?.member
            } elif isinstance(expr.right, uni.AssignCompr) {
                # base_type should be a sequence of [T].
                if not isinstance(base_type, types.ClassType) {
                    self.add_diagnostic(
                        expr,
                        f'Cannot perform assignment comprehension on type "{base_type}"',
                    );
                    return base_type;
                }
                # TODO: Ensure the base_type is a Sequence[T], for now I'm only checking
                # if it's a generic of T.
                if len(base_type.private.type_args) == 1 {
                    sequence_of = self._convert_to_instance(
                        base_type.private.type_args[0]
                    );
                    for assign in expr.right.assigns {
                        if assign.key is not None {
                            if member := self._lookup_object_member(
                                sequence_of, assign.key.sym_name
                            ) {
                                self._set_symbol_to_expr(assign.key, member.symbol);
                            } else {
                                self.add_diagnostic(
                                    assign.key,
                                    f'Member "{assign.key.sym_name}" not found on type "{sequence_of}"',
                                );
                            }
                            dest_type = self.get_type_of_expression(assign.key);
                            src_type = self.get_type_of_expression(assign.value);
                            if not self.assign_type(src_type, dest_type) {
                                self.add_diagnostic(
                                    assign.value,
                                    f'Type "{src_type}" is not assignable to type "{dest_type}"',
                                );
                            }
                        }
                    }
                }
                # Evaluate KW pair values.
                for assign in expr.right.assigns {
                    self.get_type_of_expression(assign.value);
                }
                return base_type;
            } else {  # <expr>[<expr>]

                # --- Handle Callable special form ---
                # Callable[[ArgTypes], ReturnType] creates a FunctionType, not a specialized class.
                # Similar to Pyright's handling in createSpecializedClassType() which checks
                # classType.priv.aliasName === 'Callable'.
                #
                # We check is_special_form("Callable") which looks at the alias_name stored
                # in the ClassType's private details. The alias_name is set when resolving
                # Name expressions that refer to typing module special forms.
                if (
                    isinstance(base_type, types.ClassType)
                    and base_type.is_special_form("Callable")
                ) {
                    # Extract type arguments for Callable
                    type_args_expr: uni.Expr | None = None;
                    if isinstance(expr.right, uni.IndexSlice) and expr.right.slices {
                        type_args_expr = expr.right.slices[0].start;
                    }
                    return self._create_callable_type(type_args_expr, expr);
                }
                # if <expr> is a class type, the atom trailer will be the type params.
                if isinstance(base_type, types.ClassType)
                and base_type.is_instantiable_class() {
                    # --- Handle other generic types ---
                    # Collect the type arguments.
                    type_args: list[types.TypeBase] = [];
                    if isinstance(expr.right, uni.IndexSlice) and expr.right.slices {
                        type_args_vals = expr.right.slices[0].start;
                        if isinstance(type_args_vals, uni.TupleVal) {
                            for val in type_args_vals.values {
                                type_arg_type = self.get_type_of_expression(val);
                                type_args.append(type_arg_type);
                            }
                        } else {
                            type_arg_type = self.get_type_of_expression(type_args_vals);
                            type_args.append(type_arg_type);
                        }
                    }
                    return base_type.specialize_generics(type_args);
                }
                # Case: <expr>[<expr>:<expr>] slice of the expression.
                if isinstance(expr.right, uni.IndexSlice) and expr.right.is_range {
                    # TODO: Validate the slice type arguments.
                    return self.get_type_of_expression(expr.target);
                }
                # Regular <expr>[<expr>] case, we need to call __getitem__()
                return self.get_type_of_magic_method_call(
                    base_type, "__getitem__", [expr.right], expr
                )
                or types.UnknownType();
            }

        case uni.AtomUnit():
            return self.get_type_of_expression(expr.value);

        case uni.FuncCall():
            return self.validate_call_args(expr);

        case uni.BinaryExpr():
            return operations.get_type_of_binary_operation(self, expr);

        case uni.UnaryExpr():
            if isinstance(expr.op, uni.Token) {
                if expr.op.name == Tok.NOT {
                    # `not x` -> bool (only when operand is resolved)
                    operand_type = self.get_type_of_expression(expr.operand);
                    if (
                        not isinstance(operand_type, types.UnknownType)
                        and self.prefetch
                        and self.prefetch.bool_class
                    ) {
                        return self._convert_to_instance(self.prefetch.bool_class);
                    }
                    return operand_type;
                }
                if expr.op.name in (Tok.MINUS, Tok.BW_NOT) {
                    # `-x`, `~x` -> type of operand
                    return self.get_type_of_expression(expr.operand);
                }
            }

        case uni.FilterCompr():
            if expr.f_type {
                filter_type = self.get_type_of_expression(expr.f_type);
                if isinstance(filter_type, types.ClassType) {
                    # Compute the MRO for the class.
                    # For each compare in the filter comprehension, set symbol to the right name.
                    for cmp in expr.compares {
                        if isinstance(cmp.left, uni.Name)
                        and (sym := filter_type.lookup_member_symbol(cmp.left.value)) {
                            self._set_symbol_to_expr(cmp.left, sym);
                        } else {
                            self.add_diagnostic(
                                cmp.left,
                                f'Member "{cmp.left.value}" not found on type "{filter_type}"',
                            );
                        }

                        left_type = self.get_type_of_expression(cmp.left);
                        right_type = self.get_type_of_expression(cmp.rights[0]);
                        # TODO: Check if those two types are comparable.
                        # if  not self.???(right_type, left_type) {
                        #     self.add_diagnostic(
                        #         cmp.right,
                        #         f'Type "{right_type}" is not comparable to type "{left_type}"',
                        #     );
                        # }
                    }
                }
            }

        case uni.Name() | uni.SpecialVarRef():
            if isinstance(expr, uni.SpecialVarRef) {
                if expr.name == Tok.KW_ROOT {
                    return self._get_type_of_root(expr);
                }
                # Handle "here" and "visitor" special name ref.
                if expr.name in (Tok.KW_HERE, Tok.KW_VISITOR) {
                    if (method := self._get_enclosing_method(expr)) {
                        if isinstance(method.signature, uni.EventSignature) {
                            if arch := method.signature.arch_tag_info {
                                type_arch_cls = self.get_type_of_expression(arch);
                                type_arch_inst = self._convert_to_instance(
                                    type_arch_cls
                                );
                                if isinstance(type_arch_cls, types.ClassType) {
                                    self._set_symbol_to_expr(
                                        expr, type_arch_inst.get_class_symbol()
                                    );
                                }
                                return type_arch_inst;
                            } else {
                                cls_: uni.Archetype | None = self._get_enclosing_class(
                                    expr
                                );
                                if cls_ {
                                    if cls_.sym_category == uni.SymbolType.WALKER_ARCH {
                                        self._set_symbol_to_expr(
                                            expr,
                                            self.prefetch.node_class.get_class_symbol(),
                                        );
                                    } elif cls_.sym_category == uni.SymbolType.NODE_ARCH {
                                        self._set_symbol_to_expr(
                                            expr,
                                            self.prefetch.walker_class.get_class_symbol(),
                                        );
                                    }
                                }
                            }
                        }
                    }
                }
            }

            # NOTE: For self's type pyright is getting the first parameter of a method and
            # the name can be anything not just self, however we don't have the first parameter
            # and self is a keyword, we need to do it in this way.
            if self._is_expr_self(expr) {
                return self._get_type_of_self(expr);
            }

            # Handle 'super' keyword - resolve to first parent class in MRO.
            if self._is_expr_super(expr) {
                return self._get_type_of_super(expr);
            }

            if scope := expr.find_parent_of_type(uni.UniScopeNode) {
                if symbol := type_utils.lookup_symtab(
                    scope, expr.value, self.builtins_module
                ) {
                    symbol = self.resolve_imported_symbols(symbol);
                    symbol.add_use(expr);
                    # Only set sym if not already set (preserves existing symbol info for declarations)
                    if expr.sym is None {
                        expr.sym = symbol;
                        # Link name_of to the declaration's AstSymbolNode for hover
                        if symbol.decl and symbol.decl.name_of {
                            expr.name_of = symbol.decl.name_of;
                        }
                    }
                    # Check for function overloads
                    symbol_type = self.get_type_of_symbol(symbol);
                    # --- Handle special forms from typing module ---
                    # When a Name refers to a special form (e.g., Callable), return
                    # the prefetched type which has alias_name set. This avoids creating
                    # new ClassType instances for every usage.
                    # Similar to Pyright's classType.priv.aliasName pattern.
                    if special_form := self._get_special_form_type(
                        symbol.sym_name, symbol_type
                    ) {
                        symbol_type = special_form;
                    }
                    # Consult CFG-based narrowing for flow-sensitive type.
                    # Narrowed types represent variable values, so ensure
                    # they are instance types (not instantiable class types).
                    if narrowed := self.get_narrowed_type(symbol, expr) {
                        if isinstance(narrowed, types.UnionType) {
                            symbol_type = types.UnionType(
                                types=[
                                    self._convert_to_instance(t)
                                    for t in narrowed.types
                                ]
                            );
                        } else {
                            symbol_type = self._convert_to_instance(narrowed);
                        }
                    }
                    if isinstance(symbol_type, types.FunctionType) {
                        overloaded_ty: types.OverloadedType | None = None;
                        overloaded_fns: list[types.FunctionType] = [symbol_type];
                        # Find the scope where the symbol is defined to check for overloads
                        symbol_scope: uni.UniScopeNode | None = symbol.parent_tab;
                        if symbol_scope is None {
                            # If parent_tab is None, try to find the scope from the declaration
                            if symbol.decl
                            and symbol.decl.find_parent_of_type(uni.UniScopeNode) {
                                symbol_scope = symbol.decl.find_parent_of_type(
                                    uni.UniScopeNode
                                );
                            }
                        }
                        # Check if there are overloads in the symbol's scope
                        if symbol_scope
                        and expr.value in symbol_scope.names_in_scope_overload {
                            for overload_symbol in symbol_scope.names_in_scope_overload[
                                expr.value
                            ] {
                                overload_type = self.get_type_of_symbol(
                                    overload_symbol
                                );
                                if isinstance(overload_type, types.FunctionType) {
                                    overloaded_fns.append(overload_type);
                                }
                            }
                        }
                        if len(overloaded_fns) > 1 {
                            overloaded_ty = types.OverloadedType(
                                overloads=overloaded_fns
                            );
                        }
                        return overloaded_ty or symbol_type;
                    }
                    return symbol_type;
                }
            }

    }
    # TODO: More expressions.
    return types.UnknownType();
}

"""Return the declared type of the symbol."""
impl TypeEvaluator._get_type_of_symbol(symbol: uni.Symbol) -> TypeBase {
    node_ = symbol.decl.name_of;
    match node_ {
        case uni.Enum():
            return self.get_type_of_enum(node_);

        case uni.Archetype():
            return self.get_type_of_class(node_);

        case uni.Ability():
            return self.get_type_of_ability(node_);

        case uni.ParamVar():
            if node_.type_tag {
                annotation_type = self.get_type_of_expression(node_.type_tag.tag);
                if node_.is_vararg {
                    # FIXME: *args are actually a tuple, not a list. But tuples are
                    # complicated to handle, so we'll use list for now. Will revisit this later.
                    param_type = self.prefetch.list_class.clone_as_instance();
                    param_type.private.type_args = [annotation_type];
                    return param_type;
                } elif node_.is_kwargs {
                    param_type = self.prefetch.dict_class.clone_as_instance();
                    param_type.private.type_args = [
                        self.prefetch.str_class,
                        annotation_type
                    ];
                    return param_type;
                }
                return self._convert_to_instance(annotation_type);
            }

        # This actually defined in the function getTypeForDeclaration();
        # Pyright has DeclarationType.Variable.
        case uni.Name():
            # ---- Handle SepcialForm in typing.pyi ----
            # NOTE: This is different from pyright, that does get the same logic in
            # getTypeOfAnnotation() which we don't have.
            if node_.loc.mod_path {
                node_mod_path = Path(node_.loc.mod_path).resolve();
                typing_stub_path = Path(self._TYPING_STUB_FILE_PATH).resolve();
                builtins_stub_path = Path(self._BUILTINS_STUB_FILE_PATH).resolve();
                if node_mod_path in (typing_stub_path, builtins_stub_path) {
                    match node_.sym_name {
                        case "Final":
                            return self.prefetch.final_class;

                        case "LiteralString":
                            return self.prefetch.literal_string_class;

                    }
                }
            }

            # ---- Handle tuple/list unpacking targets ----
            # When a Name is inside a TupleVal/ListVal that is the target
            # of an Assignment, infer its type from the RHS tuple element.
            if isinstance(node_.parent, (uni.TupleVal, uni.ListVal)) {
                unpack_container = node_.parent;
                unpack_assignment = unpack_container.parent;
                if (
                    isinstance(unpack_assignment, uni.Assignment)
                    and unpack_assignment.value is not None
                ) {
                    rhs_type = self.get_type_of_expression(unpack_assignment.value);
                    if isinstance(rhs_type, types.ClassType)
                    and rhs_type.private.type_args {
                        idx = -1;
                        for (vi, v) in enumerate(unpack_container.values) {
                            if v is node_ {
                                idx = vi;
                                break;
                            }
                        }
                        if idx >= 0 and idx < len(rhs_type.private.type_args) {
                            return self._convert_to_instance(
                                rhs_type.private.type_args[idx]
                            );
                        }
                    }
                }
            }

            # ---- Handle simple assignment: var = <expr> ----
            if isinstance(node_.parent, uni.Assignment) {
                if node_.parent.type_tag is not None {
                    annotation_type = self.get_type_of_expression(
                        node_.parent.type_tag.tag
                    );
                    return self._convert_to_instance(annotation_type);
                } else {  # Assignment without a type annotation.

                    if node_.parent.value is not None {
                        return self.get_type_of_expression(node_.parent.value);
                    }
                }
            }

            # ---- Handle member assignment: obj.attr = <expr> ----
            # Pyright handles this in getDeclInfoForNameNode()
            if (
                isinstance(node_.parent, uni.AtomTrailer)
                and node_.parent.parent
                and isinstance(node_.parent.parent, uni.Assignment)
            ) {
                # Member assignment with a type annotation: obj.member: <type> = <expr>
                if node_.parent.parent.type_tag is not None {
                    annotation_type = self.get_type_of_expression(
                        node_.parent.parent.type_tag.tag
                    );
                    return self._convert_to_instance(annotation_type);
                } else {
                    if node_.parent.parent.value is not None {
                        return self.get_type_of_expression(node_.parent.parent.value);
                    }
                }
            }

            # ---- Handle walrus assignment: (x := <expr>) ----
            if (
                isinstance(node_.parent, uni.BinaryExpr)
                and isinstance(node_.parent.op, uni.Token)
                and node_.parent.op.name == "WALRUS_EQ"
                and node_.parent.left is node_
            ) {
                # The left side of walrus gets the type from the right side
                return self.get_type_of_expression(node_.parent.right);
            }

            # ---- Handle member assignment: for <name> in <expr> ----
            if isinstance(node_.parent, uni.InForStmt) {
                collection_type = self.get_type_of_expression(node_.parent.collection);
                iter_type = self.get_type_of_magic_method_call(
                    collection_type, "__iter__", [], node_.parent,
                );
                if isinstance(iter_type, types.ClassType) {
                    if len(iter_type.private.type_args) == 1 {
                        elem_type = iter_type.private.type_args[0];
                        # If element type is already concrete (e.g. Iterator[int]
                        # from range.__iter__), use it directly.
                        if isinstance(elem_type, types.ClassType) {
                            return elem_type.clone_as_instance();
                        }
                        # Element type is a TypeVar — specialize using the
                        # collection's type args (e.g. list[int] -> [int]).
                        if isinstance(collection_type, types.ClassType)
                        and collection_type.private.type_args {
                            specialized = iter_type.specialize_generics(
                                collection_type.private.type_args
                            );
                            if len(specialized.private.type_args) == 1 {
                                iterable_type = specialized.private.type_args[0];
                                if isinstance(iterable_type, types.ClassType) {
                                    return iterable_type.clone_as_instance();
                                }
                            }
                        }
                    }
                }
                return types.UnknownType();
            }

            if isinstance(node_.parent, uni.ModulePath) {
                return self.get_type_of_module(node_.parent);
            }
            if isinstance(node_.parent, uni.ModuleItem) {
                return self.get_type_of_module_item(node_.parent);
            }

        case uni.HasVar():
            if node_.type_tag is not None {
                annotation_type = self.get_type_of_expression(node_.type_tag.tag);
                return self._convert_to_instance(annotation_type);
            } else {
                if node_.value is not None {
                    return self.get_type_of_expression(node_.value);
                }
            }

    }
    # TODO: Implement for functions, parameters, explicit type
    # annotations in assignment etc.
    return types.UnknownType();
}

"""
Assign a source function type to a destination callable type.

This handles Callable assignment compatibility following Python's typing rules:
- Callable[..., T] (gradual form) accepts any callable
- Parameter types are contravariant (dest params must be assignable to src params)
- Return types are covariant (src return must be assignable to dest return)
- Extra src params beyond dest count must have defaults (Pyright behavior)

Future work:
    - TypeVar handling for generic callables
    - ParamSpec support
"""
impl TypeEvaluator._assign_callable(
    src_func: types.FunctionType, dest_func: types.FunctionType
) -> bool {
    # If destination is gradual callable form (Callable[..., T]), any callable is compatible
    if dest_func.is_gradual_callable_form() {
        # Only need to check return type compatibility
        if dest_func.return_type and src_func.return_type {
            return self.assign_type(src_func.return_type, dest_func.return_type);
        }
        return True;
    }
    # If source is gradual callable form but dest is not, it's not assignable
    # (we can't guarantee the source accepts the required parameters)
    if src_func.is_gradual_callable_form() {
        return False;
    }
    # Get non-self/cls parameters for comparison
    src_params = [
        p
        for p in (src_func.parameters or [])
        if not p.is_self and not p.is_cls
    ];
    dest_params = [
        p
        for p in (dest_func.parameters or [])
        if not p.is_self and not p.is_cls
    ];
    # Count required dest parameters (those without default values)
    dest_required = len(
        [
            p
            for p in dest_params
            if p.default_value is None
        ]
    );
    # Source must have at least as many params as dest requires
    if len(src_params) < dest_required {
        return False;
    }
    # Check parameter compatibility (contravariant)
    for (i, dest_param) in enumerate(dest_params) {
        if i >= len(src_params) {
            # Dest has more params than src - extra dest params must have defaults
            if dest_param.default_value is None {
                return False;
            }
            continue;
        }

        src_param = src_params[i];

        # Skip type checking if either parameter has no type annotation
        if dest_param.param_type is None or src_param.param_type is None {
            continue;
        }

        # Contravariance: dest param type should be assignable to src param type
        if not self.assign_type(dest_param.param_type, src_param.param_type) {
            return False;
        }
    }
    # Check extra src params beyond dest count - they must have defaults
    # (Following Pyright: caller will only pass dest's param count, extras need defaults)
    if len(src_params) > len(dest_params) {
        for i in range(len(dest_params), len(src_params)) {
            src_param = src_params[i];
            if src_param.default_value is None {
                # Extra src param without default - incompatible
                return False;
            }
        }
    }
    # Check return type compatibility (covariant)
    if dest_func.return_type and src_func.return_type {
        if not self.assign_type(src_func.return_type, dest_func.return_type) {
            return False;
        }
    }
    return True;
}

"""Assign the source class type to the destination class type."""
impl TypeEvaluator._assign_class(
    src_type: types.ClassType, dest_type: types.ClassType
) -> bool {
    # If the type is Final[T], unwrap it to T.
    # TODO: We can actually check if the Final type is modified and
    # prevent that, but for now just unwrap it.
    if dest_type.shared == self.prefetch.final_class.shared {
        dest_type = dest_type.private.type_args[0];
    }
    if src_type.shared == self.prefetch.final_class.shared {
        src_type = src_type.private.type_args[0];
    }
    if src_type.shared == dest_type.shared {
        return True;
    }
    # Check if src class is a subclass of dest class.
    if self.is_sub_class(dest_type, src_type) {
        return True;
    }
    # Integers can be used where floats are expected.
    if src_type.is_builtin("int") and dest_type.is_builtin("float") {
        return True;
    }
    # Check if dest_type is a protocol and src_type implements it.
    for base_cls in dest_type.shared.base_classes {
        if not isinstance(base_cls, types.ClassType) or base_cls.shared is None {
            continue;
        }
        if base_cls.shared == self.prefetch.protocol_class.shared {
            if type_utils.class_implements_protocol(src_type, dest_type) {
                return True;
            }
            # TODO: The dest_class can have other base classes as well, do this
            # Recursively.
            break;
        }
    }
    return False;
}

impl TypeEvaluator.is_sub_class(
    super_cls: types.ClassType, sub_cls: types.ClassType
) -> bool {
    for cls in sub_cls.shared.mro {
        if cls.shared == super_cls.shared {
            return True;
        }
    }
    return False;
}

"""Return the effective return type of a magic method call."""
impl TypeEvaluator.get_type_of_magic_method_call(
    obj_type: TypeBase,
    method_name: str,
    arg_nodes: list[uni.Expr],
    node_for_error: uni.Expr | None = None,
) -> TypeBase | None {
    if obj_type.category == types.TypeCategory.Class {
        # TODO: getTypeOfBoundMember() <-- Implement this if needed, for the simple case
        # we'll directly call member lookup.
        #
        # WE'RE DAVIATING FROM PYRIGHT FOR THIS METHOD HEAVILY HOWEVER THIS CAN BE RE-WRITTEN IF NEEDED.
        #
        assert isinstance(obj_type, types.ClassType);  # <-- To make typecheck happy.
        if member := self._lookup_class_member(obj_type, method_name) {
            member_ty = self.get_type_of_symbol(member.symbol);
            # This list contains all functions including the overloads.
            overloaded_fns: list[types.FunctionType] = [];
            if isinstance(member_ty, types.FunctionType) {
                member_ty = member_ty.specialize(obj_type);
                overloaded_fns.append(member_ty);
                for overload in member.overloads {
                    overload_member_ty = self.get_type_of_symbol(overload);
                    if isinstance(overload_member_ty, types.FunctionType) {
                        overload_member_ty = overload_member_ty.specialize(obj_type);
                        overloaded_fns.append(overload_member_ty);
                    }
                }
                # Validate arguments for each overloaded function.
                for fn in overloaded_fns {
                    arg_param_match = self.match_args_to_params(
                        arg_nodes, node_for_error, fn, checking_overload=True
                    );
                    if not arg_param_match.argument_errors {
                        if self.validate_arg_types(
                            arg_param_match, checking_overload=True
                        ) {
                            return fn.return_type or types.UnknownType();
                        }
                    }
                }
                # If we reached here, none of the overloads matched.
                # Return None to allow fallback to reverse magic method (e.g., __radd__).
                return None;
            }
            # If we reached here, magic method is not a function.
            # 1. recursively check __call__() on the type, TODO
            # 2. if any or unknown, return getUnknownTypeForCallable() TODO
            # 3. return undefined.
            return None;
        }
    }
    return None;
}

"""Check if a type is Any, object, Unknown, or TypeVar."""
impl TypeEvaluator.is_any_type(ty: TypeBase) -> bool {
    # Check for UnknownType
    if isinstance(ty, types.UnknownType) {
        return True;
    }
    # Check for TypeVarType
    if isinstance(ty, types.TypeVarType) {
        return True;
    }
    # Check for object, Any, or TypeVar class types
    if isinstance(ty, types.ClassType) {
        if ty.is_builtin("object") {
            return True;
        }
        if (self.prefetch.any_class and ty.shared == self.prefetch.any_class.shared) {
            return True;
        }
        if (
            self.prefetch.type_var_class
            and ty.shared == self.prefetch.type_var_class.shared
        ) {
            return True;
        }
    }
    return False;
}

"""Assign the source type to the destination type."""
impl TypeEvaluator.assign_type(src_type: TypeBase, dest_type: TypeBase) -> bool {
    if src_type == dest_type {
        return True;
    }
    # LiteralString can be assigned to str.
    if self.prefetch and self.prefetch.literal_string_class {
        if isinstance(dest_type, types.ClassType)
        and isinstance(src_type, types.ClassType) {
            if dest_type.shared == self.prefetch.str_class.shared {
                if src_type.shared == self.prefetch.literal_string_class.shared {
                    return True;
                }
            }
        }
    }
    # Strict checking for JsxElement type - prevent non-JSX assignment to JsxElement
    if self.prefetch and self.prefetch.jsx_element_class {
        if isinstance(dest_type, types.ClassType)
        and isinstance(src_type, types.ClassType) {
            if dest_type.shared == self.prefetch.jsx_element_class.shared {
                # Destination is JsxElement - only allow JsxElement as source
                if src_type.shared != self.prefetch.jsx_element_class.shared {
                    return False;
                }
            }
        }
    }
    # --- Callable/FunctionType assignment compatibility ---
    # Handle assignment of functions to Callable types and vice versa.
    #
    # Handle bare Callable (special form without type args) - treat as gradual callable.
    # Bare `Callable` is equivalent to `Callable[..., Any]` in Python's typing system,
    # meaning any function/callable is assignable to it.
    # TODO : this is ad-hoc for now
    if (
        isinstance(dest_type, types.ClassType)
        and dest_type.is_special_form("Callable")
        and isinstance(src_type, types.FunctionType)
    ) {
        return True;
    }
    if isinstance(dest_type, types.FunctionType) {
        if isinstance(src_type, types.FunctionType) {
            return self._assign_callable(src_type, dest_type);
        }
        # OverloadedType can be assigned to Callable if any overload matches
        if isinstance(src_type, types.OverloadedType) and src_type.overloads {
            for overload in src_type.overloads {
                if self._assign_callable(overload, dest_type) {
                    return True;
                }
            }
            return False;
        }
        # Class with __call__ method can be assigned to Callable
        if isinstance(src_type, types.ClassType) and src_type.is_class_instance() {
            if call_member := self._lookup_object_member(src_type, "__call__") {
                call_type = self.get_type_of_symbol(call_member.symbol);
                if isinstance(call_type, types.FunctionType) {
                    return self._assign_callable(call_type, dest_type);
                }
            }
        }
    }
    # Source is FunctionType assigned to a different type
    if isinstance(src_type, types.FunctionType) {
        # Check if dest_type is a class with __call__ method (callable object)
        if isinstance(dest_type, types.ClassType) and dest_type.is_class_instance() {
            if call_member := self._lookup_object_member(dest_type, "__call__") {
                call_type = self.get_type_of_symbol(call_member.symbol);
                if isinstance(call_type, types.FunctionType) {
                    return self._assign_callable(src_type, call_type);
                }
            }
        }
    }
    # Everything is assignable to object, Any, Unknown, or TypeVar.
    if self.is_any_type(dest_type) or self.is_any_type(src_type) {
        return True;
    }
    # If destination is a union type, check if source is compatible with any of the
    # constituent types.
    if isinstance(dest_type, types.UnionType) {
        # TODO: pre mature optimization is the root of all evil.
        # If source is also union, we need to check if the source type args are subset of the dest type args.
        if isinstance(src_type, types.UnionType) {
            for src_type_arg in src_type.types {
                matched = False;
                src_type_inst = self._convert_to_instance(src_type_arg);
                for dest_type_arg in dest_type.types {
                    dest_type_inst = self._convert_to_instance(dest_type_arg);
                    if self.assign_type(src_type_inst, dest_type_inst) {
                        matched = True;
                        break;  # Break out of the inner loop.
                    }
                }
                # If we didn't find a match for this src_type_arg, return False.
                if not matched {
                    return False;
                }
            }
            # If we reached here, all src_type_args matched at least one dest_type_arg.
            return True;
        }
        for union_type in dest_type.types {
            new_dest_type = self._convert_to_instance(union_type);
            if self.assign_type(src_type, new_dest_type) {
                return True;
            }
        }
    }
    # Enum member assignment compatibility
    if isinstance(src_type, types.EnumMemberType) {
        # Enum member can assign to its enum class (Color.RED -> Color)
        if isinstance(dest_type, types.ClassType) and dest_type.is_enum_class() {
            if src_type.enum_class.shared == dest_type.shared {
                return True;
            }
        }
        # Enum members of same enum can assign to each other (Color.RED -> Color.BLUE)
        if isinstance(dest_type, types.EnumMemberType) {
            if src_type.enum_class.shared == dest_type.enum_class.shared {
                return True;
            }
        }
    }
    if dest_type.is_class_instance() and src_type.is_class_instance() {
        assert isinstance(dest_type, types.ClassType);
        assert isinstance(src_type, types.ClassType);
        return self._assign_class(src_type, dest_type);
    }
    return False;
}

"""Return the effective type of the expression."""
impl TypeEvaluator.get_type_of_expression(node_: uni.Expr) -> TypeBase {
    # To support JS style IIFE, abilities should be treated as expressions.
    if isinstance(node_, uni.Ability) {
        return self.get_type_of_ability(node_);
    }
    if node_.type is not None {
        return node_.type;
    }
    result = self._get_type_of_expression_core(node_);
    # If the context has an expected type, pyright does a compatibility and set
    # a diagnostics here, I don't understand why that might be necessary here.
    node_.type = result;
    return result;
}

"""Pop a symbol from the resolution stack."""
impl TypeEvaluator.pop_symbol_resolution(symbol: uni.Symbol) -> bool {
    popped_entry = self.symbol_resolution_stack.pop();
    assert popped_entry.symbol == symbol;
    return popped_entry.is_result_valid;
}

"""
Push a symbol onto the resolution stack.

Return False if recursion detected and in that case it won't push the symbol.
"""
impl TypeEvaluator.push_symbol_resolution(symbol: uni.Symbol) -> bool {
    idx = self.get_index_of_symbol_resolution(symbol);
    if idx is not None {
        # Mark all of the entries between these two as invalid.
        for i in range(idx, len(self.symbol_resolution_stack)) {
            entry_ = self.symbol_resolution_stack[i];
            entry_.is_result_valid = False;
        }
        return False;
    }
    self.symbol_resolution_stack.append(SymbolResolutionStackEntry(symbol=symbol));
    return True;
}

"""Get the index of a symbol in the resolution stack."""
impl TypeEvaluator.get_index_of_symbol_resolution(symbol: uni.Symbol) -> int | None {
    for (i, entry_) in enumerate(self.symbol_resolution_stack) {
        if entry_.symbol == symbol {
            return i;
        }
    }
    return None;
}

"""Return the prefetched types for the type evaluator."""
impl TypeEvaluator._prefetch_types{
    get_types_type = lambda type_name: str  -> types.TypeBase :
        self._get_type_from_module(self.types_module, type_name);
    get_typing_type = lambda type_name: str  -> types.TypeBase :
        self._get_type_from_module(self.typing_module, type_name);
    get_builtin_type = lambda type_name: str  -> types.TypeBase :
        self._get_type_from_module(self.builtins_module, type_name);
    get_jac_builtin_type = lambda type_name: str  -> types.TypeBase :
        self._get_type_from_module(self.jac_builtins_module, type_name);
    # TODO: Pyright first try load NoneType from typeshed and if it cannot
    # then it set to unknown type.
    self.prefetch.none_type_class = get_types_type("NoneType");
    self.prefetch.object_class = get_builtin_type("object");
    self.prefetch.type_class = get_builtin_type("type");
    self.prefetch.classmethod_class = get_builtin_type("classmethod");
    self.prefetch.union_type_class = get_types_type("UnionType");
    # self.prefetch.awaitable_class =
    # self.prefetch.function_class =
    # self.prefetch.method_class =
    self.prefetch.tuple_class = get_builtin_type("tuple");
    self.prefetch.bool_class = get_builtin_type("bool");
    self.prefetch.int_class = get_builtin_type("int");
    self.prefetch.float_class = get_builtin_type("float");
    self.prefetch.str_class = get_builtin_type("str");
    self.prefetch.dict_class = get_builtin_type("dict");
    self.prefetch.list_class = get_builtin_type("list");
    self.prefetch.enum_class = get_builtin_type("Enum");
    self.prefetch.protocol_class = get_typing_type("Protocol");
    self.prefetch.any_class = get_typing_type("Any");
    # Prefetch Callable and set alias_name. This single instance is reused
    # for all Callable references, avoiding repeated ClassType creation.
    # Similar to Pyright's classType.priv.aliasName pattern.
    self.prefetch.callable_class = get_typing_type("Callable");
    if isinstance(self.prefetch.callable_class, types.ClassType) {
        self.prefetch.callable_class.private.alias_name = "Callable";
    }
    # Prefetched Jaclang builtin types
    self.prefetch.root_class = get_jac_builtin_type("Root");
    self.prefetch.root_class.shared.is_root_class = True;
    self.prefetch.final_class = get_jac_builtin_type("Final");
    self.prefetch.literal_string_class = get_jac_builtin_type("LiteralString");
    self.prefetch.node_class = get_jac_builtin_type("Node");
    self.prefetch.walker_class = get_jac_builtin_type("Walker");
    self.prefetch.jsx_element_class = get_jac_builtin_type("JsxElement");
}

"""Load and return builtins stub module."""
impl TypeEvaluator._load_stub_module(path: str) -> uni.Module {
    if not os.path.exists(path) {
        raise FileNotFoundError(f"Stub file not found at {path}") ;
    }
    file_content = read_file_with_encoding(path);
    uni_source = uni.Source(file_content, path);
    mod = PyastBuildPass(
        ir_in=uni.PythonModuleAst(py_ast.parse(file_content), orig_src=uni_source,),
        prog=self.program,
    ).ir_out;
    SymTabBuildPass(ir_in=mod, prog=self.program);
    self.program.mod.hub[path] = mod;
    return mod;
}

"""Initialize the type evaluator with prefetched types.

Implementation Note:
--------------------
Pyright is prefetching the builtins when an evaluation is requested
on a node and from that node it does lookup for the builtins scope
and does the prefetch once, however if we forgot to call prefetch
in some place then it will not be available in the evaluator, So we
are prefetching the builtins at the constructor level once.
"""
impl TypeEvaluator.init(program: "JacProgram") -> None {
    # Initialize constants that have defaults in the class definition
    self._BUILTINS_STUB_FILE_PATH: str = os.path.join(
        os.path.dirname(__file__), "../../vendor/typeshed/stdlib/builtins.pyi"
    );
    self._TYPING_STUB_FILE_PATH: str = os.path.join(
        os.path.dirname(__file__), "../../vendor/typeshed/stdlib/typing.pyi"
    );
    self._TYPES_STUB_FILE_PATH: str = os.path.join(
        os.path.dirname(__file__), "../../vendor/typeshed/stdlib/types.pyi"
    );
    self._JAC_BUILTINS_STUB_FILE_PATH: str = os.path.join(
        os.path.dirname(__file__), "jac_builtins.pyi"
    );
    self._SPECIAL_FORM_CLASS_NAMES: tuple[(str, ...)] = (
        "Union",
        "Protocol",
        "Callable",
        "Type",
        "NoReturn",
        "ClassVar",
        "Optional",
        "Tuple",
        "Final",
        "Literal",
        "TypedDict"
    );
    self.program = program;
    self.symbol_resolution_stack: list[SymbolResolutionStackEntry] = [];
    self.prefetch: PrefetchedTypes = PrefetchedTypes();
    self.diagnostic_callback: DiagnosticCallback | None = None;
    self.builtins_module: uni.Module | None = None;
    # CFG-based type narrowing cache: (id(stmt_node), sym_name) -> narrowed_type.
    self._narrowing_cache: dict[tuple, types.TypeBase | None] = {};
    # Cache for module types by resolved path to avoid redundant lookups.
    self._module_type_cache: dict[str, types.ModuleType] = {};
    # NOTE: The initialization order here is important.
    self.typing_module = self._load_stub_module(self._TYPING_STUB_FILE_PATH);
    self.types_module = self._load_stub_module(self._TYPES_STUB_FILE_PATH);
    # These prefetch type are essential for the builtin types.
    self.prefetch.type_var_class = self._get_type_from_module(
        self.typing_module, "TypeVar"
    );
    self.builtins_module = self._load_stub_module(self._BUILTINS_STUB_FILE_PATH);
    self.jac_builtins_module = self._load_stub_module(
        self._JAC_BUILTINS_STUB_FILE_PATH
    );
    # This avoids parent_scope chaining which can cause recursion issues
    for (name, sym) in self.jac_builtins_module.names_in_scope.items() {
        if name not in self.builtins_module.names_in_scope {
            self.builtins_module.names_in_scope[name] = sym;
        }
    }
    self._prefetch_types();
}
# Cache the type, pyright is doing invalidateTypeCacheIfCanceled()
# we're not doing that any time sooner.

# -------------------------------------------------------------------------
# Type narrowing support (CFG-based, flow-sensitive)
# -------------------------------------------------------------------------
"""Entry point: get the CFG-based narrowed type for a symbol at a given AST node."""
impl TypeEvaluator.get_narrowed_type(
    symbol: uni.Symbol, at_node: uni.UniNode
) -> TypeBase | None {
    # Find the enclosing CodeBlockStmt (CFG node) for this Name node.
    stmt: uni.CodeBlockStmt | None = None;
    if isinstance(at_node, uni.CodeBlockStmt) {
        stmt = at_node;
    } else {
        stmt = at_node.find_parent_of_type(uni.CodeBlockStmt);
    }
    if stmt is None {
        return None;
    }
    return self._compute_narrowed_at(symbol, stmt, set());
}

"""Demand-driven backward CFG walk to compute narrowed type at a statement."""
impl TypeEvaluator._compute_narrowed_at(
    symbol: uni.Symbol, stmt: uni.UniCFGNode, visited: set
) -> TypeBase | None {
    cache_key = (id(stmt), symbol.sym_name);
    if cache_key in self._narrowing_cache {
        return self._narrowing_cache[cache_key];
    }
    stmt_id = id(stmt);
    if stmt_id in visited {
        return None;  # Cycle (back-edge in loop) -- conservative

    }
    visited.add(stmt_id);
    if not stmt.bb_in {
        self._narrowing_cache[cache_key] = None;
        return None;
    }
    incoming_types: list[TypeBase] = [];
    has_unnarrowed_pred: bool = False;
    for pred in stmt.bb_in {
        if pred is stmt {
            has_unnarrowed_pred = True;
            continue;
        }
        # Recursively get predecessor's narrowed type.
        pred_narrowed = self._compute_narrowed_at(symbol, pred, visited);

        # Check if predecessor is a conditional with a narrowing predicate.
        if isinstance(pred, uni.IfStmt) {
            predicate = self._find_predicate_for(symbol, pred.condition);
            if predicate is not None {
                edge_kind = self._classify_edge(pred, stmt);
                if edge_kind == "true" {
                    narrowed = self._apply_narrowing(
                        predicate, pred_narrowed, True, symbol
                    );
                    if narrowed is not None {
                        incoming_types.append(narrowed);
                    } else {
                        has_unnarrowed_pred = True;
                    }
                    continue;
                } elif edge_kind == "false" {
                    narrowed = self._apply_narrowing(
                        predicate, pred_narrowed, False, symbol
                    );
                    if narrowed is not None {
                        incoming_types.append(narrowed);
                    } else {
                        has_unnarrowed_pred = True;
                    }
                    continue;
                }
            }
        }
        # No narrowing from this predecessor; propagate its type.
        if pred_narrowed is not None {
            incoming_types.append(pred_narrowed);
        } else {
            has_unnarrowed_pred = True;
        }
    }
    # Merge incoming types.
    result: TypeBase | None = None;
    if len(incoming_types) == 0 {
        result = None;
    } elif has_unnarrowed_pred {
        # Some predecessor has no narrowing -- widen to declared type.
        result = None;
    } elif len(incoming_types) == 1 {
        result = incoming_types[0];
    } else {
        result = self._union_narrowed_types(incoming_types);
    }
    self._narrowing_cache[cache_key] = result;
    visited.discard(stmt_id);
    return result;
}

"""Classify a CFG edge from an IfStmt predecessor to a successor as true/false."""
impl TypeEvaluator._classify_edge(pred: uni.IfStmt, succ: uni.UniCFGNode) -> str {
    # True branch: succ is the first statement in pred.body.
    if pred.body and succ is pred.body[0] {
        return "true";
    }
    # False branch: ElseIf (which IS a CodeBlockStmt/UniCFGNode).
    if isinstance(pred.else_body, uni.ElseIf) and succ is pred.else_body {
        return "false";
    }
    # False branch: ElseStmt (NOT a CFG node) -- edge goes to its body[0].
    if isinstance(pred.else_body, uni.ElseStmt) {
        if pred.else_body.body and succ is pred.else_body.body[0] {
            return "false";
        }
    }
    # False branch: no else_body (fall-through to next sibling).
    if pred.else_body is None and succ not in pred.body {
        return "false";
    }
    return "unconditional";
}

"""Find a narrowing predicate for a specific symbol in a condition expression.

Supports the following patterns (Pyright-compatible):
- isinstance(x, T) / isinstance(x, (A, B, C))
- x is None / x is not None
- not <condition> (inverts inner predicate)
- <cond1> and <cond2> (returns first matching predicate)
- <cond1> or <cond2> (unions all positive isinstance predicates)
- (parenthesized_condition) (unwraps AtomUnit)
- if x: (truthiness - excludes None/falsy)
- x == literal / x != literal (literal equality)
"""
impl TypeEvaluator._find_predicate_for(
    symbol: uni.Symbol, condition: uni.Expr
) -> NarrowingPredicate | None {
    import from jaclang.compiler.type_system.type_evaluator { NarrowingPredicate }
    sym_name = symbol.sym_name;
    # Pattern 0: Unwrap parenthesized expressions (AtomUnit)
    # Handles: (isinstance(x, T)), ((x is None)), etc.
    if isinstance(condition, uni.AtomUnit) and isinstance(condition.value, uni.Expr) {
        return self._find_predicate_for(symbol, condition.value);
    }
    # Pattern 1: NOT handling (UnaryExpr with NOT operator)
    # Handles: not isinstance(x, T), not (x is None), etc.
    if (
        isinstance(condition, uni.UnaryExpr)
        and isinstance(condition.op, uni.Token)
        and condition.op.name == Tok.NOT
    ) {
        inner_pred = self._find_predicate_for(symbol, condition.operand);
        if inner_pred is not None {
            return NarrowingPredicate(
                sym_name=inner_pred.sym_name,
                narrow_type=inner_pred.narrow_type,
                is_inverted=not inner_pred.is_inverted
            );
        }
        return None;
    }
    # Patterns 2-3: Handle AND, OR via match statement
    if isinstance(condition, uni.BoolExpr) {
        match condition.op.name {
            # Pattern 2: Compound AND (BoolExpr with KW_AND)
            # Handles: isinstance(x, A) and isinstance(x, B)
            # Returns the first matching predicate for the symbol
            case Tok.KW_AND:
                for val in condition.values {
                    pred = self._find_predicate_for(symbol, val);
                    if pred is not None {
                        return pred;
                    }
                }
                return None;

            # Pattern 3: Compound OR (BoolExpr with KW_OR)
            # Handles: isinstance(x, A) | isinstance(x, B) -> narrows to A | B
            # Note: In Jac, boolean OR is expressed with '|' (KW_OR), not 'or'
            # Only works when all branches are positive isinstance checks
            case Tok.KW_OR:
                narrowed_types: list[types.TypeBase] = [];
                for val in condition.values {
                    pred = self._find_predicate_for(symbol, val);
                    if pred is None or pred.is_inverted {
                        # Can't narrow OR if any branch is negative or unknown
                        return None;
                    }
                    narrowed_types.append(pred.narrow_type);
                }
                if len(narrowed_types) > 0 {
                    if len(narrowed_types) == 1 {
                        union_type = narrowed_types[0];
                    } else {
                        union_type = types.UnionType(types=narrowed_types);
                    }
                    return NarrowingPredicate(
                        sym_name=sym_name, narrow_type=union_type, is_inverted=False
                    );
                }
                return None;

        }
    }
    # Pattern 4: isinstance(x, T) or isinstance(x, (A, B, C))
    if (
        isinstance(condition, uni.FuncCall)
        and isinstance(condition.target, uni.Name)
        and condition.target.value == "isinstance"
        and len(condition.params) == 2
        and isinstance(condition.params[0], uni.Name)
        and not isinstance(condition.params[0], uni.KWPair)
        and not isinstance(condition.params[1], uni.KWPair)
    ) {
        if condition.params[0].value == sym_name {
            type_arg = condition.params[1];
            # Check if it's a tuple of types: isinstance(x, (A, B, C))
            if isinstance(type_arg, uni.TupleVal) {
                type_list: list[types.TypeBase] = [];
                for type_expr in type_arg.values {
                    if not isinstance(type_expr, uni.KWPair) {
                        t = self.get_type_of_expression(type_expr);
                        t_inst = self._convert_to_instance(t);
                        type_list.append(t_inst);
                    }
                }
                if len(type_list) > 0 {
                    if len(type_list) == 1 {
                        isinstance_inst = type_list[0];
                    } else {
                        isinstance_inst = types.UnionType(types=type_list);
                    }
                    return NarrowingPredicate(
                        sym_name=sym_name,
                        narrow_type=isinstance_inst,
                        is_inverted=False
                    );
                }
            } else {
                # Single type: isinstance(x, T)
                isinstance_type = self.get_type_of_expression(type_arg);
                isinstance_inst = self._convert_to_instance(isinstance_type);
                return NarrowingPredicate(
                    sym_name=sym_name, narrow_type=isinstance_inst, is_inverted=False
                );
            }
        }
    }
    # Pattern 5: x is None / x is not None
    if (
        isinstance(condition, uni.CompareExpr)
        and len(condition.ops) == 1
        and len(condition.rights) == 1
        and isinstance(condition.left, uni.Name)
        and isinstance(condition.rights[0], uni.Null)
    ) {
        if condition.left.value == sym_name {
            op_name = condition.ops[0].name;
            if self.prefetch and self.prefetch.none_type_class {
                none_inst = self._convert_to_instance(self.prefetch.none_type_class);
                if op_name == Tok.KW_IS {
                    return NarrowingPredicate(
                        sym_name=sym_name, narrow_type=none_inst, is_inverted=False
                    );
                } elif op_name == Tok.KW_ISN {
                    return NarrowingPredicate(
                        sym_name=sym_name, narrow_type=none_inst, is_inverted=True
                    );
                }
            }
        }
    }
    # Pattern 6: x == literal / x != literal (literal equality narrowing)
    if (
        isinstance(condition, uni.CompareExpr)
        and len(condition.ops) == 1
        and len(condition.rights) == 1
        and isinstance(condition.left, uni.Name)
    ) {
        if condition.left.value == sym_name {
            op_name = condition.ops[0].name;
            right_expr = condition.rights[0];
            # Check for literal values (String, Int, Float, Bool, etc.)
            if isinstance(right_expr, (uni.String, uni.Int, uni.Float, uni.Bool)) {
                literal_type = self.get_type_of_expression(right_expr);
                if op_name == Tok.EE {  # ==

                    return NarrowingPredicate(
                        sym_name=sym_name, narrow_type=literal_type, is_inverted=False
                    );
                } elif op_name == Tok.NE {  # !=

                    return NarrowingPredicate(
                        sym_name=sym_name, narrow_type=literal_type, is_inverted=True
                    );
                }
            }
        }
    }
    # Pattern 7: Truthiness narrowing - if x: (where x is a Name)
    # This excludes None from the type when the condition is truthy
    if isinstance(condition, uni.Name) and condition.value == sym_name {
        if self.prefetch and self.prefetch.none_type_class {
            none_inst = self._convert_to_instance(self.prefetch.none_type_class);
            return NarrowingPredicate(
                sym_name=sym_name, narrow_type=none_inst, is_inverted=True
            );
        }
    }
    return None;
}

"""Apply a narrowing predicate to compute a narrowed type.

For positive narrowing (isinstance true branch), this method is inheritance-aware:
- If base type is `A | B | C` and we check `isinstance(x, T)`,
  the result includes all types that are subclasses of T.
- Example: `isinstance(x, int)` with `x: str | IndexSlice | int | None`
  narrows to `IndexSlice | int` (all int subclasses).
"""
impl TypeEvaluator._apply_narrowing(
    predicate: NarrowingPredicate,
    incoming: TypeBase | None,
    is_true_branch: bool,
    symbol: uni.Symbol
) -> TypeBase | None {
    import from jaclang.compiler.type_system.type_evaluator { NarrowingPredicate }
    # Determine if this is positive (narrow to type) or negative (exclude type).
    is_positive: bool = (
        is_true_branch if not predicate.is_inverted else not is_true_branch
    );
    if is_positive {
        # Get the base type to filter
        base_type: TypeBase;
        if incoming is not None {
            base_type = incoming;
        } else {
            base_type = self.get_type_of_symbol(symbol);
        }
        # Filter the base union to only include types that are subclasses
        # of the narrow_type (inheritance-aware isinstance narrowing)
        filtered = self._filter_union_for_isinstance(base_type, predicate.narrow_type);
        if filtered is not None {
            return filtered;
        }
        # Fallback: return the narrow_type directly
        return predicate.narrow_type;
    } else {
        # Negative narrowing: exclude narrow_type from the base type.
        base_type: TypeBase;
        if incoming is not None {
            base_type = incoming;
        } else {
            base_type = self.get_type_of_symbol(symbol);
        }
        return self.exclude_type_from_union(base_type, predicate.narrow_type);
    }
}

"""Filter a union type to only include types that pass isinstance(x, target_type).

Returns types from the union that are:
1. The same as target_type
2. Subclasses of target_type
3. Types where target_type is a subclass (for contravariant checks)
"""
impl TypeEvaluator._filter_union_for_isinstance(
    base_type: TypeBase, target_type: TypeBase
) -> TypeBase | None {
    # Collect matching types from the base union
    matching: list[TypeBase] = [];
    # Handle base_type being a union
    if isinstance(base_type, types.UnionType) and base_type.types {
        for t in base_type.types {
            if self._type_matches_isinstance(t, target_type) {
                matching.append(t);
            }
        }
    } else {
        # Single type
        if self._type_matches_isinstance(base_type, target_type) {
            matching.append(base_type);
        }
    }
    if len(matching) == 0 {
        return None;
    } elif len(matching) == 1 {
        return matching[0];
    } else {
        return types.UnionType(types=matching);
    }
}

"""Check if a type matches an isinstance check against target_type.

Returns True if:
1. t is the same class as target_type
2. t is a subclass of target_type
"""
impl TypeEvaluator._type_matches_isinstance(t: TypeBase, target_type: TypeBase) -> bool {
    # Handle target_type being a union (isinstance(x, (A, B)))
    if isinstance(target_type, types.UnionType) and target_type.types {
        for target_t in target_type.types {
            if self._type_matches_isinstance(t, target_t) {
                return True;
            }
        }
        return False;
    }
    # Both must be ClassTypes for subclass checking
    if isinstance(t, types.ClassType) and isinstance(target_type, types.ClassType) {
        # Same class?
        if t.shared is not None and target_type.shared is not None {
            if t.shared == target_type.shared {
                return True;
            }
        }
        # Is t a subclass of target_type?
        if self.is_sub_class(target_type, t) {
            return True;
        }
    }
    return False;
}

"""Union multiple narrowed types at a join point."""
impl TypeEvaluator._union_narrowed_types(types_list: list) -> TypeBase {
    if len(types_list) == 0 {
        return types.NeverType();
    }
    if len(types_list) == 1 {
        return types_list[0];
    }
    # Flatten any UnionTypes.
    flat: list[TypeBase] = [];
    for t in types_list {
        if isinstance(t, types.UnionType) and t.types {
            flat.extend(t.types);
        } else {
            flat.append(t);
        }
    }
    # Deduplicate by ClassType.shared identity.
    unique: list[TypeBase] = [];
    seen_shared: set = set();
    for t in flat {
        if isinstance(t, types.ClassType) and t.shared is not None {
            shared_id = id(t.shared);
            if shared_id not in seen_shared {
                seen_shared.add(shared_id);
                unique.append(t);
            }
        } else {
            unique.append(t);
        }
    }
    if len(unique) == 1 {
        return unique[0];
    }
    return types.UnionType(types=unique);
}

"""Exclude a type from a union, returning the remaining type(s).

Handles:
- Excluding a single ClassType from a UnionType
- Excluding a UnionType from another UnionType (excludes all types in the union)
"""
impl TypeEvaluator.exclude_type_from_union(
    original: TypeBase, to_exclude: TypeBase
) -> TypeBase {
    if isinstance(original, types.UnionType) and original.types {
        # Build a set of shared IDs to exclude
        exclude_shareds: set = set();
        if isinstance(to_exclude, types.UnionType) and to_exclude.types {
            for excl_t in to_exclude.types {
                if isinstance(excl_t, types.ClassType) and excl_t.shared is not None {
                    exclude_shareds.add(id(excl_t.shared));
                }
            }
        } elif isinstance(to_exclude, types.ClassType)
        and to_exclude.shared is not None {
            exclude_shareds.add(id(to_exclude.shared));
        }
        remaining: list[TypeBase] = [];
        for t in original.types {
            if isinstance(t, types.ClassType) and t.shared is not None {
                if id(t.shared) in exclude_shareds {
                    continue;
                }
            }
            remaining.append(t);
        }
        if len(remaining) == 0 {
            return types.NeverType();
        } elif len(remaining) == 1 {
            return remaining[0];
        } else {
            return types.UnionType(types=remaining);
        }
    }
    return original;
}
