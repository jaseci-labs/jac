import json
import os
from pathlib import Path

from jaclang.compiler.jtyping import (
    JClassInstanceType,
    JClassMember,
    JClassType,
    JFuncArgument,
    JFunctionType,
    JNoneType,
    JType,
    JTypeVar,
    JUnionType,
)
from jaclang.compiler.jtyping.types.jclassmember import MemberKind, Visibility


BUILTIN_PATH = Path(os.path.dirname(__file__)) / "builtins.json"


class JTypeRegistry:
    """
    Global registry for all user-defined and built-in types in the Jac type system.

    Types are indexed by their fully qualified name (e.g., 'builtins.int', 'mymod.MyClass').
    """

    def __init__(self) -> None:
        self._types: dict[str, JType] = {}
        self.__load_builtin_types()

    def register(self, type_obj: JClassType) -> None:
        """
        Register a type in the global registry.

        Args:
            type_obj (JType): The type to register.
        """
        self._types[type_obj.full_name] = type_obj

    def get(self, full_name: str) -> JType | None:
        """
        Retrieve a type by its fully qualified name.

        Args:
            full_name (str): The full name (e.g., 'builtins.str').

        Returns:
            JType | None: The registered type, or None if not found.
        """
        return self._types.get(full_name)

    def get_full_name(self, type_obj: JType) -> str:
        """
        Compute the fully qualified name for a type.

        Args:
            type_obj (JType): The type whose name to compute.

        Returns:
            str: Fully qualified name like 'builtins.int'.
        """
        mod = type_obj.module.name if type_obj.module else "unknown"
        return f"{mod}.{type_obj.name}"

    def all_types(self) -> list[JType]:
        """
        Retrieve all types currently registered in the type registry.

        Returns:
            list[JType]: A list of all registered types.
        """
        return list(self._types.values())

    def __load_builtin_types(self) -> None:
        """
        Load and register built-in types and their methods into the type registry.

        This method performs the following steps:
        1. Reads a JSON file defined by `BUILTIN_PATH`, allowing for comments (lines starting with `//`).
        2. Parses the cleaned JSON content to extract built-in type definitions.
        3. Registers each built-in type as a `JClassType`.
        4. For each built-in type, registers its methods by resolving argument and return types,
        including support for generic type variables.

        Raises:
            AssertionError: If a registered type is not an instance of `JClassType`.
        """
        with open(BUILTIN_PATH, "r") as file:
            # Remove comments (//) and collect cleaned lines
            lines = (line.split("//")[0].strip() for line in file)
            json_str = "\n".join(line for line in lines if line)
            builtin_types = json.loads(json_str)

            # Step 1: Register base class types first
            for type_name, type_info in builtin_types.items():
                generics_list: dict[str, JTypeVar] = {
                    t: JTypeVar(t) for t in type_info.get("generics", [])
                }
                class_type = JClassType(
                    name=type_name.split(".")[-1],  # short name
                    full_name=type_name,
                    module=None,
                    is_abstract=False,
                    instance_members={},
                    class_members={},
                    assignable_from=type_info.get("assignable_from", []),
                    generics=generics_list,
                )
                self.register(class_type)

            # Step 2: Register method signatures (with generic support)
            for type_name, type_info in builtin_types.items():
                full_name = type_name
                type_obj = self.get(full_name)
                assert isinstance(type_obj, JClassType)

                generics_dict = type_obj.generics_vars

                for method_name, sig in type_info.get("methods", {}).items():
                    args = sig.get("args", [])
                    ret = sig.get("return", "builtins.none")

                    method_type = self.__make_callable_type(
                        arg_types=args, return_type=ret, generics=generics_dict
                    )

                    type_obj.instance_members[method_name] = JClassMember(
                        name=method_name,
                        type=method_type,
                        kind=MemberKind.INSTANCE,
                        visibility=Visibility.PUBLIC,
                        is_method=True,
                        decl=None,
                    )

    def __make_callable_type(
        self,
        arg_types: list[list[str] | str],
        return_type: str,
        generics: dict[str, JTypeVar],
    ) -> JFunctionType:
        """
        Construct a `JFunctionType` from a list of argument types and a return type.

        This method builds a callable type signature, resolving type names to actual
        `JClassInstanceType` or `JUnionType` objects, and handles generic type variables.

        Args:
            arg_types (list[list[str] | str]):
                A list specifying the argument types:
                - A single string (e.g., "int") is treated as a single type.
                - A list of strings (e.g., ["int", "float"]) is treated as a union type.

                Each type string may refer to either a built-in type (found in `self._types`)
                or a type variable (found in `generics`).

            return_type (str):
                A string specifying the return type. It may be:
                - A built-in type (found in `self._types`)
                - A type variable (from `generics`)
                - An empty string, which implies `None` as the return type.

            generics (dict[str, JTypeVar]):
                A mapping of generic type variable names to their corresponding `JTypeVar` objects.

        Returns:
            JFunctionType:
                A callable type representation consisting of:
                - A list of `JFuncArgument` for parameters
                - A resolved return type (`JClassType`, `JTypeVar`, or `JNoneType`)
        """
        # Resolve the arg type from builtins json
        resolved_types: list[JType] = []
        for arg in arg_types:
            if isinstance(arg, list):
                union_types: list[JClassType | JClassInstanceType] = []
                for t in arg:
                    resolved_type = generics[t] if t in generics else self._types[t]
                    assert isinstance(resolved_type, JClassType | JTypeVar)
                    union_types.append(JClassInstanceType(resolved_type))
                resolved_types.append(JUnionType(union_types))
            else:
                resolved_type = generics[arg] if arg in generics else self._types[arg]
                assert isinstance(resolved_type, JClassType | JTypeVar)
                resolved_types.append(JClassInstanceType(resolved_type))

        # Create function arguments based on their types
        resolved_args: list[JFuncArgument] = [
            JFuncArgument(name=f"arg{i}", type=typ)
            for i, typ in enumerate(resolved_types)
        ]

        return JFunctionType(
            parameters=resolved_args,
            return_type=(
                JNoneType()
                if return_type == ""
                else (
                    generics[return_type]
                    if return_type in generics
                    else self._types[return_type]
                )
            ),
        )

    def __repr__(self) -> str:
        """
        Return a string representation of the JTypeRegistry instance.

        Returns:
            str: Summary of the registered types.
        """
        registered_types = ", ".join(sorted(self._types.keys()))
        return f"<JTypeRegistry: {len(self._types)} types registered: [{registered_types}]>"
