"""Jac Semantic Analysis Pass."""
from __future__ import annotations
from jaclang.pycore.jaclib import Obj, field
import ast as ast3
from collections.abc import Sequence
import jaclang.pycore.unitree as uni
from jaclang.pycore.constant import Tokens as Tok
from jaclang.pycore.passes import UniPass
from jaclang import JacRuntime as Jac
from jaclang.pycore.mtp import Info, VarInfo, FunctionInfo, MethodInfo, ClassInfo, FieldInfo, ParamInfo
import uuid

PRIMITIVE_TYPES: list[str] = ['int', 'float', 'str', 'bool', 'None', 'bytes', 'list', 'dict', 'set', 'tuple']

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

    def _extract_type_symbol(self, type_expr: uni.Expr | None, scope: uni.UniScopeNode) -> uni.Symbol | None:
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
        decl = symbol.decl
        if not isinstance(decl.name_of, uni.Archetype):
            return None
        arch_node = decl.name_of
        # Extract class name
        class_name = arch_node.name.value
        # Extract base classes
        base_classes: list[str] = []
        if arch_node.base_classes:
            for base in arch_node.base_classes:
                if isinstance(base, uni.Name):
                    base_classes.append(base.value)
                elif isinstance(base, uni.AtomTrailer):
                    base_classes.append(base.unparse())
        # Extract fields
        fields: list[FieldInfo] = []
        if arch_node.body and isinstance(arch_node.body, Sequence):
            for stmt in arch_node.body:
                if isinstance(stmt, uni.ArchHas):
                    for var in stmt.vars:
                        type_annotation = var.type_tag.tag if var.type_tag else None
                        is_primitive = self._is_primitive_type(type_annotation)
                        type_symbol_obj = self._extract_type_symbol(type_annotation, arch_node) if not is_primitive else None
                        # For FieldInfo: name, semstr, type_symbol
                        type_symbol_value: ClassInfo | str | None = None
                        if type_symbol_obj:
                            nested_class = self._extract_class_info(type_symbol_obj)
                            type_symbol_value = nested_class if nested_class else type_annotation.value if isinstance(type_annotation, uni.Name) else None
                        elif is_primitive and type_annotation:
                            type_symbol_value = type_annotation.value if isinstance(type_annotation, uni.Name) else str(type_annotation)
                        field_info = FieldInfo(
                            name=var.name.value,
                            semstr=type_symbol_obj.semstr if type_symbol_obj else symbol.semstr,
                            type_symbol=type_symbol_value
                        )
                        fields.append(field_info)
        # Extract methods
        methods: list[str] = []
        if arch_node.body and isinstance(arch_node.body, Sequence):
            for stmt in arch_node.body:
                if isinstance(stmt, uni.Ability):
                    methods.append(stmt.py_resolve_name())
        # Return ClassInfo
        return ClassInfo(
            name=class_name,
            semstr=symbol.semstr,
            fields=fields,
            base_classes=base_classes,
            methods=methods,
            archetype_node=arch_node
        )

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
                is_primitive = self._is_primitive_type(type_annotation)
                type_symbol_obj = self._extract_type_symbol(type_annotation, node) if not is_primitive else None
                # For ParamInfo: name, semstr, type_symbol
                type_symbol_value: ClassInfo | str | None = None
                if type_symbol_obj:
                    nested_class = self._extract_class_info(type_symbol_obj)
                    type_symbol_value = nested_class if nested_class else type_annotation.value if isinstance(type_annotation, uni.Name) else None
                elif is_primitive and type_annotation:
                    type_symbol_value = type_annotation.value if isinstance(type_annotation, uni.Name) else str(type_annotation)
                param_info = ParamInfo(
                    name=param.name.value,
                    semstr=type_symbol_obj.semstr if type_symbol_obj else (param.name.sym.semstr if hasattr(param.name, 'sym') and param.name.sym else None),
                    type_symbol=type_symbol_value
                )
                parameters.append(param_info)
        # Extract return type
        return_type: str | ClassInfo | None = None
        if node.signature and isinstance(node.signature, uni.FuncSignature):
            return_type_annotation = node.signature.return_type
            return_is_primitive = self._is_primitive_type(return_type_annotation)
            if return_is_primitive and return_type_annotation:
                return_type = return_type_annotation.value if isinstance(return_type_annotation, uni.Name) else str(return_type_annotation)
            elif not return_is_primitive:
                return_type_symbol = self._extract_type_symbol(return_type_annotation, node)
                if return_type_symbol:
                    return_class = self._extract_class_info(return_type_symbol)
                    return_type = return_class if return_class else (return_type_annotation.value if isinstance(return_type_annotation, uni.Name) else None)
        # Extract tools for genai abilities
        tools: list[Info] = []
        if node.is_genai_ability:
            if node.kid[-1].params:
                for param in node.kid[-1].params:
                    if isinstance(param, uni.KWPair):
                        if param.key.value == "tools":
                            for tool in param.value.values:
                                tool_ability = node.lookup(tool.value, deep=True).symbol_table
                                if tool_ability.is_method:
                                    tool_info = self._extract_method_info(tool_ability)
                                else:
                                    tool_info = self._extract_function_info(tool_ability)
                                tools.append(tool_info)
        # Return FunctionInfo
        return FunctionInfo(
            name=function_name,
            semstr=node.sym.semstr if hasattr(node, 'sym') and node.sym else None,
            params=parameters,
            return_type=return_type,
            tools=tools if tools else None
        )
    
    def _extract_method_info(self, node: uni.Ability) -> MethodInfo:
        """Extract method information from an Ability node."""
        func_info = self._extract_function_info(node)
        
        # Find parent archetype and extract its ClassInfo
        parent_arch = node.find_parent_of_type(uni.Archetype)
        parent_class_info = None
        if parent_arch and hasattr(parent_arch.name, 'sym') and parent_arch.name.sym:
            parent_class_info = self._extract_class_info(parent_arch.name.sym)
        
        return MethodInfo(
            name=func_info.name,
            semstr=func_info.semstr,
            params=func_info.params,
            return_type=func_info.return_type,
            parent_class=parent_class_info
        )
        

    def enter_ability(self, node: uni.Ability) -> None:
        """Handle entering an ability node for MTIR generation."""
        # Only process genai abilities
        if not node.is_genai_ability:
            return
        # Extract function or method info based on type
        if node.is_method:
            func_info = self._extract_method_info(node)
        else:
            func_info = self._extract_function_info(node)
        # Add to MTIR map
        Jac.add_mtir_to_map(node, func_info)
        
 