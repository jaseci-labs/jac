"""MTIR Generation Pass Implementation.

This module contains the implementations for MTIRGenPass methods.
"""

import from collections.abc { Sequence }
import from pathlib { Path }
import jaclang.jac0core.unitree as uni;
import from jaclang { JacRuntime as Jac }
import from jaclang.jac0core.mtp {
    ClassInfo,
    FieldInfo,
    FunctionInfo,
    MethodInfo,
    ParamInfo,
    mk_dict,
    mk_list,
    mk_tuple,
    type_to_str
}

"""Initialize the pass with the input IR and program context."""
impl MTIRGenPass.postinit -> None {
    super.init(self.ir_in, self.prog, self.cancel_token);
}

"""Check if a type expression represents a primitive type."""
impl MTIRGenPass._is_primitive_type(type_expr: uni.Expr | None) -> bool {
    if type_expr is None {
        return False;
    }
    if isinstance(type_expr, uni.Name) or isinstance(type_expr, uni.BuiltinType) {
        return type_expr.value in PRIMITIVE_TYPES;
    }
    return False;
}

"""Parse a unitree type expression into a primitive name, ClassInfo,
or tuple-based generic representation (using mk_list/mk_dict/mk_tuple)."""
impl MTIRGenPass._parse_type_expr(
    type_expr: uni.Expr | None, scope: uni.UniScopeNode
) -> ClassInfo | EnumInfo | str | tuple | None {
    if type_expr is None {
        return None;
    }
    if self._is_primitive_type(type_expr) {
        if isinstance(type_expr, uni.Name) {
            return type_expr.value;
        }
        return str(type_expr);
    }
    try {
        if type_expr?.unparse {
            text = type_expr.unparse();
        } else {
            text = str(type_expr);
        }
        if ('[' in text) and (']' in text) {
            base = text.split('[', 1)[0].strip();
            inner = text[(text.find('[') + 1):text.rfind(']')].strip();
            parts = [
                p.strip()
                for p in inner.split(',')
                if p.strip()
            ];
            resolved_parts: list[object] = [];
            for p in parts {
                try_sym = None;
                if isinstance(scope, uni.UniScopeNode) and scope?.lookup {
                    try {
                        try_sym = scope.lookup(p, deep=True);
                    } except Exception {
                        try_sym = None;
                    }
                }
                if try_sym {
                    nested = self._extract_class_info(try_sym);
                    resolved_parts.append(nested or p);
                } elif p in PRIMITIVE_TYPES {
                    resolved_parts.append(p);
                } else {
                    resolved_parts.append(p);
                }
            }
            if (base == 'list') and (len(resolved_parts) == 1) {
                return mk_list(resolved_parts[0]);
            }
            if (base == 'dict') and (len(resolved_parts) == 2) {
                return mk_dict(resolved_parts[0], resolved_parts[1]);
            }
            if (base == 'tuple') and (len(resolved_parts) >= 1) {
                return mk_tuple(*resolved_parts);
            }
            return tuple([base] + resolved_parts);
        }
    } except Exception {
        ;
    }
    sym = self._extract_type_symbol(type_expr, scope);
    if sym {
        if sym and sym.sym_type.value == 'enum' {
            enum_info = self._extract_enum_info(sym);
            return enum_info;
        } else {
            nested = self._extract_class_info(sym);
            if nested {
                return nested;
            }
            if isinstance(type_expr, uni.Name) {
                return type_expr.value;
            }
        }
    }
    return None;
}

"""Extract symbol from type expression if it's not a primitive type."""
impl MTIRGenPass._extract_type_symbol(
    type_expr: uni.Expr | None, scope: uni.UniScopeNode
) -> uni.Symbol | None {
    if (type_expr is None) or self._is_primitive_type(type_expr) {
        return None;
    }
    if isinstance(type_expr, uni.NameAtom) and type_expr.sym {
        return type_expr.sym;
    }
    if isinstance(type_expr, uni.Name) {
        return scope.lookup(type_expr.value, deep=True);
    }
    return None;
}

