"""Core function to get the type of the expression."""
impl TypeEvaluator._get_type_of_expression_core(expr: uni.Expr) -> TypeBase {
    match expr {
        # ----------------------------------------------------------------------
        # Prefetched types: These types may not have prefetched and we need to
        # check if they are available, if the're not, we're inside builtins or
        # typeshed module itself and in that case we can just return unknown type.
        # ----------------------------------------------------------------------
        case uni.String() | uni.MultiString():
            if self.prefetch {
                return self._convert_to_instance(self.get_type_of_string(expr));
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
                # TODO: We can do some inference inside the list to get the element type.
                return self._convert_to_instance(self.prefetch.list_class);
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
                        return self._set_symbol_to_expr(expr.right, sym);
                    }
                    return types.UnknownType();
                } elif base_type.is_instantiable_class() {
                    assert isinstance(base_type, types.ClassType);
                    if member := self._lookup_class_member(base_type, expr.right.value) {
                        value = self._set_symbol_to_expr(expr.right, member.symbol);
                        if base_type.is_enum_class() {
                            # Because enum values are instances of the enum class,
                            # we need to return the enum class as an instance type.
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

                # if <expr> is a class type, the atom trailer will be the type params.
                if isinstance(base_type, types.ClassType)
                and base_type.is_instantiable_class() {
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
                                    if cls_.sym_category == uni.SymbolType.WALKER {
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

        case uni.TypeRef():
            ty = self.get_type_of_expression(expr.target);
            if isinstance(ty, types.ClassType) {
                return ty.clone_as_class();
            }

    }
    # TODO: More expressions.
    return types.UnknownType();
}

"""Return the declared type of the symbol."""
impl TypeEvaluator._get_type_of_symbol(symbol: uni.Symbol) -> TypeBase {
    node_ = symbol.decl.name_of;
    match node_ {
        case uni.Archetype() | uni.Enum():
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
            if node_.loc.mod_path == self._TYPING_STUB_FILE_PATH {
                match node_.sym_name {
                    case "Final":
                        return self.prefetch.final_class;

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
                # TODO: Ensure the iter_type is an Iterator[T].
                # The iter_tpe should be Iterator[T] and the return type should be T.
                if isinstance(iter_type, types.ClassType)
                and isinstance(collection_type, types.ClassType) {
                    if len(iter_type.private.type_args) == 1 {
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
    # If it's alreay "cached" return it.
    if node_.type is not None {
        return node_.type;
    }
    result = self._get_type_of_expression_core(node_);
    # If the context has an expected type, pyright does a compatibility and set
    # a diagnostics here, I don't understand why that might be necessary here.
    node_.type = result;  # Cache the result
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
    # self.prefetch.module_type_class =
    # self.prefetch.typed_dict_class =
    # self.prefetch.typed_dict_private_class =
    # self.prefetch.supports_keys_and_get_item_class =
    # self.prefetch.mapping_class =
    # self.prefetch.template_class =
    self.prefetch.protocol_class = get_typing_type("Protocol");
    self.prefetch.any_class = get_typing_type("Any");
    # Prefetched Jaclang builtin types
    self.prefetch.root_class = get_jac_builtin_type("Root");
    self.prefetch.root_class.shared.is_root_class = True;
    self.prefetch.final_class = get_jac_builtin_type("Final");
    self.prefetch.node_class = get_jac_builtin_type("Node");
    self.prefetch.walker_class = get_jac_builtin_type("Walker");
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
    self._prefetch_types();
}
# Cache the type, pyright is doing invalidateTypeCacheIfCanceled()
# we're not doing that any time sooner.
