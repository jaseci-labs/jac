"""Semantic analysis for Jac language."""

from contextlib import suppress
from typing import cast

import jaclang.compiler.jtyping as jtype
import jaclang.compiler.unitree as ast
from jaclang.compiler.jtyping.types.jclassmember import MemberKind
from jaclang.compiler.jtyping.types.jtype import _BINARY_OPERATOR_METHODS
from jaclang.compiler.passes import UniPass
from jaclang.settings import settings


class JTypeCheckPass(UniPass):
    """Jac pass for semantic analysis."""

    def before_pass(self) -> None:
        """Do setup pass vars."""  # noqa D403, D401
        # TODO: Change this to use the errors_had infrastructure
        if not settings.enable_jac_semantics:
            self.terminate()
        if self.ir_in.name == "builtins":
            self.terminate()
        return super().before_pass()

    def __debug_print(self, msg: str) -> None:
        if settings.debug_jac_typing:
            print("[JTypeCheckPass]", msg)

    ####################################################
    # Safety mechanism to disable crashes at user side #
    ####################################################
    def enter_node(self, node: ast.UniNode) -> None:
        """Enter Node"""
        if settings.enable_jac_typing_asserts:
            try:
                super().enter_node(node)
            except AssertionError as e:
                raise AssertionError(
                    f"{node.loc.mod_path} {node.loc} {str(e)}"
                ).with_traceback(e.__traceback__)
        else:
            with suppress(Exception):
                super().enter_node(node)

    def exit_node(self, node: ast.UniNode) -> None:
        """Exit node."""
        if settings.enable_jac_typing_asserts:
            try:
                super().exit_node(node)
            except AssertionError as e:
                raise AssertionError(
                    f"{node.loc.mod_path} {node.loc}: {str(e)}"
                ).with_traceback(e.__traceback__)
        else:
            with suppress(Exception):
                super().exit_node(node)

    #############
    # Abilities #
    #############
    def exit_return_stmt(self, node: ast.ReturnStmt) -> None:
        """Check the return var type across the annotated return type."""
        return_type = self.prog.type_resolver.get_type(node.expr)

        func_decl = ast.find_parent_of_type(node, ast.Ability)
        if not func_decl:
            self.log_error(
                "Return statement not inside an ability, can't check return type"
            )
            return
        sig_ret_type = self.prog.type_resolver.get_type(func_decl.name_spec)

        if isinstance(func_decl.signature, ast.EventSignature):
            self.log_warning(
                "return from function with event signeature is not supported yet"
            )
            return

        assert isinstance(sig_ret_type, jtype.JFunctionType)
        sig_ret_type = sig_ret_type.return_type

        if return_type and isinstance(sig_ret_type, jtype.JNoneType):
            self.log_warning(
                "Ability has a return type however it's defined as None type"
            )

        elif not sig_ret_type.can_assign_from(return_type):
            self.log_error(
                f"Ability have a return type {sig_ret_type} but got assigned a type {return_type}"
            )

    #################
    # Ability calls #
    #################
    def exit_func_call(self, node: ast.FuncCall) -> None:
        """Check the vars used as actual parameters across the formal parameters."""
        assert isinstance(node.target, (ast.NameAtom, ast.AtomTrailer))

        if isinstance(node.target, ast.NameAtom) and node.target.name_spec.sym is None:
            self.__debug_print(
                f"Ignoring function call {node.unparse()}, no symbol linked to it"
            )
            return

        callable_type = self.prog.type_resolver.get_type(node.target)

        if isinstance(callable_type, jtype.JAnyType):
            # if constructor is called through super and it was generated internally by Jac then we
            # need this work arround as there is no symbol for this constructor
            if (
                isinstance(node.target, ast.AtomTrailer)
                and node.target.as_attr_list[-1].sym_name == "__init__"
                and node.target.as_attr_list[-2].sym_name == "super"
            ):
                assert isinstance(node.target.as_attr_list[-2], ast.Name)
                assert node.target.as_attr_list[-2].sym is not None
                class_inst_type = self.prog.type_resolver.get_type(
                    node.target.as_attr_list[-2]
                )
                assert isinstance(class_inst_type, jtype.JClassInstanceType)
                if isinstance(class_inst_type.class_type, jtype.JGenericType):
                    base_class = class_inst_type.class_type.base
                elif isinstance(class_inst_type.class_type, jtype.JTypeVar):
                    raise AssertionError()
                else:
                    base_class = class_inst_type.class_type
                callable_type = base_class.get_callable_signature()
            else:
                self.__debug_print("AnyType target func call!!!")
                return

        assert isinstance(callable_type, (jtype.JFunctionType, jtype.JClassType))

        if isinstance(callable_type, jtype.JClassType):
            if callable_type.is_abstract:
                self.log_error("Can't create an object from an abstract class")
                return
            else:
                callable_type = callable_type.get_callable_signature()

        func_params = {a.name: a.type for a in callable_type.parameters}

        actual_params = node.params
        actual_items = actual_params if actual_params else []

        kw_args_seen = False
        arg_count = 0

        for actual, formal in zip(actual_items, func_params.values()):
            arg_name = ""

            if isinstance(actual, ast.Expr):
                assert kw_args_seen is False
                actual_type = self.prog.type_resolver.get_type(actual)
                arg_name = list(func_params.keys())[arg_count]
                arg_count += 1

            # TODO: Check that all the keys are valid keys in semantic analysis pass
            elif isinstance(actual, ast.KWPair):
                kw_args_seen = True
                actual_type = self.prog.type_resolver.get_type(actual.value)
                assert actual.key is not None
                arg_name = actual.key.sym_name
                formal = func_params[arg_name]

            if not formal.can_assign_from(actual_type):
                self.log_error(
                    f"Can't assign a value {actual_type} to a parameter '{arg_name}' of type {formal}"
                )

    ##################################
    # Assignments & Var delcarations #
    ##################################
    def exit_assignment(self, node: ast.Assignment) -> None:
        """Set var type & check the value type across the var annotated type."""
        value = node.value

        # if no value is assigned then no need to do type check
        if not value:
            return

        value_type = self.prog.type_resolver.get_type(value)
        # handle multiple assignment targets
        for target in node.target:

            # check target expression types
            if isinstance(target, ast.FuncCall):
                self.log_error(
                    f"Expression '{target.unparse()}' can't be assigned (not a valid ltype)"
                )
                continue

            sym_type = self.prog.type_resolver.get_type(target)
            if not sym_type.can_assign_from(value_type):
                self.log_error(
                    f"Can't assign a value {value_type} to a {sym_type} object"
                )

            # if the variable has no annotation and this is the first assignment for it
            # then set the var type to the val type
            if isinstance(sym_type, jtype.JAnyType) and (
                (isinstance(target, ast.Name) and target.name_spec is target)
                or (
                    isinstance(target, ast.AtomTrailer)
                    and isinstance(target.as_attr_list[-1], ast.AstSymbolNode)
                    and target.as_attr_list[-1].name_spec is target.as_attr_list[-1]
                    and target.as_attr_list[-1].name_spec.sym
                )
            ):
                self.prog.type_resolver.set_type(target, value_type)

    #####################
    ### Atom Trailers ###
    #####################
    def enter_atom_trailer(self, node: ast.AtomTrailer) -> None:
        """
        Resolve and validate chained attribute access expressions (e.g., `a.b.c`) in the AST.

        This method performs static type checking for a sequence of chained access expressions,
        which may include attribute accesses, function calls, and index operations. It performs:

        1. Type resolution of the base object (first node in the chain).
        2. Step-by-step traversal through each subsequent element in the chain.
        3. Verification that each element is a valid member on the current type.
        4. Symbol binding for each resolved member to update the AST with type information.

        Args:
            node (ast.AtomTrailer): The AST node representing a chain of accesses.

        Raises / Logs:
            - An error if a member in the chain does not exist on the current type.
            - An error if a non-instance/class/generic type is used in a chain.
            - A debug message if unsupported node types (like `EdgeRefTrailer`) are encountered.
        """
        if any(
            not isinstance(i, ast.Name | ast.FuncCall | ast.IndexSlice)
            for i in node.to_list
        ):
            self.__debug_print(
                "EdgeRefTrailer are not supported yet, ignoring this node"
            )
            return

        for n in node.to_list:
            assert isinstance(
                n, (ast.Name | ast.FuncCall | ast.IndexSlice)
            ), f"Expected all Name or FuncCall, Found {n} --> {n.loc.mod_path} {n.loc}"
        nodes = cast(
            list[ast.Name | ast.FuncCall],
            node.to_list,
        )

        if isinstance(nodes[0], ast.FuncCall) and isinstance(
            nodes[0].target, ast.AtomTrailer
        ):
            self.enter_atom_trailer(nodes[0].target)

        first_item_type = self.prog.type_resolver.get_type(
            nodes[0]
        )  # Resolve type of base object.

        last_node_type: jtype.JClassInstanceType | jtype.JClassType | jtype.JGenericType
        next_type: jtype.JType = first_item_type

        # Iterate through each attribute in the chain (excluding the first base object).
        for n in nodes[1:]:
            # Ensure the current type can have members.
            if not isinstance(
                next_type,
                (jtype.JClassInstanceType, jtype.JClassType, jtype.JGenericType),
            ):
                self.log_error(
                    f"Can't access a field from an object of type {type(next_type)} {n}"
                )
                return
            else:
                assert isinstance(
                    next_type,
                    jtype.JClassInstanceType | jtype.JClassType | jtype.JGenericType,
                )
                last_node_type = next_type

            if isinstance(n, ast.FuncCall):
                assert isinstance(n.target, ast.Name)
                node_name = n.target.sym_name
            elif isinstance(n, ast.IndexSlice):
                node_name = "__getitem__"
            else:
                node_name = n.sym_name
            member = last_node_type.get_member(node_name)

            if (
                member
                and isinstance(last_node_type, jtype.JClassType)
                and member.kind == MemberKind.INSTANCE
            ):
                member = None

            if member is None:
                # Attribute doesn't exist; log an error with context.
                self.log_error(
                    f"No member called '{node_name}' in {last_node_type} object",
                    node_override=n,
                )
                break
            else:
                # Update type for the next iteration and store the resolved symbol.
                next_type = member.type
                if isinstance(n, ast.FuncCall):
                    assert isinstance(n.target, ast.Name)
                    n.target.name_spec._sym = member.decl
                else:
                    n.name_spec._sym = member.decl
                    # No symbols for builtin methods, auto generate the missing
                    # symbols
                    # TODO: This should be moved to symbol table build pass not here
                    if n.name_spec.sym is None:
                        s = ast.Symbol(
                            ast.NameAtom(False),
                            access=ast.SymbolAccess.PUBLIC,
                            parent_tab=ast.UniScopeNode("AUTO_GEN"),
                        )
                        s.jtype = member.type
                        n.name_spec.sym = s

                    if isinstance(n, ast.IndexSlice):
                        assert isinstance(member.type, jtype.JFunctionType)
                        next_type = member.type.return_type

    def exit_index_slice(self, node: ast.IndexSlice) -> None:
        """
        Type checks a runtime index expression (e.g., `obj[index]`) when not in annotation context.

        This method performs type validation for subscript/indexing operations by:
        1. Resolving the base type being indexed (e.g., the object before `[...]`).
        2. Resolving the type(s) of the index expression(s).
        3. Checking if the base type defines a `__getitem__` method.
        4. Verifying that the number and types of index arguments match the method signature.

        This logic is only applied outside type annotations (e.g., `List[int]` is handled in resolver).

        Args:
            node (ast.IndexSlice): The AST node representing the indexing operation.

        Logs:
            - An error if the number of index arguments does not match the callable signature.
            - An error if the index argument types are incompatible.
            - An error if the base type lacks a `__getitem__` method.
        """
        parent = node.parent
        assert isinstance(parent, ast.AtomTrailer)
        base_type = self.prog.type_resolver.get_type(parent.to_list[-2])
        if isinstance(base_type, jtype.JAnyType):
            self.log_warning("This node is not supported yet")
            return
        assert isinstance(base_type, jtype.JClassInstanceType)

        indexes = []
        if isinstance(node.slices[0].start, ast.TupleVal):
            for v in node.slices[0].start.values:
                assert isinstance(v, ast.Expr)
                indexes.append(self.prog.type_resolver.get_type(v))
        else:
            indexes = [self.prog.type_resolver.get_type(node.slices[0].start)]

        is_annotation = node.find_parent_of_type(
            ast.SubTag
        ) or node.find_parent_of_type(ast.FuncSignature)
        if not is_annotation:
            index_method = base_type.get_member("__getitem__")
            if index_method and isinstance(index_method.type, jtype.JFunctionType):
                params = index_method.type.parameters
                if len(params) != len(indexes):
                    self.log_error(
                        f"Object of type {base_type} supports {len(params)} indicies, suppliied number is {len(indexes)}"
                    )
                for p, i in zip(params, indexes):
                    if not p.type.can_assign_from(i):
                        self.log_error(
                            f"Can't assign an index of type {p.type} with a value of type {i}"
                        )
            else:
                self.log_error(
                    f"Object of type {base_type} doesn't support item assignment"
                )

    ###############################
    ### Binary/Bool Expressions ###
    ###############################
    def exit_binary_expr(self, node: ast.BinaryExpr) -> None:
        """
        Perform type checking for a binary expression node during AST traversal.

        This function is called after visiting a binary expression node. It resolves
        the types of the left and right operands and checks if the binary operator
        is supported for the given types.

        Type checking is skipped for:
        - Binary expressions used within type annotation contexts (e.g., `int | str`).
        - Operands of type `Any`.
        - Operands involving user-defined class types (binary ops are disallowed).

        Supported operations are resolved through method dispatch on the left-hand
        operand. If the operator is overloaded and the right-hand operand type is
        assignable to the expected parameter, the result type is inferred. Implicit
        promotion from int to float is supported for arithmetic operations.

        Args:
            node (ast.BinaryExpr): The binary expression AST node to type check.

        Raises:
            AssertionError: If the operator function or its type is unexpectedly missing.
            Logs errors and warnings for unsupported operations or invalid type combinations.
        """
        # Ignore type checking in case of type annotations expressions
        # this will prevert issues like or not supported for a: int | str
        if isinstance(node.parent, ast.SubTag):
            return

        if isinstance(node.op, ast.Token):
            type1 = self.prog.type_resolver.get_type(node.left)
            type2 = self.prog.type_resolver.get_type(node.right)

            if isinstance(type1, jtype.JAnyType) or isinstance(type2, jtype.JAnyType):
                self.log_warning("Type checking is not supported here!!")
                return

            if isinstance(type1, jtype.JClassType) or isinstance(
                type2, jtype.JClassType
            ):
                self.log_warning("Binary expressions is not supported on class types")
                return

            assert isinstance(type1, jtype.JClassInstanceType)
            assert isinstance(type2, jtype.JClassInstanceType)
            if type1.supports_binary_op(node.op.name):
                op_function = type1.get_member(_BINARY_OPERATOR_METHODS[node.op.name])
                assert op_function is not None
                op_function_type = op_function.type
                assert isinstance(op_function_type, jtype.JFunctionType)
                assert len(op_function_type.parameters) == 1

                if op_function_type.parameters[0].type.can_assign_from(type2):
                    if node.op.name in ["PLUS", "MINUS", "MUL"] and (
                        (
                            type1.class_type.name == "float"
                            and type2.class_type.name == "int"
                        )
                        or (
                            type2.class_type.name == "float"
                            and type1.class_type.name == "int"
                        )
                    ):
                        float_type = self.prog.type_registry.get("builtins.float")
                        assert isinstance(float_type, jtype.JClassType)

                        self.prog.type_resolver.set_type(
                            node, jtype.JClassInstanceType(float_type)
                        )
                    else:
                        assert isinstance(
                            op_function_type.return_type, jtype.JClassType
                        )
                        self.prog.type_resolver.set_type(
                            node, jtype.JClassInstanceType(op_function_type.return_type)
                        )
                else:
                    self.log_error(
                        f"Unsupported type {type2} for binary operation '{node.op.name}'  on type {type1}"
                    )
            else:
                self.log_error(
                    f"Unsupported binary operation '{node.op.name}' on type {type1}"
                )
        else:
            self.__debug_print(
                f"Normal binary operation are supported for now {node.op}"
            )

    # def after_pass(self):
    #     print(self.prog.type_registry)
