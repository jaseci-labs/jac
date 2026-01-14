"""Jac Semantic Analysis Pass."""

from __future__ import annotations

from collections.abc import Sequence

import jaclang.pycore.unitree as uni
from jaclang import JacRuntime as Jac
from jaclang.pycore.mtp import (
    ClassInfo,
    FieldInfo,
    FunctionInfo,
    MethodInfo,
    ParamInfo,
    mk_dict,
    mk_list,
    mk_tuple,
    type_to_str,
)
from jaclang.pycore.passes import UniPass

PRIMITIVE_TYPES: list[str] = [
    "int",
    "float",
    "str",
    "bool",
    "None",
    "bytes",
    "list",
    "dict",
    "set",
    "tuple",
]


class MTIRGenPass(UniPass):
    """Jac MTIR Generation Pass."""

    def _is_primitive_type(self, type_expr: uni.Expr | None) -> bool:
        """Check if a type expression represents a primitive type."""
        if type_expr is None:
            return False
        if isinstance(type_expr, uni.Name):
            return type_expr.value in PRIMITIVE_TYPES
        if isinstance(type_expr, uni.BuiltinType):
            return type_expr.value in PRIMITIVE_TYPES
        return False

    def _parse_type_expr(
        self, type_expr: uni.Expr | None, scope: uni.UniScopeNode
    ) -> ClassInfo | str | tuple | None:
        """Parse a unitree type expression into a primitive name, ClassInfo,
        or tuple-based generic representation (using mk_list/mk_dict/mk_tuple).
        This is deliberately conservative to avoid wide refactors.
        """
        if type_expr is None:
            return None

        # primitives like `int`, `str`, `list` etc.
        if self._is_primitive_type(type_expr):
            if isinstance(type_expr, uni.Name):
                return type_expr.value
            return str(type_expr)

        # Try to obtain a textual form and parse common generics like list[..], dict[...], tuple[...]
        try:
            if hasattr(type_expr, "unparse"):
                text = type_expr.unparse()
            else:
                text = str(type_expr)
            if "[" in text and "]" in text:
                base = text.split("[", 1)[0].strip()
                inner = text[text.find("[") + 1 : text.rfind("]")].strip()
                parts = [p.strip() for p in inner.split(",") if p.strip()]
                resolved_parts: list[object] = []
                for p in parts:
                    # try scope lookup for symbol
                    try_sym = None
                    if isinstance(scope, uni.UniScopeNode) and hasattr(scope, "lookup"):
                        try:
                            try_sym = scope.lookup(p, deep=True)
                        except Exception:
                            try_sym = None
                    if try_sym:
                        nested = self._extract_class_info(try_sym)
                        resolved_parts.append(nested if nested else p)
                    elif p in PRIMITIVE_TYPES:
                        resolved_parts.append(p)
                    else:
                        resolved_parts.append(p)

                if base == "list" and len(resolved_parts) == 1:
                    return mk_list(resolved_parts[0])
                if base == "dict" and len(resolved_parts) == 2:
                    return mk_dict(resolved_parts[0], resolved_parts[1])
                if base == "tuple" and len(resolved_parts) >= 1:
                    return mk_tuple(*resolved_parts)
                # fallback: generic tuple encoding (base, args...)
                return tuple([base] + resolved_parts)
        except Exception:
            pass

        # Fallback: if the annotation names a symbol, try to resolve to ClassInfo
        sym = self._extract_type_symbol(type_expr, scope)
        if sym:
            nested = self._extract_class_info(sym)
            if nested:
                return nested
            # if not resolved to a full ClassInfo, return simple name when available
            if isinstance(type_expr, uni.Name):
                return type_expr.value

        return None

    def _extract_type_symbol(
        self, type_expr: uni.Expr | None, scope: uni.UniScopeNode
    ) -> uni.Symbol | None:
        """Extract symbol from type expression if it's not a primitive type."""
        if type_expr is None or self._is_primitive_type(type_expr):
            return None
        if isinstance(type_expr, uni.NameAtom) and type_expr.sym:
            return type_expr.sym
        if isinstance(type_expr, uni.Name):
            return scope.lookup(type_expr.value, deep=True)
        return None

    def _extract_class_info(self, symbol: uni.Symbol) -> ClassInfo | None:
        """Extract class structure information from a symbol.

        Args:
            symbol: Symbol representing a class/archetype

        Returns:
            ClassInfo object with class structure details, or None if not a class
        """
        # initialize small cache to avoid infinite recursion on self-referential symbols
        if not hasattr(self, "_class_info_cache"):
            self._class_info_cache = {}

        cache_key = id(symbol)
        if cache_key in self._class_info_cache:
            return self._class_info_cache[cache_key]

        decl = symbol.decl
        if not isinstance(decl.name_of, uni.Archetype):
            return None
        arch_node = decl.name_of
        # Extract class name
        class_name = arch_node.name.value
        # Create placeholder ClassInfo early and stash in cache to break cycles.
        placeholder = ClassInfo(
            name=class_name,
            semstr=symbol.semstr
            if symbol.semstr
            else (arch_node.doc.lit_value if arch_node.doc else None),
            fields=[],
            base_classes=[],
            methods=[],
        )
        self._class_info_cache[cache_key] = placeholder

        # Extract base classes (as ClassInfo objects)
        base_classes: list[ClassInfo] = []
        if arch_node.base_classes:
            for base in arch_node.base_classes:
                # try to resolve base to a symbol and extract its ClassInfo
                try_sym = self._extract_type_symbol(base, arch_node)
                if try_sym:
                    nested = self._extract_class_info(try_sym)
                    if nested:
                        base_classes.append(nested)
                        continue
                # fallback: create a minimal ClassInfo using the name
                if isinstance(base, uni.Name):
                    base_name = base.value
                elif isinstance(base, uni.AtomTrailer):
                    base_name = base.unparse()
                else:
                    base_name = str(base)
                base_classes.append(ClassInfo(name=base_name, semstr=None))
        # Extract fields
        fields: list[FieldInfo] = []
        if arch_node.body and isinstance(arch_node.body, Sequence):
            for stmt in arch_node.body:
                if isinstance(stmt, uni.ArchHas):
                    for var in stmt.vars:
                        type_annotation = var.type_tag.tag if var.type_tag else None
                        parsed_type = self._parse_type_expr(type_annotation, arch_node)
                        # Attempt to get a semstr from a referenced symbol when possible
                        type_symbol_obj = self._extract_type_symbol(
                            type_annotation, arch_node
                        )
                        semstr_val = (
                            type_symbol_obj.semstr if type_symbol_obj else symbol.semstr
                        )
                        field_info = FieldInfo(
                            name=var.name.value,
                            semstr=semstr_val,
                            type_info=parsed_type,
                        )
                        fields.append(field_info)
        # Extract methods (as MethodInfo objects)
        methods: list[MethodInfo] = []
        if arch_node.body and isinstance(arch_node.body, Sequence):
            for stmt in arch_node.body:
                if isinstance(stmt, uni.Ability) and stmt.is_method:
                    methods.append(self._extract_method_info(stmt))

        # Populate placeholder and return it
        placeholder.fields = fields
        placeholder.base_classes = base_classes
        placeholder.methods = methods
        return placeholder

    def _extract_function_info(self, node: uni.Ability) -> FunctionInfo:
        """Extract comprehensive information from an Ability node."""
        # Extract function name
        function_name = node.py_resolve_name()
        # Extract parameters
        parameters: list[ParamInfo] = []
        if node.signature and isinstance(node.signature, uni.FuncSignature):
            all_params = node.signature.get_parameters()
            for param in all_params:
                type_annotation = param.type_tag.tag if param.type_tag else None
                parsed_type = self._parse_type_expr(type_annotation, node)
                type_symbol_obj = self._extract_type_symbol(type_annotation, node)
                semstr_val = None
                if type_symbol_obj:
                    semstr_val = type_symbol_obj.semstr
                else:
                    if hasattr(param.name, "sym") and param.name.sym:
                        semstr_val = param.name.sym.semstr
                param_info = ParamInfo(
                    name=param.name.value,
                    semstr=semstr_val,
                    type_info=parsed_type,
                )
                parameters.append(param_info)

        # Extract return type
        return_type: str | ClassInfo | tuple | None = None
        if node.signature and isinstance(node.signature, uni.FuncSignature):
            return_type_annotation = node.signature.return_type
            parsed_return = self._parse_type_expr(return_type_annotation, node)
            return_type = parsed_return
        # Extract tools for genai abilities
        tools: list[FunctionInfo] = []
        if node.is_genai_ability:
            if node.kid[-1].params:
                for param in node.kid[-1].params:
                    if isinstance(param, uni.KWPair):
                        if param.key.value == "tools":
                            for tool in param.value.values:
                                tool_ability = node.lookup(
                                    tool.value, deep=True
                                ).symbol_table
                                if tool_ability.is_method:
                                    tool_info = self._extract_method_info(tool_ability)
                                else:
                                    tool_info = self._extract_function_info(
                                        tool_ability
                                    )
                                tools.append(tool_info)
        # Return FunctionInfo
        return FunctionInfo(
            name=function_name,
            semstr=node.sym.semstr if hasattr(node, "sym") and node.sym else None,
            params=parameters,
            return_type=return_type,
            tools=tools if tools else None,
        )

    def _extract_method_info(
        self, node: uni.Ability, by_call: bool = False
    ) -> MethodInfo:
        """Extract method information from an Ability node."""
        func_info = self._extract_function_info(node=node)

        # Find parent archetype and extract its ClassInfo
        parent_arch = node.find_parent_of_type(uni.Archetype)
        parent_class_info = None
        if (
            parent_arch
            and hasattr(parent_arch.name, "sym")
            and parent_arch.name.sym
            and by_call
        ):
            parent_class_info = self._extract_class_info(parent_arch.name.sym)

        return MethodInfo(
            name=func_info.name,
            semstr=func_info.semstr,
            params=func_info.params,
            return_type=func_info.return_type,
            parent_class=parent_class_info,
        )
    
    def _get_scope_str(self, node: uni.UniScopeNode) -> str:
        """Get a unique scope string for a given scope node."""
        self_name = node.scope_name
        if node.parent_scope and isinstance(node.parent_scope, uni.UniScopeNode):
            parent_scope_str = self._get_scope_str(node.parent_scope)
            return f"{parent_scope_str}.{self_name}"
        return self_name
        

    def enter_ability(self, node: uni.Ability) -> None:
        """Handle entering an ability node for MTIR generation."""
        # Only process genai abilities
        if not node.is_genai_ability:
            return
        # Extract function or method info based on type
        if node.is_method:
            func_info = self._extract_method_info(node=node, by_call=True)

            if (
                isinstance(func_info.return_type, str)
                and func_info.parent_class
                and func_info.return_type == func_info.parent_class.name
            ):
                func_info.return_type = func_info.parent_class
                # Avoid printing full dataclass repr (can contain cycles). Print concise info instead.
                parent_name = (
                    func_info.parent_class.name if func_info.parent_class else None
                )
                ret_str = type_to_str(func_info.return_type)
        else:
            func_info = self._extract_function_info(node=node)
        # Add to MTIR map
        scope = self._get_scope_str(node)
        Jac.add_mtir_to_map(scope, func_info)
        
 