impl MTIRGenPass._extract_enum_info(symbol: uni.Symbol) -> EnumInfo {
    decl = symbol.decl;
    if not isinstance(decl.name_of, uni.Enum) {
        raise Exception(f"Symbol {symbol} is not an Enum.") ;
    }
    enum_node = decl.name_of;
    members: list[FieldInfo] = [];
    # Check if enum has a body and it's a Sequence
    if enum_node.body and isinstance(enum_node.body, Sequence) {
        for enum_stmt in enum_node.body {
            # Handle Assignment nodes (e.g., RED = 1)
            if isinstance(enum_stmt, uni.Assignment) and enum_stmt.is_enum_stmt {
                # Extract the target name (should be a single Name/NameAtom)
                if enum_stmt.target and len(enum_stmt.target) > 0 {
                    target = enum_stmt.target[0];
                    if isinstance(target, uni.NameAtom) or isinstance(target, uni.Name) {
                        member_name = target.value;
                        # Determine type from the assigned value
                        type_info = None;
                        if enum_stmt.value {
                            # Check literal types
                            if isinstance(enum_stmt.value, uni.Int) {
                                type_info = "int";
                            } elif isinstance(enum_stmt.value, uni.String) {
                                type_info = "str";
                            } elif isinstance(enum_stmt.value, uni.MultiString) {
                                # MultiString is used for string literals in some contexts
                                type_info = "str";
                            } elif isinstance(enum_stmt.value, uni.Float) {
                                type_info = "float";
                            } elif isinstance(enum_stmt.value, uni.Bool) {
                                type_info = "bool";
                            } else {
                                # Non-allowed type for enum value
                                raise Exception(
                                    f"Enum member '{member_name}' has invalid value type: {type(
                                        enum_stmt.value
                                    ).__name__}. "
                                    f"Only int, str, float, and bool literals are allowed."
                                ) ;
                            }
                        }
                        # Get semantic string from symbol if available
                        semstr_val = None;
                        if target?.sym and target.sym {
                            semstr_val = target.sym.semstr;
                        }
                        field_info = FieldInfo(
                            name=member_name, semstr=semstr_val, type_info=type_info
                        );
                        members.append(field_info);
                    }
                }
            }
            # Handle NameAtom nodes (simple enum members like RED, BLUE)
            elif isinstance(enum_stmt, uni.NameAtom) and enum_stmt.is_enum_stmt {
                member_name = enum_stmt.value;
                # Get semantic string from symbol if available
                semstr_val = None;
                if enum_stmt?.sym and enum_stmt.sym {
                    semstr_val = enum_stmt.sym.semstr;
                }
                field_info = FieldInfo(
                    name=member_name,
                    semstr=semstr_val,
                    type_info=None  # Simple enum members don't have explicit type
                );
                members.append(field_info);
            }
        }
    }
    return EnumInfo(
        name=enum_node.name.value,
        semstr=symbol.semstr or enum_node.doc.lit_value if enum_node.doc else None,
        members=members
    );
}

