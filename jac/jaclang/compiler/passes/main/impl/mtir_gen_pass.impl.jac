"""MTIR Generation Pass Implementation.

This module contains the implementations for MTIRGenPass methods.
"""

import from collections.abc { Sequence }
import from pathlib { Path }
import jaclang.pycore.unitree as uni;
import from jaclang { JacRuntime as Jac }
import from jaclang.pycore.mtp {
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
) -> ClassInfo | str | tuple | None {
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
        nested = self._extract_class_info(sym);
        if nested {
            return nested;
        }
        if isinstance(type_expr, uni.Name) {
            return type_expr.value;
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
impl MTIRGenPass._extract_function_info(node: uni.Ability) -> FunctionInfo {
    function_name = node.py_resolve_name();
    parameters: list[ParamInfo] = [];
    if node.signature and isinstance(node.signature, uni.FuncSignature) {
        all_params = node.signature.get_parameters();
        for param in all_params {
            type_annotation = param.type_tag.tag if param.type_tag else None;
            parsed_type = self._parse_type_expr(type_annotation, node);
            type_symbol_obj = self._extract_type_symbol(type_annotation, node);
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
    if node.signature and isinstance(node.signature, uni.FuncSignature) {
        return_type_annotation = node.signature.return_type;
        parsed_return = self._parse_type_expr(return_type_annotation, node);
        return_type = parsed_return;
    }
    tools: list[FunctionInfo] = [];
    if node.is_genai_ability {
        # Extract tools from the by clause expression
        # node.body is the expression after 'by' (e.g., model(tools=[...]))
        by_expr = node.body;
        tools = self._extract_tools_from_expr(by_expr, node);
    }
    return FunctionInfo(
        name=function_name,
        semstr=node.sym.semstr if node?.sym and node.sym else None,
        params=parameters,
        return_type=return_type,
        tools=tools
    );
}

"""Extract method information from an Ability node."""
impl MTIRGenPass._extract_method_info(
    node: uni.Ability, by_call: bool = False
) -> MethodInfo {
    func_info = self._extract_function_info(node=node);
    parent_arch = node.find_parent_of_type(uni.Archetype);
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
impl MTIRGenPass._get_scope_str(node: uni.UniScopeNode) -> str {
    # For Module nodes, compute the full module path using the file path
    if isinstance(node, uni.Module) {
        mod_path = node.loc.mod_path;
        # Use the entry point's directory as the base path for module resolution
        # This matches how Python's __module__ is resolved at runtime
        main_mod = self.prog.mod.main if self.prog and self.prog.mod else None;
        if main_mod and main_mod.loc.mod_path {
            base_path = str(Path(main_mod.loc.mod_path).parent);
        } else {
            base_path = Jac.base_path_dir;
        }
        if base_path and mod_path {
            path = Path(mod_path);
            base = Path(base_path);
            try {
                rel_path = path.relative_to(base);
            } except ValueError {
                # File not under base_path, use filename
                rel_path = path;
            }
            # Remove .jac extension and convert path separators to dots
            module_parts: list[str] = [];
            for part in rel_path.parts {
                if part.endswith(".jac") {
                    module_parts.append(part[:-4]);
                } elif part.endswith(".impl.jac") {
                    module_parts.append(part[:-9]);
                } elif part.endswith(".cl.jac") {
                    module_parts.append(part[:-7]);
                } elif part.endswith(".sv.jac") {
                    module_parts.append(part[:-7]);
                } else {
                    module_parts.append(part);
                }
            }
            return ".".join(module_parts);
        }
        # Fallback to scope_name if base_path is not available
        return node.scope_name;
    }
    self_name = node.scope_name;
    if node.parent_scope and isinstance(node.parent_scope, uni.UniScopeNode) {
        parent_scope_str = self._get_scope_str(node.parent_scope);
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
impl MTIRGenPass.enter_ability(node: uni.Ability) -> None {
    if not node.is_genai_ability {
        return;
    }
    if node.is_method {
        func_info = self._extract_method_info(node=node, by_call=True);
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
        func_info = self._extract_function_info(node=node);
    }
    scope = self._get_scope_str(node);
    Jac.add_mtir_to_map(scope, func_info);
}
