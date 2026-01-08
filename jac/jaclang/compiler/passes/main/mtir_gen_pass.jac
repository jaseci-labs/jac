"""Jac Semantic Analysis Pass."""
import ast as ast3;
import from collections.abc { Sequence }
import jaclang.pycore.unitree as uni;
import from jaclang.compiler.constant { Tokens as Tok }
import from jaclang.pycore.passes { UniPass }
import from jaclang { JacRuntime as Jac }
import from jaclang.pycore.mtp { Info, VarInfo, FunctionInfo, MethodInfo, ClassInfo, FieldInfo, ParamInfo }
import uuid;
"""Information about a function parameter."""

obj ParamInfo {
    has    name: str;
    has    type_annotation: (uni.Expr | None);
    has    type_symbol: (uni.Symbol | None);
    has    is_primitive: bool;
    has    has_default: bool;
}
"""Information about a class field."""
obj FieldInfo {
    has    name: str;
    has    type_annotation: (uni.Expr | None);
    has    type_symbol: (uni.Symbol | None);
    has    is_primitive: bool;
    has    has_default: bool;
    has    is_static: bool;
}
        
"""Extracted information about a class/archetype."""

obj ClassInfo {
    has    class_name: str;
    has    fields: list[FieldInfo];
    has    base_classes: list[str];
    has    methods: list[str];
    has    archetype_node: uni.Archetype;
}
"""Extracted information about a function/ability."""
obj FunctionInfo {
    has    function_name: str;
    has    parameters: list[ParamInfo];
    has    return_type_annotation: (uni.Expr | None);
    has    return_type_symbol: (uni.Symbol | None);
    has    return_is_primitive: bool;
}