"""Extract class structure information from a symbol."""
impl MTIRGenPass._extract_class_info(symbol: uni.Symbol) -> ClassInfo | None {
    if not self?._class_info_cache {
        self._class_info_cache = {};
    }
    cache_key = id(symbol);
    if cache_key in self._class_info_cache {
        return self._class_info_cache[cache_key];
    }
    decl = symbol.decl;
    if not isinstance(decl.name_of, uni.Archetype) {
        return None;
    }
    arch_node = decl.name_of;
    class_name = arch_node.name.value;
    placeholder = ClassInfo(
        name=class_name,
        semstr=symbol.semstr or arch_node.doc.lit_value if arch_node.doc else None,
        fields=[],
        base_classes=[],
        methods=[]
    );
    self._class_info_cache[cache_key] = placeholder;
    base_classes: list[ClassInfo] = [];
    if arch_node.base_classes {
        for base in arch_node.base_classes {
            try_sym = self._extract_type_symbol(base, arch_node);
            if try_sym {
                nested = self._extract_class_info(try_sym);
                if nested {
                    base_classes.append(nested);
                    continue;
                }
            }
            if isinstance(base, uni.Name) {
                base_name = base.value;
            } elif isinstance(base, uni.AtomTrailer) {
                base_name = base.unparse();
            } else {
                base_name = str(base);
            }
            base_classes.append(ClassInfo(name=base_name, semstr=None));
        }
    }
    fields: list[FieldInfo] = [];
    if arch_node.body and isinstance(arch_node.body, Sequence) {
        for stmt in arch_node.body {
            if isinstance(stmt, uni.ArchHas) {
                for var in stmt.vars {
                    type_annotation = var.type_tag.tag if var.type_tag else None;

                    parsed_type = self._parse_type_expr(type_annotation, arch_node);

                    type_symbol_obj = self._extract_type_symbol(parsed_type, arch_node);

                    semstr_val = type_symbol_obj.semstr
                    if type_symbol_obj
                    else var.sym.semstr;
                    field_info = FieldInfo(
                        name=var.name.value, semstr=semstr_val, type_info=parsed_type
                    );
                    fields.append(field_info);
                }
            }
        }
    }
    methods: list[MethodInfo] = [];
    if arch_node.body and isinstance(arch_node.body, Sequence) {
        for stmt in arch_node.body {
            if isinstance(stmt, uni.Ability) and stmt.is_method {
                methods.append(self._extract_method_info(stmt));
            }
        }
    }
    placeholder.fields = fields;
    placeholder.base_classes = base_classes;
    placeholder.methods = methods;
    return placeholder;
}

"""Extract comprehensive information from an Ability node."""
impl MTIRGenPass._extract_function_info(nd: uni.Ability) -> FunctionInfo {
    function_name = nd.py_resolve_name();
    parameters: list[ParamInfo] = [];
    if nd.signature and isinstance(nd.signature, uni.FuncSignature) {
        all_params = nd.signature.get_parameters();
        for param in all_params {
            type_annotation = param.type_tag.tag if param.type_tag else None;
            parsed_type = self._parse_type_expr(type_annotation, nd);
            type_symbol_obj = self._extract_type_symbol(type_annotation, nd);
            semstr_val = None;
            if type_symbol_obj {
                semstr_val = type_symbol_obj.semstr;
            } elif param.name?.sym and param.name.sym {
                semstr_val = param.name.sym.semstr;
            }

            param_info = ParamInfo(
                name=param.name.value, semstr=semstr_val, type_info=parsed_type
            );
            parameters.append(param_info);
        }
    }
    return_type: str | ClassInfo | tuple | None = None;
    if nd.signature and isinstance(nd.signature, uni.FuncSignature) {
        return_type_annotation = nd.signature.return_type;
        parsed_return = self._parse_type_expr(return_type_annotation, nd);
        return_type = parsed_return;
    }
    tools: list[FunctionInfo] = [];
    if nd.is_genai_ability {
        # Extract tools from the by clause expression
        # node.body is the expression after 'by' (e.g., model(tools=[...]))
        by_expr = nd.body;
        tools = self._extract_tools_from_expr(by_expr, nd);
    }
    return FunctionInfo(
        name=function_name,
        semstr=nd.sym.semstr if nd?.sym and nd.sym else None,
        params=parameters,
        return_type=return_type,
        tools=tools
    );
}

"""Extract method information from an Ability node."""
impl MTIRGenPass._extract_method_info(
    nd: uni.Ability, by_call: bool = False
) -> MethodInfo {
    func_info = self._extract_function_info(nd=nd);
    parent_arch = nd.find_parent_of_type(uni.Archetype);
    parent_class_info = None;
    if parent_arch and parent_arch.name?.sym and parent_arch.name.sym and by_call {
        parent_class_info = self._extract_class_info(parent_arch.name.sym);
    } else {
        parent_class_info = parent_arch.name.sym;
    }
    return MethodInfo(
        name=func_info.name,
        semstr=func_info.semstr,
        params=func_info.params,
        return_type=func_info.return_type,
        parent_class=parent_class_info,
        tools=func_info.tools
    );
}

