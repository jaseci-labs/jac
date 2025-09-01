"""
Type system evaluator for JacLang.

PyrightReference:
    packages/pyright-internal/src/analyzer/typeEvaluator.ts
    packages/pyright-internal/src/analyzer/typeEvaluatorTypes.ts
"""

from dataclasses import dataclass
from pathlib import Path
from typing import TYPE_CHECKING, cast

import jaclang.compiler.unitree as uni
from jaclang.compiler.type_system import types

if TYPE_CHECKING:
    from jaclang.compiler.program import JacProgram

from .type_utils import ClassMember
from .types import TypeBase


@dataclass
class PrefetchedTypes:
    """Types whose definitions are prefetched and cached by the type evaluator."""

    none_type_class: TypeBase | None = None
    object_class: TypeBase | None = None
    type_class: TypeBase | None = None
    union_type_class: TypeBase | None = None
    awaitable_class: TypeBase | None = None
    function_class: TypeBase | None = None
    method_class: TypeBase | None = None
    tuple_class: TypeBase | None = None
    bool_class: TypeBase | None = None
    int_class: TypeBase | None = None
    str_class: TypeBase | None = None
    dict_class: TypeBase | None = None
    module_type_class: TypeBase | None = None
    typed_dict_class: TypeBase | None = None
    typed_dict_private_class: TypeBase | None = None
    supports_keys_and_get_item_class: TypeBase | None = None
    mapping_class: TypeBase | None = None
    template_class: TypeBase | None = None