"""Jac MTIR Generation Pass."""
obj MTIRGenPass(UniPass) {
    has PRIMITIVE_TYPES: list[str] = ['int','float','str','bool','None','bytes','list','dict','set','tuple'];
    

    """Check if a type expression represents a primitive type."""
    def _is_primitive_type( type_expr: (uni.Expr | None)) -> bool {
        if (type_expr is None) {
            return False;
        }
        if isinstance(type_expr, uni.Name) {
            return (type_expr.value in self.PRIMITIVE_TYPES);
        }
        if isinstance(type_expr, uni.BuiltinType) {
            return (type_expr.value in self.PRIMITIVE_TYPES);
        }
        return False;
    }
    """Extract symbol from type expression if it's not a primitive type."""
    def _extract_type_symbol(
         type_expr: (uni.Expr | None), scope: uni.UniScopeNode
    ) -> (uni.Symbol | None) {
        if ((type_expr is None) or self._is_primitive_type(type_expr)) {
            return None;
        }
        if (isinstance(type_expr, uni.NameAtom) and type_expr.sym) {
            return type_expr.sym;
        }
        if isinstance(type_expr, uni.Name) {
            return scope.lookup(type_expr.value, deep=True);
        }
        return None;
    }
    """Extract class structure information from a symbol.

        Args:
            symbol: Symbol representing a class/archetype

        Returns:
            ClassInfo object with class structure details, or None if not a class
        """
    def _extract_class_info(
        symbol: uni.Symbol
    ) -> (ClassInfo | None) {
        decl = symbol.decl;
        if not isinstance(decl.name_of, uni.Archetype) {
            return None;
        }
        arch_node = decl.name_of;
        class_name = arch_node.name.value;
        base_classes: list[str] = [];
        if arch_node.base_classes {
            for base in arch_node.base_classes {
                if isinstance(base, uni.Name) {
                    base_classes.append(base.value);
                } elif isinstance(base, uni.AtomTrailer) {
                    base_classes.append(base.unparse());
                }
            }
        }
        fields: list[FieldInfo] = [];
        if (arch_node.body and isinstance(arch_node.body, Sequence)) {
            for stmt in arch_node.body {
                if isinstance(stmt, uni.ArchHas) {
                    for var in stmt.vars {
                        type_annotation = var.type_tag.tag if var.type_tag else None;
                        is_primitive = self._is_primitive_type(type_annotation);
                        type_symbol = self._extract_type_symbol(
                            type_annotation, arch_node
                        )
                        if not is_primitive
                        else None;
                        field_info = FieldInfo(
                            name=var.name.value,
                            type_annotation=type_annotation,
                            type_symbol=type_symbol,
                            is_primitive=is_primitive,
                            has_default=(var.value is not None),
                            is_static=stmt.is_static
                        );
                        fields.append(field_info);
                    }
                }
            }
        }
        methods: list[str] = [];
        if (arch_node.body and isinstance(arch_node.body, Sequence)) {
            for stmt in arch_node.body {
                if isinstance(stmt, uni.Ability) {
                    methods.append(stmt.py_resolve_name());
                }
            }
        }
        return ClassInfo(
            class_name=class_name,
            fields=fields,
            base_classes=base_classes,
            methods=methods,
            archetype_node=arch_node
        );
    }

    """Extract comprehensive information from an Ability node."""
    def _extract_function_info(<>node: uni.Ability) -> FunctionInfo {
        function_name = <>node.py_resolve_name();
        parameters: list[ParamInfo] = [];
        if (<>node.signature and isinstance(<>node.signature, uni.FuncSignature)) {
            all_params = <>node.signature.get_parameters();
            for param in all_params {
                type_annotation = param.type_tag.tag if param.type_tag else None;
                is_primitive = self._is_primitive_type(type_annotation);
                type_symbol = self._extract_type_symbol(type_annotation, <>node)
                if not is_primitive
                else None;
                param_info = ParamInfo(
                    name=param.name.value,
                    type_annotation=type_annotation,
                    type_symbol=type_symbol,
                    is_primitive=is_primitive,
                    has_default=(param.value is not None)
                );
                parameters.append(param_info);
            }
        }
        return_type_annotation = None;
        return_type_symbol = None;
        return_is_primitive = False;
        if (<>node.signature and isinstance(<>node.signature, uni.FuncSignature)) {
            return_type_annotation = <>node.signature.return_type;
            return_is_primitive = self._is_primitive_type(return_type_annotation);
            return_type_symbol = self._extract_type_symbol(
                return_type_annotation, <>node
            )
            if not return_is_primitive
            else None;
        }
        return FunctionInfo(
            function_name=function_name,
            parameters=parameters,
            return_type_annotation=return_type_annotation,
            return_type_symbol=return_type_symbol,
            return_is_primitive=return_is_primitive
        );
    }
    """Handle entering an ability node for MTIR generation."""
    def enter_ability(<>node: uni.Ability) -> None {
        # print(f"MTIRGenPass: enter_ability: here");
        if not <>node.is_genai_ability {
            return;
        }
        func_info = self._extract_function_info(<>node);
        <>node.genid = str(uuid.uuid4());
        Jac.add_mtir_to_map(<>node, func_info);
        # TODO: Use extracted information for MTIR generation
        # For now, just demonstrate the extraction
        print(f"\n{'='*60}");
        print(f"Function: {func_info.function_name}");
        # print(f"Parameters: {len(func_info.parameters)}")
        # for param in func_info.parameters:
        #     print(f"  - {param.name}: primitive={param.is_primitive}, has_symbol={param.type_symbol is not None}")
            
        #     # If parameter has a custom type, extract its class structure
        #     if param.type_symbol:
        #         class_info = self._extract_class_info(param.type_symbol)
        #         if class_info:
        #             print(f"    Class: {class_info.class_name}")
        #             print(f"    Fields: {len(class_info.fields)}")
        #             for field in class_info.fields:
        #                 print(f"      - {field.name}: {field.type_annotation.value if isinstance(field.type_annotation, uni.Name) else 'complex'} (primitive={field.is_primitive}, static={field.is_static})")
                        
        #                 # Recursively extract nested class info
        #                 if field.type_symbol:
        #                     nested_class = self._extract_class_info(field.type_symbol)
        #                     if nested_class:
        #                         print(f"        Nested class: {nested_class.class_name} with {len(nested_class.fields)} fields")
        
        # print(f"Return: primitive={func_info.return_is_primitive}, has_symbol={func_info.return_type_symbol is not None}")
        
        # # Extract return type class structure if it's a custom type
        # if func_info.return_type_symbol:
        #     class_info = self._extract_class_info(func_info.return_type_symbol)
        #     if class_info:
        #         print(f"  Return Class: {class_info.class_name}")
        #         print(f"  Fields: {len(class_info.fields)}")
        #         for field in class_info.fields:
        #             print(f"    - {field.name}: {field.type_annotation.value if isinstance(field.type_annotation, uni.Name) else 'complex'} (primitive={field.is_primitive})")
        # print(f"{'='*60}\n")
    }
}

