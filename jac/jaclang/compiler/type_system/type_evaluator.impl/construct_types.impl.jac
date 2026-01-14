"""Return the effective type of root."""
impl TypeEvaluator._get_type_of_root(node_: uni.SpecialVarRef) -> TypeBase {
    node_.sym = self.prefetch.root_class.get_class_symbol();
    node_.type = self.prefetch.root_class.clone_as_instance();
    return node_.type;
}

"""Return the effective type of self."""
impl TypeEvaluator._get_type_of_self(node_: uni.SpecialVarRef) -> TypeBase {
    if method := self._get_enclosing_method(node_) {
        cls = method.method_owner;
        if isinstance(cls, uni.Archetype) {
            node_.sym = type_utils.lookup_symtab(
                method, node_.value, self.builtins_module
            );
            node_.type = self.get_type_of_class(cls).clone_as_instance();
            return node_.type;
        }
        if isinstance(cls, uni.Enum) {
            # TODO: Implement type from enum.
        }
    }
    return types.UnknownType();
}

"""Return the effective type of the float."""
impl TypeEvaluator.get_type_of_float(node: uni.Float) -> TypeBase {
    assert self.prefetch.float_class is not None;
    return self.prefetch.float_class;
}

"""Return the effective type of the int."""
impl TypeEvaluator.get_type_of_int(node: uni.Int) -> TypeBase {
    assert self.prefetch.int_class is not None;
    return self.prefetch.int_class;
}

"""Return the effective type of the string."""
impl TypeEvaluator.get_type_of_string(node: uni.String | uni.MultiString) -> TypeBase {
    # FIXME: Strings are a type of LiteralString type:
    # "foo" is not `str` but Literal["foo"], however for now we'll
    # not considering that and make it work and will implement that
    # later.
    #
    # see: getTypeOfString() in pyright (it requires parsing the sub
    # file of the typing module).
    assert self.prefetch.str_class is not None;
    return self.prefetch.str_class;
}

"""Return the effective type of an ability."""
impl TypeEvaluator.get_type_of_ability(node_: uni.Ability) -> TypeBase {
    if node_.name_spec.type is not None {
        return node_.name_spec.type;
    }
    if not isinstance(node_.signature, uni.FuncSignature) {
        func_type = types.FunctionType(
            func_name=node_.name_spec.sym_name,
            return_type=types.UnknownType(),
            parameters=None,
        );
        node_.name_spec.type = func_type;
        return node_.name_spec.type;
    }
    return_type: TypeBase = types.UnknownType();
    if isinstance(node_.signature.return_type, uni.Expr) {
        return_type = self._convert_to_instance(
            self.get_type_of_expression(node_.signature.return_type)
        );
    } else {
        if self.prefetch and self.prefetch.none_type_class {
            return_type = self._convert_to_instance(self.prefetch.none_type_class);
        }
    }
    # Define helper function for parameter conversion.
    def _get_param_category(param: uni.ParamVar) -> types.ParameterCategory {
        if param.is_vararg {
            return types.ParameterCategory.ArgsList;
        }
        if param.is_kwargs {
            return types.ParameterCategory.KwargsDict;
        }
        return types.ParameterCategory.Positional;
    }
    # Define helper function for parameter kind conversion.
    def _convert_param_kind(kind: uni.ParamKind) -> types.ParamKind {
        match kind {
            case uni.ParamKind.POSONLY:
                return types.ParamKind.POSONLY;

            case uni.ParamKind.NORMAL:
                return types.ParamKind.NORMAL;

            case uni.ParamKind.VARARG:
                return types.ParamKind.VARARG;

            case uni.ParamKind.KWONLY:
                return types.ParamKind.KWONLY;

            case uni.ParamKind.KWARG:
                return types.ParamKind.KWARG;
                return types.ParamKind.NORMAL;

        }
    }
    parameters: list[types.Parameter] = [];
    for (idx, param) in enumerate(node_.signature.get_parameters()) {
        # TODO: Set parameter category for *args, and **kwargs
        param_type: TypeBase | None = None;

        if param.type_tag {
            param_type_cls = self.get_type_of_expression(param.type_tag.tag);
            param_type = self._convert_to_instance(param_type_cls);
        }

        # For Python stub methods, check if first parameter is named 'self' or 'cls'
        # In addition to the Jac-specific checks
        # Note: For static methods, 'self' is just a regular parameter, not special
        is_self_param = (
            idx == 0
            and (
                self._is_expr_self(param.name)
                or (
                    isinstance(param.name, uni.Name)
                    and param.name.value == "self"
                    and node_.signature
                    and not node_.signature.is_static
                )
            )
        );
        is_cls_param = (
            idx == 0
            and (
                self._is_ability_classmethod(node_)
                or (
                    isinstance(param.name, uni.Name)
                    and param.name.value == "cls"
                    and node_.name_spec.sym_name == "__new__"
                )
            )
        );
        parameters.append(
            types.Parameter(
                name=param.name.value,
                category=_get_param_category(param),
                param_type=param_type,
                default_value=param.value,
                is_self=is_self_param,
                is_cls=is_cls_param,
                param_kind=_convert_param_kind(param.param_kind),
            )
        );
    }
    func_type = types.FunctionType(
        func_name=node_.name_spec.sym_name,
        return_type=return_type,
        parameters=parameters,
    );
    node_.name_spec.type = func_type;
    return func_type;
}

"""Return the effective type of the class."""
impl TypeEvaluator.get_type_of_class(node_: uni.Archetype) -> types.ClassType {
    # Is this type already cached?
    if node_.name_spec.type is not None {
        return cast(types.ClassType, node_.name_spec.type);
    }
    # Gather type parameters.
    type_params = self._extract_type_params(node_);
    base_classes: list[TypeBase] = [];
    for base_class in node_.base_classes or [] {
        base_class_type = self.get_type_of_expression(base_class);
        base_classes.append(base_class_type);
    }
    is_builtin_class = node_.find_parent_of_type(uni.Module) == self.builtins_module;
    # NOTE: obj, walker, node, edge are dataclass with symbol type as such but
    # other classes are with symbol type TYPE.
    # TODO: We need to handle @dataclass decorator as well.
    is_data_class = node_.sym_category != SymbolType.TYPE;
    is_enum_class = node_.sym_category == SymbolType.ENUM_ARCH;
    cls_type = types.ClassType(
        shared=types.ClassType.ClassDetailsShared(
            class_name=node_.name_spec.sym_name,
            symbol_table=node_,
            type_params=type_params,
            base_classes=base_classes,
            is_builtin_class=is_builtin_class,
            is_data_class=is_data_class,
            is_enum_class=is_enum_class,
        ),
        private=None,
        flags=types.TypeFlags.Instantiable,
    );
    # Compute the MRO for the class.
    type_utils.compute_mro_linearization(cls_type);
    # Cache the type, pyright is doing invalidateTypeCacheIfCanceled()
    # we're not doing that any time sooner.
    node_.name_spec.type = cls_type;
    return cls_type;
}

"""Return the built-in type with the given name."""
impl TypeEvaluator._get_type_from_module(module: uni.Module, name: str) -> TypeBase {
    if (symbol := type_utils.lookup_symtab(module, name, self.builtins_module)) is not None {
        return self.get_type_of_symbol(symbol);
    }
    return types.UnknownType();
}

impl TypeEvaluator.get_none_type -> TypeBase {
    if self.prefetch and self.prefetch.none_type_class {
        return self.prefetch.none_type_class;
    }
    return types.UnknownType();
}