class TypeEvaluator:
    """Type evaluator for JacLang."""

    def __init__(self, builtins_module: uni.Module, program: "JacProgram") -> None:
        """Initialize the type evaluator with prefetched types.

        Implementation Note:
        --------------------
        Pyright is prefetching the builtins when an evaluation is requested
        on a node and from that node it does lookup for the builtins scope
        and does the prefetch once, however if we forgot to call prefetch
        in some place then it will not be available in the evaluator, So we
        are prefetching the builtins at the constructor level once.
        """
        self.builtins_module = builtins_module
        self.program = program
        self.prefetch = self._prefetch_types()

    # Pyright equivalent function name = getEffectiveTypeOfSymbol.
    def get_type_of_symbol(self, symbol: uni.Symbol) -> TypeBase:
        """Return the effective type of the symbol."""
        return self._get_type_of_symbol(symbol)

    # NOTE: This function doesn't exists in pyright, however it exists as a helper function
    # for the following functions.
    def _import_module_from_path(self, path: str) -> uni.Module:
        """Import a module from the given path."""
        # Get the module, if it's not loaded yet, compile and get it.
        #
        # TODO:
        # We're not typechecking inside the module itself however we
        # need to check if the module path is site-package or not and
        # do typecheck inside as well.
        mod: uni.Module
        if path in self.program.mod.hub:
            mod = self.program.mod.hub[path]
        else:
            mod = self.program.compile(path, no_cgen=True, type_check=False)
            # FIXME: Inherit from builtin symbol table logic is currently implemented
            # here and checker pass, however it should be in one location, since we're
            # doing type_check=False, it doesn't set parent_scope to builtins, this
            # needs to be done properly. The way jaclang handles symbol table is different
            # than pyright, so we cannot strictly follow them, however as long as a new
            # module has a parent scope as builtin scope, we're aligned with pyright.
            if mod.parent_scope is None and mod is not self.builtins_module:
                mod.parent_scope = self.builtins_module
        return mod

    def get_type_of_module(self, node: uni.ModulePath) -> types.ModuleType:
        """Return the effective type of the module."""
        if node.name_spec.type is not None:
            return cast(types.ModuleType, node.name_spec.type)

        mod: uni.Module = self._import_module_from_path(node.resolve_relative_path())
        mod_type = types.ModuleType(
            mod_name=node.name_spec.sym_name,
            file_uri=Path(node.resolve_relative_path()).resolve(),
            symbol_table=mod,
        )

        node.name_spec.type = mod_type
        return mod_type

    def get_type_of_module_item(self, node: uni.ModuleItem) -> types.TypeBase:
        """Return the effective type of the module item."""
        # Module item can be both a module or a member of a module.
        # import from .. { mod }   # <-- Here mod is not a member but a module itself.
        # import from mod { item } # <-- Here item is not a module but a member of mod.
        if node.name_spec.type is not None:
            return node.name_spec.type

        import_node = node.parent_of_type(uni.Import)
        if import_node.from_loc:

            from_path = Path(import_node.from_loc.resolve_relative_path())
            is_dir = from_path.is_dir() or (from_path.stem == "__init__")

            # import from .. { mod }
            if is_dir:
                mod_dir = from_path.parent if not from_path.is_dir() else from_path
                # FIXME: Implement module resolution properly.
                for ext in (".jac", ".py", ".pyi"):
                    if (path := (mod_dir / (node.name.value + ext)).resolve()).exists():
                        mod = self._import_module_from_path(str(path))
                        mod_type = types.ModuleType(
                            mod_name=node.name_spec.sym_name,
                            file_uri=path,
                            symbol_table=mod,
                        )
                        # Cache the type.
                        node.name_spec.type = mod_type

                        # FIXME: goto definition works on imported symbol by checking if it's a MODULE
                        # type and in that case it'll call resolve_relative_path on the parent node of
                        # the symbol's definition node (a module path), So the goto definition to work
                        # properly the category should be module on a module path, If we set like this
                        # below should work but because of the above assumption (should be a mod path)
                        # it won't, This needs to be discussed.
                        #
                        # node.name_spec._sym_category = uni.SymbolType.MODULE
                        return node.name_spec.type

            # import from mod { item }
            else:
                mod_type = self.get_type_of_module(import_node.from_loc)
                if sym := mod_type.symbol_table.lookup(node.name.value, deep=True):
                    node.name.sym = sym
                    if node.alias:
                        node.alias.sym = sym
                    node.name_spec.type = self.get_type_of_symbol(sym)
                    return node.name_spec.type

        return types.UnknownType()

    def get_type_of_class(self, node: uni.Archetype) -> types.ClassType:
        """Return the effective type of the class."""
        # Is this type already cached?
        if node.name_spec.type is not None:
            return cast(types.ClassType, node.name_spec.type)

        cls_type = types.ClassType(
            types.ClassType.ClassDetailsShared(
                class_name=node.name_spec.sym_name,
                symbol_table=node,
                # TODO: Resolve the base class expression and pass them here.
            ),
            flags=types.TypeFlags.Instantiable,
        )

        # Cache the type, pyright is doing invalidateTypeCacheIfCanceled()
        # we're not doing that any time sooner.
        node.name_spec.type = cls_type
        return cls_type

    def get_type_of_string(self, node: uni.String | uni.MultiString) -> TypeBase:
        """Return the effective type of the string."""
        # FIXME: Strings are a type of LiteralString type:
        # "foo" is not `str` but Literal["foo"], however for now we'll
        # not considering that and make it work and will implement that
        # later.
        #
        # see: getTypeOfString() in pyright (it requires parsing the sub
        # file of the typing module).
        assert self.prefetch.str_class is not None
        return self.prefetch.str_class

    def get_type_of_int(self, node: uni.Int) -> TypeBase:
        """Return the effective type of the int."""
        assert self.prefetch.int_class is not None
        return self.prefetch.int_class

    # Pyright equivalent function name = getTypeOfExpression();
    def get_type_of_expression(self, node: uni.Expr) -> TypeBase:
        """Return the effective type of the expression."""
        # If it's alreay "cached" return it.
        if node.type is not None:
            return node.type

        result = self._get_type_of_expression_core(node)
        # If the context has an expected type, pyright does a compatibility and set
        # a diagnostics here, I don't understand why that might be necessary here.

        node.type = result  # Cache the result
        return result

    # Comments from pyright:
    # // Determines if the source type can be assigned to the dest type.
    # // If constraint are provided, type variables within the destType are
    # // matched against existing type variables in the map. If a type variable
    # // in the dest type is not in the type map already, it is assigned a type
    # // and added to the map.
    def assign_type(self, src_type: TypeBase, dest_type: TypeBase) -> bool:
        """Assign the source type to the destination type."""
        if types.TypeCategory.Unknown in (src_type.category, dest_type.category):
            # NOTE: For now if we don't have the type info, we assume it's compatible.
            # For strict mode we should disallow usage of unknown unless explicitly ignored.
            return True
        # FIXME: This logic is not valid, just here as a stub.
        if types.TypeCategory.Unknown in (src_type.category, dest_type.category):
            return True

        if src_type == dest_type:
            return True

        if dest_type.is_class_instance() and src_type.is_class_instance():
            assert isinstance(dest_type, types.ClassType)
            assert isinstance(src_type, types.ClassType)
            return self._assign_class(src_type, dest_type)

        # FIXME: This is temporary.
        return src_type == dest_type

    def _assign_class(
        self, src_type: types.ClassType, dest_type: types.ClassType
    ) -> bool:
        """Assign the source class type to the destination class type."""
        if src_type.shared == dest_type.shared:
            return True

        # TODO: Search base classes and everything else pyright is doing.
        return False

    def _prefetch_types(self) -> "PrefetchedTypes":
        """Return the prefetched types for the type evaluator."""
        return PrefetchedTypes(
            # TODO: Pyright first try load NoneType from typeshed and if it cannot
            # then it set to unknown type.
            none_type_class=types.UnknownType(),
            object_class=self._get_builtin_type("object"),
            type_class=self._get_builtin_type("type"),
            # union_type_class=
            # awaitable_class=
            # function_class=
            # method_class=
            tuple_class=self._get_builtin_type("tuple"),
            bool_class=self._get_builtin_type("bool"),
            int_class=self._get_builtin_type("int"),
            str_class=self._get_builtin_type("str"),
            dict_class=self._get_builtin_type("dict"),
            # module_type_class=
            # typed_dict_class=
            # typed_dict_private_class=
            # supports_keys_and_get_item_class=
            # mapping_class=
            # template_class=
        )

    def _get_builtin_type(self, name: str) -> TypeBase:
        """Return the built-in type with the given name."""
        if (symbol := self.builtins_module.lookup(name)) is not None:
            return self.get_type_of_symbol(symbol)
        return types.UnknownType()

    # This function is a combination of the bellow pyright functions.
    #  - getDeclaredTypeOfSymbol
    #  - getTypeForDeclaration
    #
    # Implementation Note:
    # Pyright is actually have some duplicate logic for handling declared
    # type and inferred type, we're going to unify them (if it's required
    # in the future, we can refactor this).
    def _get_type_of_symbol(self, symbol: uni.Symbol) -> TypeBase:
        """Return the declared type of the symbol."""
        node = symbol.decl.name_of
        match node:
            case uni.ModulePath():
                return self.get_type_of_module(node)

            case uni.ModuleItem():
                return self.get_type_of_module_item(node)

            case uni.Archetype():
                return self.get_type_of_class(node)

            # This actually defined in the function getTypeForDeclaration();
            # Pyright has DeclarationType.Variable.
            case uni.Name():
                if isinstance(node.parent, uni.Assignment):
                    if node.parent.type_tag is not None:
                        annotation_type = self.get_type_of_expression(
                            node.parent.type_tag.tag
                        )
                        return self._convert_to_instance(annotation_type)

                    else:  # Assignment without a type annotation.
                        if node.parent.value is not None:
                            return self.get_type_of_expression(node.parent.value)

            case uni.HasVar():
                if node.type_tag is not None:
                    annotation_type = self.get_type_of_expression(node.type_tag.tag)
                    return self._convert_to_instance(annotation_type)
                else:
                    if node.value is not None:
                        return self.get_type_of_expression(node.value)

            # TODO: Implement for functions, parameters, explicit type
            # annotations in assignment etc.
        return types.UnknownType()

    # Pyright equivalent function name = getTypeOfExpressionCore();
    def _get_type_of_expression_core(self, expr: uni.Expr) -> TypeBase:
        """Core function to get the type of the expression."""
        match expr:

            case uni.String() | uni.MultiString():
                return self._convert_to_instance(self.get_type_of_string(expr))

            case uni.Int():
                return self._convert_to_instance(self.get_type_of_int(expr))

            case uni.AtomTrailer():
                # NOTE: Pyright is using CFG to figure out the member type by narrowing the base
                # type and filtering the members. We're not doing that anytime sooner.
                base_type = self.get_type_of_expression(expr.target)

                if expr.is_attr:  # <expr>.member
                    assert isinstance(expr.right, uni.Name)

                    if isinstance(base_type, types.ModuleType):
                        # getTypeOfMemberAccessWithBaseType()
                        if sym := base_type.symbol_table.lookup(
                            expr.right.value, deep=True
                        ):
                            expr.right.sym = sym
                            return self.get_type_of_symbol(sym)
                        return types.UnknownType()

                    elif base_type.is_instantiable_class():
                        assert isinstance(base_type, types.ClassType)
                        if member := self._lookup_class_member(
                            base_type, expr.right.value
                        ):
                            expr.right.sym = member.symbol
                            return self.get_type_of_symbol(member.symbol)
                        return types.UnknownType()

                    elif base_type.is_class_instance():
                        assert isinstance(base_type, types.ClassType)
                        if member := self._lookup_object_member(
                            base_type, expr.right.value
                        ):
                            expr.right.sym = member.symbol
                            return self.get_type_of_symbol(member.symbol)
                        return types.UnknownType()

                elif expr.is_null_ok:  # <expr>?.member
                    pass  # TODO:

                else:  # <expr>[<expr>]
                    pass  # TODO:

            case uni.Name():
                if symbol := expr.sym_tab.lookup(expr.value, deep=True):
                    return self.get_type_of_symbol(symbol)

            # TODO: More expressions.
        return types.UnknownType()

    def _convert_to_instance(self, jtype: TypeBase) -> TypeBase:
        """Convert a class type to an instance type."""
        # TODO: Grep pyright "Handle type[x] as a special case." They handle `type[x]` as a special case:
        #
        # foo: int = 42;       # <-- Here `int` is instantiable class and, become instance after this method.
        # foo: type[int] = int # <-- Here `type[int]`, this should be `int` that's instantiable.
        #
        if jtype.is_instantiable_class():
            assert isinstance(jtype, types.ClassType)
            return jtype.clone_as_instance()
        return jtype

    def _lookup_class_member(
        self, base_type: types.ClassType, member: str
    ) -> ClassMember | None:
        """Lookup the class member type."""
        assert self.prefetch.int_class is not None
        # FIXME: Pyright's way: Implement class member iterator (based on mro and the multiple inheritance)
        # return the first found member from the iterator.

        # NOTE: This is a simple implementation to make it work and more robust implementation will
        # be done in a future PR.
        if sym := base_type.lookup_member_symbol(member):
            return ClassMember(sym, base_type)
        return None

    def _lookup_object_member(
        self, base_type: types.ClassType, member: str
    ) -> ClassMember | None:
        """Lookup the object member type."""
        assert self.prefetch.int_class is not None
        if base_type.is_class_instance():
            assert isinstance(base_type, types.ClassType)
            # TODO: We need to implement Member lookup flags and set SkipInstanceMember to 0.
            return self._lookup_class_member(base_type, member)
        return None
