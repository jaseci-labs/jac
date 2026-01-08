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
        class_name = arch_node.name.value
        base_classes: list[str] = []
        if arch_node.base_classes:
            for base in arch_node.base_classes:
                if isinstance(base, uni.Name):
                    base_classes.append(base.value)
                elif isinstance(base, uni.AtomTrailer):
                    base_classes.append(base.unparse())
        fields: list[FieldInfo] = []
        if arch_node.body and isinstance(arch_node.body, Sequence):
            for stmt in arch_node.body:
                if isinstance(stmt, uni.ArchHas):
                    for var in stmt.vars:
                        type_annotation = var.type_tag.tag if var.type_tag else None
                        is_primitive = self._is_primitive_type(type_annotation)
                        type_symbol_obj = self._extract_type_symbol(type_annotation, arch_node) if not is_primitive else None
                        # For FieldInfo: name, symbol, semstr, type_symbol
                        type_symbol_value: ClassInfo | str | None = None
                        if type_symbol_obj:
                            nested_class = self._extract_class_info(type_symbol_obj)
                            type_symbol_value = nested_class if nested_class else type_annotation.value if isinstance(type_annotation, uni.Name) else None
                        elif is_primitive and type_annotation:
                            type_symbol_value = type_annotation.value if isinstance(type_annotation, uni.Name) else str(type_annotation)
                        field_info = FieldInfo(
                            name=var.name.value,
                            symbol=type_symbol_obj if type_symbol_obj else symbol,
                            semstr=type_symbol_obj.semstr if type_symbol_obj else symbol.semstr,
                            type_symbol=type_symbol_value
                        )
                        fields.append(field_info)
        methods: list[str] = []
        if arch_node.body and isinstance(arch_node.body, Sequence):
            for stmt in arch_node.body:
                if isinstance(stmt, uni.Ability):
                    methods.append(stmt.py_resolve_name())
        return ClassInfo(
            name=class_name,
            symbol=symbol,
            semstr=symbol.semstr,
            fields=fields,
            base_classes=base_classes,
            methods=methods,
            archetype_node=arch_node
        )

    def _extract_function_info(self, node: uni.Ability) -> FunctionInfo:
        """Extract comprehensive information from an Ability node."""
        function_name = node.py_resolve_name()
        parameters: list[ParamInfo] = []
        if node.signature and isinstance(node.signature, uni.FuncSignature):
            all_params = node.signature.get_parameters()
            for param in all_params:
                type_annotation = param.type_tag.tag if param.type_tag else None
                is_primitive = self._is_primitive_type(type_annotation)
                type_symbol_obj = self._extract_type_symbol(type_annotation, node) if not is_primitive else None
                # For ParamInfo: name, symbol, semstr, type_symbol
                type_symbol_value: ClassInfo | str | None = None
                if type_symbol_obj:
                    nested_class = self._extract_class_info(type_symbol_obj)
                    type_symbol_value = nested_class if nested_class else type_annotation.value if isinstance(type_annotation, uni.Name) else None
                elif is_primitive and type_annotation:
                    type_symbol_value = type_annotation.value if isinstance(type_annotation, uni.Name) else str(type_annotation)
                param_info = ParamInfo(
                    name=param.name.value,
                    symbol=type_symbol_obj if type_symbol_obj else (param.name.sym if hasattr(param.name, 'sym') else None),
                    semstr=type_symbol_obj.semstr if type_symbol_obj else (param.name.sym.semstr if hasattr(param.name, 'sym') and param.name.sym else None),
                    type_symbol=type_symbol_value
                )
                parameters.append(param_info)
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
        if node.is_genai_ability:
            print(node)
        return FunctionInfo(
            name=function_name,
            symbol=node.sym if hasattr(node, 'sym') else None,
            semstr=node.sym.semstr if hasattr(node, 'sym') and node.sym else None,
            params=parameters,
            return_type=return_type
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
            symbol=func_info.symbol,
            semstr=func_info.semstr,
            params=func_info.params,
            return_type=func_info.return_type,
            parent_class=parent_class_info
        )
        

    def enter_ability(self, node: uni.Ability) -> None:
        """Handle entering an ability node for MTIR generation."""
        if not node.is_genai_ability:
            return
        if node.is_method:
            func_info = self._extract_method_info(node)
        else:
            func_info = self._extract_function_info(node)
        Jac.add_mtir_to_map(node, func_info)
        # print(f"""{'=' * 60}""")
        # print(f'Function: {func_info.name}')
        # print(f"Parameters: {len(func_info.params)}")
        # for param in func_info.params:
        #     is_primitive = isinstance(param.type_symbol, str) and param.type_symbol in PRIMITIVE_TYPES
        #     print(f"  - {param.name}: primitive={is_primitive}, type={param.type_symbol}")
            
        #     # If parameter has a custom type (ClassInfo), show its structure
        #     if isinstance(param.type_symbol, ClassInfo):
        #         class_info = param.type_symbol
        #         print(f"    Class: {class_info.name}")
        #         print(f"    Fields: {len(class_info.fields)}")
        #         for field in class_info.fields:
        #             field_type_str = field.type_symbol if isinstance(field.type_symbol, str) else (field.type_symbol.name if isinstance(field.type_symbol, ClassInfo) else 'complex')
        #             print(f"      - {field.name}: {field_type_str}")
                    
        #             # Recursively show nested class info
        #             if isinstance(field.type_symbol, ClassInfo):
        #                 nested_class = field.type_symbol
        #                 print(f"        Nested class: {nested_class.name} with {len(nested_class.fields)} fields")
        
        # if node.is_method and func_info.parent_class:
        #     print(f"Parent Class: {func_info.parent_class.name}")

        # return_is_primitive = isinstance(func_info.return_type, str)
        # print(f"Return: primitive={return_is_primitive}, type={func_info.return_type}")
        
        # # Show return type class structure if it's a custom type
        # if isinstance(func_info.return_type, ClassInfo):
        #     class_info = func_info.return_type
        #     print(f"  Return Class: {class_info.name}")
        #     print(f"  Fields: {len(class_info.fields)}")
        #     for field in class_info.fields:
        #         field_type_str = field.type_symbol if isinstance(field.type_symbol, str) else (field.type_symbol.name if isinstance(field.type_symbol, ClassInfo) else 'complex')
        #         print(f"    - {field.name}: {field_type_str}")
        # print(f"{'='*60}\n")
 