"""Get a unique scope string for a given scope node."""
impl MTIRGenPass._get_scope_str(nd: uni.UniScopeNode) -> str {
    # For Module nodes, use the file stem as the scope key.
    # For the entry point module, this will be just the filename without extension.
    # At runtime, we can get the same value from sys.modules['__main__'].__file__
    if isinstance(nd, uni.Module) {
        mod_path = nd.loc.mod_path;
        if mod_path {
            path = Path(mod_path);
            # Use just the file stem (filename without extension)
            stem = path.stem;
            # Handle multi-extension files like .impl.jac
            if stem.endswith(".impl") {
                stem = stem[:-5];
            } elif stem.endswith(".cl") or stem.endswith(".sv") {
                stem = stem[:-3];
            }
            return stem;
        }
        # Fallback to scope_name if mod_path is not available
        return nd.scope_name;
    }
    self_name = nd.scope_name;
    if nd.parent_scope and isinstance(nd.parent_scope, uni.UniScopeNode) {
        parent_scope_str = self._get_scope_str(nd.parent_scope);
        return f"{parent_scope_str}.{self_name}";
    }
    return self_name;
}

"""Extract tools from a by clause expression."""
impl MTIRGenPass._extract_tools_from_expr(
    expr: uni.Expr, scope: uni.UniScopeNode
) -> list[FunctionInfo] {
    tools: list[FunctionInfo] = [];
    # Helper to extract tools from a list of params
    # This is inlined instead of a nested function
    params_to_check: list = [];
    # Case 1: Direct function call - by model(tools=[...])
    if isinstance(expr, uni.FuncCall) and expr?.params {
        params_to_check = expr.params;
    }
    # Case 2: AtomTrailer (attribute/subscript access, possibly with call)
    elif isinstance(expr, uni.AtomTrailer) {
        # Traverse the chain to find FuncCall nodes
        current = expr;
        while current {
            # Check if right is a FuncCall
            if isinstance(current.right, uni.FuncCall) and current.right?.params {
                params_to_check = current.right.params;
                break;
            }
            # Check if target is AtomTrailer to continue chain
            if isinstance(current.target, uni.AtomTrailer) {
                current = current.target;
            } else {
                break;
            }
        }
    }
    # Extract tools from the params we found
    for param in params_to_check {
        if isinstance(param, uni.KWPair) and param?.key and param.key.value == 'tools' {
            # params.value should be a list of tool references
            if param.value?.values {
                for tool in param.value.values {
                    try {
                        # Try to lookup the tool symbol
                        tool_sym = None;
                        if isinstance(tool, uni.NameAtom) {
                            tool_sym = scope.lookup(tool.value, deep=True);
                        } elif isinstance(tool, uni.AtomTrailer)
                        and isinstance(tool.right, uni.NameAtom) {
                            # Handle module.function references
                            tool_sym = scope.lookup(tool.right.value, deep=True);
                        } elif tool?.symbol_table {
                            tool_sym = tool.symbol_table;
                        }

                        if tool_sym {
                            tool_ability = tool_sym.decl.name_of
                            if tool_sym.decl
                            else None;
                            if tool_ability and isinstance(tool_ability, uni.Ability) {
                                if tool_ability.is_method {
                                    tool_info = self._extract_method_info(tool_ability);
                                } else {
                                    tool_info = self._extract_function_info(
                                        tool_ability
                                    );
                                }
                                tools.append(tool_info);
                            }
                        }
                    } except Exception {
                        # If we can't resolve the tool, skip it
                        # Tools might be defined at runtime
                        ;
                    }
                }
            }
        }
    }
    return tools;
}

"""Handle entering an ability node for MTIR generation."""
impl MTIRGenPass.enter_ability(nd: uni.Ability) -> None {
    if not nd.is_genai_ability {
        return;
    }
    if nd.is_method {
        func_info = self._extract_method_info(nd=nd, by_call=True);
        if (
            isinstance(func_info.return_type, str)
            and func_info.parent_class
            and (func_info.return_type == func_info.parent_class.name)
        ) {
            func_info.return_type = func_info.parent_class;
            parent_name = func_info.parent_class.name
            if func_info.parent_class
            else None;
            ret_str = type_to_str(func_info.return_type);
        }
    } else {
        func_info = self._extract_function_info(nd=nd);
    }
    scope = self._get_scope_str(nd);
    Jac.add_mtir_to_map(scope, func_info);
}
