"""extracting/setting JType from Jac expressions."""

from typing import Optional

import jaclang.compiler.jtyping as jtype
import jaclang.compiler.unitree as ast
from jaclang.compiler.jtyping.registery import JTypeRegistry
from jaclang.settings import settings
from jaclang.utils.helpers import pascal_to_snake


class JTypeResolver:
    """Extract/Set JType from Jac expressions."""

    def __init__(self, type_registry: JTypeRegistry) -> None:
        """Initialize the JacTypeResolver."""
        self.type_registry = type_registry

    def __debug_print(self, msg: str) -> None:
        if settings.debug_jac_typing:
            print("[JacTypeResolver]", msg)

    def get_type(self, node: Optional[ast.Expr]) -> jtype.JType:
        """
        Determine the JType of any Jac expression node.

        This is a generic dispatcher method that maps an AST expression node
        (e.g., `Literal`, `Name`, `BinaryExpr`, etc.) to its corresponding
        type resolution handler (e.g., `_get_literal_expr_type`, `_get_name_expr_type`).

        The method converts the node's class name to snake_case, constructs the handler
        function name, and calls it if implemented. If no specific handler is found,
        it defaults to returning `JAnyType`, indicating an unknown or untyped expression.

        This method also handles `None` nodes gracefully by returning `JNoneType`, which
        may be used in situations like empty return statements or untyped defaults.

        Args:
            node (Optional[ast.Expr]): The expression node to infer the type of.

        Returns:
            jtype.JType: The inferred or declared type of the expression.
        """
        if node is None:
            return jtype.JNoneType()

        name = pascal_to_snake(node.__class__.__name__)
        func_name = f"_get_{name}_expr_type"

        if hasattr(self, func_name):
            return getattr(self, func_name)(node)
        else:
            self.__debug_print(f"{func_name} is not implemented yet")
            return jtype.JAnyType()

    def _get_name_expr_type(self, node: ast.Name) -> jtype.JType:
        """
        Resolve the JType of a name expression in the AST.

        This method attempts to determine the type of a symbol referenced by a `Name` node.
        If the symbol is not yet bound, it falls back to `JAnyType`. If the symbol's type is
        currently `JAnyType`, it attempts to resolve the fully qualified type from the
        global type registry using the module path and symbol name.

        However, in the case of **forward references**, the first occurrence of a type name
        may appear in a usage context (e.g., as an annotation) before the actual type is
        declared. In such situations, the symbol's `jtype` will initially be `JAnyType`,
        since the declaration hasn't yet been processed.

        To handle this, the method attempts to reconstruct the fully qualified name of the
        identifier (based on its module and symbol name) and queries the global type registry.
        If a real type has been registered by a separate type collection pass, it replaces
        the default `JAnyType` with the correct `JType`.

        Args:
            node (ast.Name): The name expression node whose type is to be resolved.

        Returns:
            jtype.JType: The best-known type for the name, either from the symbol itself
                        or from the global type registry if a better match is found.
        """
        if node.name_spec.sym is None:
            return jtype.JAnyType()

        name_type = node.name_spec.sym.jtype
        registered_type: Optional[jtype.JType] = None

        if isinstance(name_type, jtype.JAnyType):
            module = node.parent_of_type(ast.Module)
            full_name = f"{module.get_href_path(node)}.{node.sym_name}"
            registered_type = self.type_registry.get(full_name)

        if registered_type:
            return registered_type
        else:
            return name_type

    def _get_int_expr_type(self, node: ast.Int) -> jtype.JType:
        """
        Resolve the type of an integer literal.

        Returns:
            JClassInstanceType: An instance of 'builtins.int'.
        """
        t = self.type_registry.get("builtins.int")
        assert isinstance(t, jtype.JClassType)
        return jtype.JClassInstanceType(t)

    def _get_float_expr_type(self, node: ast.Float) -> jtype.JType:
        """
        Resolve the type of a float literal.

        Returns:
            JClassInstanceType: An instance of 'builtins.float'.
        """
        t = self.type_registry.get("builtins.float")
        assert isinstance(t, jtype.JClassType)
        return jtype.JClassInstanceType(t)

    def _get_bool_expr_type(self, node: ast.Bool) -> jtype.JType:
        """
        Resolve the type of a boolean literal.

        Returns:
            JClassInstanceType: An instance of 'builtins.bool'.
        """
        t = self.type_registry.get("builtins.bool")
        assert isinstance(t, jtype.JClassType)
        return jtype.JClassInstanceType(t)

    def _get_multi_string_expr_type(self, node: ast.MultiString) -> jtype.JType:
        """
        Resolve the type of a multi-line string literal.

        Returns:
            JClassInstanceType: An instance of 'builtins.str'.
        """
        t = self.type_registry.get("builtins.str")
        assert isinstance(t, jtype.JClassType)
        return jtype.JClassInstanceType(t)

    def _get_string_expr_type(self, node: ast.MultiString) -> jtype.JType:
        """
        Resolve the type of a single-line string literal.

        Returns:
            JClassInstanceType: An instance of 'builtins.str'.
        """
        t = self.type_registry.get("builtins.str")
        assert isinstance(t, jtype.JClassType)
        return jtype.JClassInstanceType(t)

    def _get_null_expr_type(self, node: ast.Null) -> jtype.JType:
        """
        Resolve the type of a null literal (`null` in Jac).

        This corresponds to the built-in `None` type in the type system,
        used when a variable or expression is explicitly set to null.

        Args:
            node (ast.Null): The AST node representing the null literal.

        Returns:
            JNoneType: A singleton type representing `null`.
        """
        return jtype.JNoneType()

    def _get_builtin_type_expr_type(self, node: ast.BuiltinType) -> jtype.JType:
        """
        Resolve the type of a built-in type reference (e.g., `int`, `float`, etc.).

        This is used when the source code contains a direct reference to a built-in type,
        such as `int`, `str`, `float`, or `bool`, in a type annotation or type expression.

        The method maps the internal token name (`TYP_INT`, `TYP_BOOL`, etc.)
        to its fully qualified type in the registry and returns an instance type.

        Args:
            node (ast.BuiltinType): The AST node representing the type name.

        Returns:
            JClassInstanceType: The resolved built-in type as an instance type.
        """
        type_map: dict[str, str] = {
            "TYP_INT": "builtins.int",
            "TYP_FLOAT": "builtins.float",
            "TYP_STRING": "builtins.str",
            "TYP_BOOL": "builtins.bool",
            "TYP_LIST": "builtins.list",
            "TYP_DICT": "builtins.dict",
        }

        if node.name in type_map:
            t = self.type_registry.get(type_map[node.name])
            assert isinstance(t, jtype.JClassType)
            return jtype.JClassInstanceType(t)
        else:
            self.__debug_print(f"builtins of type {node.name} is not supported yet")
            return jtype.JAnyType()

    def _get_func_call_expr_type(self, node: ast.FuncCall) -> jtype.JType:
        """
        Resolve the type of a function call expression.

        This method handles both regular function calls and constructor calls:
        - If the target resolves to a JFunctionType, it returns the declared return type.
        - If the target resolves to a JClassType, it represents a constructor call
        and returns a JClassInstanceType of that class.
        - If the function target has no resolved symbol, the type defaults to JAnyType.

        Args:
            node (ast.FuncCall): The AST node representing the function call expression.

        Returns:
            JType: The resulting type of evaluating the function call.
        """
        assert isinstance(node.target, (ast.NameAtom, ast.AtomTrailer))

        if isinstance(node.target, ast.NameAtom) and node.target.name_spec.sym is None:
            self.__debug_print(
                f"Ignoring function call {node.unparse()}, no symbol linked to it"
            )
            return jtype.JAnyType()

        func_type = self.get_type(node.target)

        # TODO: this needs to be removed once importing is supported
        if isinstance(func_type, jtype.JAnyType):
            self.__debug_print(f"Can't get type of {node.loc.mod_path} {node.loc}")
            return func_type

        assert isinstance(func_type, (jtype.JFunctionType, jtype.JClassType))

        # In case of normal functions
        if isinstance(func_type, jtype.JFunctionType):
            return func_type.return_type

        # In case of class constructor
        elif isinstance(func_type, jtype.JClassType):
            return jtype.JClassInstanceType(func_type)

        raise AssertionError()

    def _get_atom_trailer_expr_type(self, node: ast.AtomTrailer) -> jtype.JType:
        """
        Resolve the type of a chained expression, including attribute and index access.

        This method evaluates the final expression in a chained access like `a.b.c` or `T[int]`,
        by returning the type of the last node in the trailer list.

        Args:
            node (ast.AtomTrailer): The AST node representing the chained expression.

        Returns:
            JType: The resolved type of the last expression in the access chain.
        """
        last_node = node.to_list[-1]
        assert isinstance(last_node, ast.Expr)
        return self.get_type(last_node)

    def _get_index_slice_expr_type(self, node: ast.IndexSlice) -> jtype.JType:
        """
        Resolve the type of an index slice expression.

        This method handles two distinct contexts:

        1. **Type annotation context (e.g., List[int])**:
        If the slice is part of a type annotation, it interprets the expression as a generic
        instantiation and returns a `JClassInstanceType` wrapping a `JGenericType`.

        2. **Runtime indexing (e.g., obj[0])**:
        If the slice is used outside an annotation, it attempts to resolve the result of
        `__getitem__` method on the base object.

        Tuple values in the slice are treated as multiple type/index arguments.

        Args:
            node (ast.IndexSlice): The index slice AST node to resolve.

        Returns:
            JType:
                - A `JClassInstanceType` wrapping `JGenericType` for generic instantiations.
                - The return type of `__getitem__` for runtime indexing.
                - Raises an error if indexing is unsupported by the base type.
        """
        parent = node.parent
        assert isinstance(parent, ast.AtomTrailer)
        base_type = self.get_type(parent.to_list[-2])

        if isinstance(base_type, jtype.JAnyType):
            return jtype.JAnyType()

        assert isinstance(base_type, jtype.JClassInstanceType)

        if node.find_parent_of_type(ast.SubTag) or node.find_parent_of_type(
            ast.FuncSignature
        ):
            generic_vars: list[jtype.JClassInstanceType | jtype.JUnionType] = []
            if isinstance(node.slices[0].start, ast.TupleVal):
                for v in node.slices[0].start.values:
                    assert isinstance(v, ast.Expr)
                    expression_type = self.get_type(v)
                    if isinstance(
                        expression_type, (jtype.JClassType, jtype.JGenericType)
                    ):
                        expression_type = jtype.JClassInstanceType(expression_type)
                    assert isinstance(
                        expression_type, (jtype.JUnionType, jtype.JClassInstanceType)
                    )
                    generic_vars.append(expression_type)
            else:
                expression_type = self.get_type(node.slices[0].start)
                if isinstance(expression_type, (jtype.JClassType, jtype.JGenericType)):
                    expression_type = jtype.JClassInstanceType(expression_type)
                assert isinstance(
                    expression_type, (jtype.JUnionType, jtype.JClassInstanceType)
                )
                generic_vars = [expression_type]
            assert isinstance(base_type.class_type, jtype.JClassType)
            return jtype.JClassInstanceType(
                jtype.JGenericType(base_type.class_type, generic_vars)
            )
        else:
            index_method = base_type.get_member("__getitem__")
            if index_method:
                assert isinstance(index_method.type, jtype.JFunctionType)
                if node.slices[0].stop is not None:
                    list_type = self.__get_list_type()
                    return jtype.JClassInstanceType(
                        jtype.JGenericType(list_type, [index_method.type.return_type])
                    )
                else:
                    return index_method.type.return_type
            else:
                return jtype.JAnyType()

    def _get_special_var_ref_expr_type(self, node: ast.SpecialVarRef) -> jtype.JType:
        """
        Resolve the type of a special variable reference (e.g., `here`).

        Special variables are reserved keywords that have specific contextual meaning.
        For example, `here` refers to the current instance of the enclosing archetype
        and should resolve to that archetype's type.

        If the keyword is not part of an archetype then check if it's part of an impl
        node of an archetype.

        If the special variable is not recognized (e.g., not `here`), the method
        falls back to standard name-based resolution.

        Args:
            node (ast.SpecialVarRef): The AST node representing the special variable reference.

        Returns:
            JType: The resolved type of the special variable.
        """
        if node.sym_name in ["here", "self", "super"]:
            archetype_node = node.find_parent_of_type(ast.Archetype)
            if archetype_node is None:
                impl_decl = node.find_parent_of_type(ast.ImplDef)
                if impl_decl and impl_decl.decl_link:
                    if isinstance(impl_decl.decl_link, ast.Archetype):
                        archetype_node = impl_decl.decl_link
                    else:
                        archetype_node = impl_decl.decl_link.find_parent_of_type(
                            ast.Archetype
                        )
            if not archetype_node:
                return jtype.JAnyType()
            if archetype_node.sym:
                assert isinstance(archetype_node.sym.jtype, jtype.JClassType)
                if node.sym_name == "super":
                    return jtype.JClassInstanceType(archetype_node.sym.jtype.bases[0])
                else:
                    return jtype.JClassInstanceType(archetype_node.sym.jtype)
        return self._get_name_expr_type(node)

    def _get_binary_expr_expr_type(self, node: ast.BinaryExpr) -> jtype.JType:
        return node.expr_type

    def _get_list_val_expr_type(self, node: ast.ListVal) -> jtype.JType:
        union_types = {}
        for val in node.values:
            val_type = self.get_type(val)
            union_types[str(val_type)] = val_type

        list_type = self.__get_list_type()
        if len(list(union_types.values())) == 0:
            return jtype.JClassInstanceType(list_type)
        elif len(list(union_types.values())) == 1:
            return jtype.JClassInstanceType(
                jtype.JGenericType(list_type, union_types.values())
            )
        else:
            return jtype.JClassInstanceType(
                jtype.JGenericType(
                    list_type, [jtype.JUnionType(list(union_types.values()))]
                )
            )

    def _get_dict_val_expr_type(self, node: ast.DictVal) -> jtype.JType:
        key_types: dict[str, jtype.JType] = {}
        values_types: dict[str, jtype.JType] = {}
        for kv in node.kv_pairs:
            k_type = self.get_type(kv.key)
            key_types[str(k_type)] = k_type
            v_type = self.get_type(kv.value)
            values_types[str(v_type)] = v_type
        if len(list(key_types.values())) == 1:
            k_type = list(key_types.values())[0]
        else:
            k_type = jtype.JUnionType(key_types.values())
        if len(list(values_types.values())) == 1:
            v_type = list(values_types.values())[0]
        else:
            v_type = jtype.JUnionType(values_types.values())
        dict_type = self.type_registry.get("builtins.dict")
        assert isinstance(dict_type, jtype.JClassType)
        return jtype.JClassInstanceType(jtype.JGenericType(dict_type, [k_type, v_type]))

    def set_type(
        self, node: ast.Expr, expr_type: jtype.JType, quite: bool = False
    ) -> None:
        """Set type from any jac expression based."""
        name = pascal_to_snake(node.__class__.__name__)
        func_name = f"_set_{name}_expr_type"

        if hasattr(self, func_name):
            if not quite:
                self.__debug_print(
                    f"Setting type {expr_type} to {node.loc.mod_path}:{node.loc}"
                )
            return getattr(self, func_name)(node, expr_type)
        else:
            self.__debug_print(f"{func_name} is not implemented yet")

    def _set_name_expr_type(self, node: ast.Name, expr_type: jtype.JType) -> None:
        assert node.name_spec.sym is not None
        node.name_spec.sym.jtype = expr_type

    def _set_name_atom_expr_type(
        self, node: ast.NameAtom, expr_type: jtype.JType
    ) -> None:
        assert node.sym is not None
        node.sym.jtype = expr_type

    def _set_special_var_ref_expr_type(
        self, node: ast.SpecialVarRef, expr_type: jtype.JType
    ) -> None:
        self._set_name_expr_type(node, expr_type)

    def _set_atom_trailer_expr_type(
        self, node: ast.AtomTrailer, expr_type: jtype.JType
    ) -> None:
        nodes = node.to_list
        assert isinstance(nodes[-1], ast.Expr)
        self.set_type(nodes[-1], expr_type, quite=True)

    def _set_binary_expr_expr_type(
        self, node: ast.AtomTrailer, expr_type: jtype.JType
    ) -> None:
        node.expr_type = expr_type

    def __get_list_type(self) -> jtype.JClassType:
        out = self.type_registry.get("builtins.list")
        assert isinstance(out, jtype.JClassType)
        return out

    def __get_dict_type(self) -> jtype.JClassType:
        out = self.type_registry.get("builtins.dict")
        assert isinstance(out, jtype.JClassType)
        return out
