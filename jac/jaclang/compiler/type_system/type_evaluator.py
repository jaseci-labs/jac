"""
Type system evaluator for JacLang.

PyrightReference:
    packages/pyright-internal/src/analyzer/typeEvaluator.ts
    packages/pyright-internal/src/analyzer/typeEvaluatorTypes.ts
"""

import ast as py_ast
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, TYPE_CHECKING, cast

import jaclang.compiler.unitree as uni
from jaclang.compiler import TOKEN_MAP
from jaclang.compiler.constant import Tokens as Tok
from jaclang.compiler.passes.main.pyast_load_pass import PyastBuildPass
from jaclang.compiler.passes.main.sym_tab_build_pass import SymTabBuildPass
from jaclang.compiler.type_system import types
from jaclang.runtimelib.utils import read_file_with_encoding

if TYPE_CHECKING:
    from jaclang.compiler.program import JacProgram

from . import operations
from . import type_utils
from .types import TypeBase

# The callback type definition for the diagnostic messages.
DiagnosticCallback = Callable[[uni.UniNode, str, bool], None]


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
    float_class: TypeBase | None = None
    str_class: TypeBase | None = None
    dict_class: TypeBase | None = None
    module_type_class: TypeBase | None = None
    typed_dict_class: TypeBase | None = None
    typed_dict_private_class: TypeBase | None = None
    supports_keys_and_get_item_class: TypeBase | None = None
    mapping_class: TypeBase | None = None
    template_class: TypeBase | None = None


@dataclass
class SymbolResolutionStackEntry:
    """Represents a single entry in the symbol resolution stack."""

    symbol: uni.Symbol

    # Initially true, it's set to false if a recursion
    # is detected.
    is_result_valid: bool = True

    # Some limited forms of recursion are allowed. In these
    # cases, a partially-constructed type can be registered.
    partial_type: TypeBase | None = None


@dataclass
class MatchArgsToParamsResult:
    """Result of matching arguments to parameters."""

    # FIXME: This class implementation is modified from pyright to make it
    # simple and work for now, however this needs to be revisited and
    # implemented properly.
    arg_params: dict[uni.Expr | uni.KWPair, types.Parameter | None]

    overload: types.FunctionType | None = None
    argument_errors: bool = False


class TypeEvaluator:
    """Type evaluator for JacLang."""

    # NOTE: This is done in the binder pass of pyright, however I'm doing this
    # here, cause this will be the entry point of the type checker and we're not
    # relying on the binder pass at the moment and we can go back to binder pass
    # in the future if we needed it.
    _BUILTINS_STUB_FILE_PATH = os.path.join(
        os.path.dirname(__file__),
        "../../vendor/typeshed/stdlib/builtins.pyi",
    )

    def __init__(
        self,
        program: "JacProgram",
    ) -> None:
        """Initialize the type evaluator with prefetched types.

        Implementation Note:
        --------------------
        Pyright is prefetching the builtins when an evaluation is requested
        on a node and from that node it does lookup for the builtins scope
        and does the prefetch once, however if we forgot to call prefetch
        in some place then it will not be available in the evaluator, So we
        are prefetching the builtins at the constructor level once.
        """
        self.program = program
        self.symbol_resolution_stack: list[SymbolResolutionStackEntry] = []
        self.builtins_module = self._load_builtins_stub_module()
        self.prefetch = self._prefetch_types()
        self.diagnostic_callback: DiagnosticCallback | None = None

    def _load_builtins_stub_module(self) -> uni.Module:
        """Load and return the builtins stub module."""
        if not os.path.exists(TypeEvaluator._BUILTINS_STUB_FILE_PATH):
            raise FileNotFoundError(
                f"Builtins stub file not found at {TypeEvaluator._BUILTINS_STUB_FILE_PATH}"
            )
        file_content = read_file_with_encoding(TypeEvaluator._BUILTINS_STUB_FILE_PATH)
        uni_source = uni.Source(file_content, TypeEvaluator._BUILTINS_STUB_FILE_PATH)
        mod = PyastBuildPass(
            ir_in=uni.PythonModuleAst(
                py_ast.parse(file_content),
                orig_src=uni_source,
            ),
            prog=self.program,
        ).ir_out
        SymTabBuildPass(ir_in=mod, prog=self.program)
        return mod

    def _get_builtin_type(self, name: str) -> TypeBase:
        """Return the built-in type with the given name."""
        if (symbol := self.builtins_module.lookup(name)) is not None:
            return self.get_type_of_symbol(symbol)
        return types.UnknownType()

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
            float_class=self._get_builtin_type("float"),
            str_class=self._get_builtin_type("str"),
            dict_class=self._get_builtin_type("dict"),
            # module_type_class=
            # typed_dict_class=
            # typed_dict_private_class=
            # supports_keys_and_get_item_class=
            # mapping_class=
            # template_class=
        )

    def add_diagnostic(
        self, node: uni.UniNode, message: str, warning: bool = False
    ) -> None:
        """Add a diagnostic message to the program."""
        if self.diagnostic_callback:
            self.diagnostic_callback(node, message, warning)

    # -------------------------------------------------------------------------
    # Symbol resolution stack
    # -------------------------------------------------------------------------

    def get_index_of_symbol_resolution(self, symbol: uni.Symbol) -> int | None:
        """Get the index of a symbol in the resolution stack."""
        for i, entry in enumerate(self.symbol_resolution_stack):
            if entry.symbol == symbol:
                return i
        return None

    def push_symbol_resolution(self, symbol: uni.Symbol) -> bool:
        """
        Push a symbol onto the resolution stack.

        Return False if recursion detected and in that case it won't push the symbol.
        """
        idx = self.get_index_of_symbol_resolution(symbol)
        if idx is not None:
            # Mark all of the entries between these two as invalid.
            for i in range(idx, len(self.symbol_resolution_stack)):
                entry = self.symbol_resolution_stack[i]
                entry.is_result_valid = False
            return False
        self.symbol_resolution_stack.append(SymbolResolutionStackEntry(symbol=symbol))
        return True

    def pop_symbol_resolution(self, symbol: uni.Symbol) -> bool:
        """Pop a symbol from the resolution stack."""
        popped_entry = self.symbol_resolution_stack.pop()
        assert popped_entry.symbol == symbol
        return popped_entry.is_result_valid

    # Pyright equivalent function name = getEffectiveTypeOfSymbol.
    def get_type_of_symbol(self, symbol: uni.Symbol) -> TypeBase:
        """Return the effective type of the symbol."""
        if self.push_symbol_resolution(symbol):
            try:
                return self._get_type_of_symbol(symbol)
            finally:
                self.pop_symbol_resolution(symbol)

        # If we reached here that means we have a cyclic symbolic reference.
        return types.UnknownType()

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

    def get_type_of_module(self, node: uni.ModulePath) -> types.TypeBase:
        """Return the effective type of the module."""
        if node.name_spec.type is not None:
            return cast(types.ModuleType, node.name_spec.type)
        if not Path(node.resolve_relative_path()).exists():
            node.name_spec.type = types.UnknownType()
            return node.name_spec.type

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
                if not isinstance(mod_type, types.ModuleType):
                    node.name_spec.type = types.UnknownType()
                    # TODO: Add diagnostic that from_loc is not accessible.
                    # Eg: 'Import "scipy" could not be resolved'
                    return node.name_spec.type
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

        base_classes: list[TypeBase] = []
        for base_class in node.base_classes or []:
            base_class_type = self.get_type_of_expression(base_class)
            base_classes.append(base_class_type)
        is_builtin_class = node.find_parent_of_type(uni.Module) == self.builtins_module

        cls_type = types.ClassType(
            types.ClassType.ClassDetailsShared(
                class_name=node.name_spec.sym_name,
                symbol_table=node,
                base_classes=base_classes,
                is_builtin_class=is_builtin_class,
            ),
            flags=types.TypeFlags.Instantiable,
        )

        # Compute the MRO for the class.
        type_utils.compute_mro_linearization(cls_type)

        # Cache the type, pyright is doing invalidateTypeCacheIfCanceled()
        # we're not doing that any time sooner.
        node.name_spec.type = cls_type
        return cls_type

    def get_type_of_ability(self, node: uni.Ability) -> TypeBase:
        """Return the effective type of an ability."""
        if node.name_spec.type is not None:
            return node.name_spec.type

        if not isinstance(node.signature, uni.FuncSignature):
            node.name_spec.type = types.UnknownType()
            return node.name_spec.type

        return_type: TypeBase
        if isinstance(node.signature.return_type, uni.Expr):
            return_type = self._convert_to_instance(
                self.get_type_of_expression(node.signature.return_type)
            )
        else:
            return_type = types.UnknownType()

        # Define helper function for parameter conversion.
        def _get_param_category(param: uni.ParamVar) -> types.ParameterCategory:
            if param.is_vararg:
                return types.ParameterCategory.ArgsList
            if param.is_kwargs:
                return types.ParameterCategory.KwargsDict
            return types.ParameterCategory.Positional

        # Define helper function for parameter kind conversion.
        def _convert_param_kind(kind: uni.ParamKind) -> types.ParamKind:
            match kind:
                case uni.ParamKind.POSONLY:
                    return types.ParamKind.POSONLY
                case uni.ParamKind.NORMAL:
                    return types.ParamKind.NORMAL
                case uni.ParamKind.VARARG:
                    return types.ParamKind.VARARG
                case uni.ParamKind.KWONLY:
                    return types.ParamKind.KWONLY
                case uni.ParamKind.KWARG:
                    return types.ParamKind.KWARG
            return types.ParamKind.NORMAL

        parameters: list[types.Parameter] = []
        for idx, param in enumerate(node.signature.get_parameters()):
            # TODO: Set parameter category for *args, and **kwargs
            param_type: TypeBase | None = None

            if param.type_tag:
                param_type_cls = self.get_type_of_expression(param.type_tag.tag)
                param_type = self._convert_to_instance(param_type_cls)

            parameters.append(
                types.Parameter(
                    name=param.name.value,
                    category=_get_param_category(param),
                    param_type=param_type,
                    default_value=param.value,
                    is_self=(idx == 0 and self._is_expr_self(param.name)),
                    param_kind=_convert_param_kind(param.param_kind),
                )
            )

        func_type = types.FunctionType(
            func_name=node.name_spec.sym_name,
            return_type=return_type,
            parameters=parameters,
        )

        node.name_spec.type = func_type
        return func_type

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

    def get_type_of_float(self, node: uni.Float) -> TypeBase:
        """Return the effective type of the float."""
        assert self.prefetch.float_class is not None
        return self.prefetch.float_class

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

        if src_type == dest_type:
            return True

        if dest_type.is_class_instance() and src_type.is_class_instance():
            assert isinstance(dest_type, types.ClassType)
            assert isinstance(src_type, types.ClassType)
            return self._assign_class(src_type, dest_type)

        return False

    # TODO: This should take an argument list as parameter.
    def get_type_of_magic_method_call(
        self, obj_type: TypeBase, method_name: str
    ) -> TypeBase | None:
        """Return the effective return type of a magic method call."""
        if obj_type.category == types.TypeCategory.Class:
            # TODO: getTypeOfBoundMember() <-- Implement this if needed, for the simple case
            # we'll directly call member lookup.
            #
            # WE'RE DAVIATING FROM PYRIGHT FOR THIS METHOD HEAVILY HOWEVER THIS CAN BE RE-WRITTEN IF NEEDED.
            #
            assert isinstance(obj_type, types.ClassType)  # <-- To make typecheck happy.
            if member := self._lookup_class_member(obj_type, method_name):
                member_ty = self.get_type_of_symbol(member.symbol)
                if isinstance(member_ty, types.FunctionType):
                    return member_ty.return_type
                # If we reached here, magic method is not a function.
                # 1. recursively check __call__() on the type, TODO
                # 2. if any or unknown, return getUnknownTypeForCallable() TODO
                # 3. return undefined.
                return None
        return None

    def _assign_class(
        self, src_type: types.ClassType, dest_type: types.ClassType
    ) -> bool:
        """Assign the source class type to the destination class type."""
        if src_type.shared == dest_type.shared:
            return True

        # Check if src class is a subclass of dest class.
        for base_cls in src_type.shared.mro:
            if base_cls.shared == dest_type.shared:
                return True

        # Everything is assignable to an object.
        if dest_type.is_builtin("object"):
            # TODO: Invariance not handled yet
            # invariant contexts to avoid list[int] <: list[object] errors.
            return True

        # Integers can be used where floats are expected.
        if src_type.is_builtin("int") and dest_type.is_builtin("float"):
            return True

        # TODO: Search base classes and everything else pyright is doing.
        return False

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

            case uni.Ability():
                return self.get_type_of_ability(node)

            case uni.ParamVar():
                if node.type_tag:
                    annotation_type = self.get_type_of_expression(node.type_tag.tag)
                    return self._convert_to_instance(annotation_type)

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

            case uni.Float():
                return self._convert_to_instance(self.get_type_of_float(expr))

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

            case uni.AtomUnit():
                return self.get_type_of_expression(expr.value)

            case uni.FuncCall():
                return self.validate_call_args(expr)

            case uni.BinaryExpr():
                return operations.get_type_of_binary_operation(self, expr)

            case uni.Name():
                # NOTE: For self's type pyright is getting the first parameter of a method and
                # the name can be anything not just self, however we don't have the first parameter
                # and self is a keyword, we need to do it in this way.
                if self._is_expr_self(expr):
                    return self._get_type_of_self(expr)

                if symbol := expr.sym_tab.lookup(expr.value, deep=True):
                    expr.sym = symbol
                    return self.get_type_of_symbol(symbol)

            # TODO: More expressions.
        return types.UnknownType()

    # -----------------------------------------------------------------------------
    # Helper functions
    # -----------------------------------------------------------------------------

    def _is_expr_self(self, expr: uni.Expr) -> bool:
        """Check if the expression is Name that is 'self' and in the method context."""
        if (
            isinstance(expr, uni.Name)
            and (expr.value == TOKEN_MAP[Tok.KW_SELF])
            and (fn := self._get_enclosing_method(expr))
            and (not fn.is_static)
        ):
            return True
        return False

    def _get_enclosing_function(self, node: uni.UniNode) -> uni.Ability | None:
        """Get the enclosing function (ability) of the given node."""
        if (impl := node.find_parent_of_type(uni.ImplDef)) and (
            isinstance(impl.decl_link, uni.Ability)
        ):
            return impl.decl_link
        return node.find_parent_of_type(uni.Ability)

    def _get_enclosing_method(self, node: uni.UniNode) -> uni.Ability | None:
        """Get the enclosing method (ability) of the given node."""
        enclosing_fn = self._get_enclosing_function(node)
        while enclosing_fn and (not enclosing_fn.is_method):
            enclosing_fn = self._get_enclosing_function(enclosing_fn)
        if enclosing_fn and enclosing_fn.is_method:
            return enclosing_fn
        return None

    def _get_type_of_self(self, node: uni.Name) -> TypeBase:
        """Return the effective type of self."""
        if method := self._get_enclosing_method(node):
            cls = method.method_owner
            if isinstance(cls, uni.Archetype):
                return self.get_type_of_class(cls).clone_as_instance()
            if isinstance(cls, uni.Enum):
                pass  # TODO: Implement type from enum.
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
    ) -> type_utils.ClassMember | None:
        """Lookup the class member type."""
        assert self.prefetch.int_class is not None
        # FIXME: Pyright's way: Implement class member iterator (based on mro and the multiple inheritance)
        # return the first found member from the iterator.

        # NOTE: This is a simple implementation to make it work and more robust implementation will
        # be done in a future PR.
        for cls in base_type.shared.mro:
            if sym := cls.lookup_member_symbol(member):
                return type_utils.ClassMember(sym, cls)
        return None

    def _lookup_object_member(
        self, base_type: types.ClassType, member: str
    ) -> type_utils.ClassMember | None:
        """Lookup the object member type."""
        assert self.prefetch.int_class is not None
        if base_type.is_class_instance():
            assert isinstance(base_type, types.ClassType)
            # TODO: We need to implement Member lookup flags and set SkipInstanceMember to 0.
            return self._lookup_class_member(base_type, member)
        return None

    def match_args_to_params(
        self, expr: uni.FuncCall, func_type: types.FunctionType
    ) -> MatchArgsToParamsResult:
        """
        Match arguments passed to a function to the corresponding parameters in that function.

        This matching is done based on positions and keywords. Type evaluation and
        validation is left to the caller.
        This logic is based on PEP 3102: https://www.python.org/dev/peps/pep-3102/
        """
        arg_params: dict[uni.Expr | uni.KWPair, types.Parameter | None] = {}
        argument_errors = False

        params_to_match = func_type.parameters.copy()

        # Skip `self` for method calls.
        if len(func_type.parameters) >= 1 and func_type.parameters[0].is_self:
            params_to_match.pop(0)

        # Create a tracker for parameter assignment.
        param_tracker = type_utils.ParamAssignmentTracker(params_to_match)

        # We iterate over the arguments and match with the parameter, the param_tracker will
        # keep track of the matched parameters and unmatched required parameters.
        #
        # Tracker: p1, p2, /, p3, p4,   *args,       | p6,   **kwargs
        #          ^   ^      ^    ^    ^^   ^       | ^       ^^
        #          |   |      |    |    | \__ \__    | |       | \________
        # Args:    a1, a2,   a3, p4=a4, a5, a6, *a7, | p6=a8, p_kw1=a9, p_kw2=a10
        #         '--------------------------------' | '------------------------'
        #          We match positional with          |  We match named arguments with
        #          tracked parameter index.          |  param name lookup.
        #
        for arg in expr.params:
            try:
                if isinstance(arg, uni.KWPair):
                    # Match parameter based on name lookup.
                    matching_param = param_tracker.match_named_argument(arg)
                    arg_params[arg] = matching_param
                else:  # Match parameter based on the position of the argument.
                    matching_param = param_tracker.match_positional_argument(arg)
                    arg_params[arg] = matching_param
            except Exception as e:
                self.add_diagnostic(arg, str(e))
                argument_errors = True

        if unmatched_params := param_tracker.get_unmatched_required_params():
            names = ", ".join(f"'{p.name}'" for p in unmatched_params)
            argument_errors = True
            self.add_diagnostic(
                expr,
                f"Not all required parameters were provided in the function call: {names}",
            )

        return MatchArgsToParamsResult(
            arg_params=arg_params, argument_errors=argument_errors
        )

    def validate_call_args(self, expr: uni.FuncCall) -> TypeBase:
        """
        Validate that the arguments can be assigned to the call's parameter list.

        Specializes the call based on arg types, and returns the specialized
        type of the return value. If it detects an error along the way, it emits
        a diagnostic and sets argumentErrors to true.
        """
        caller_type = self.get_type_of_expression(expr.target)
        if isinstance(caller_type, types.FunctionType):
            arg_param_match = self.match_args_to_params(expr, caller_type)
            if not arg_param_match.argument_errors:
                self.validate_arg_types(arg_param_match)
            return caller_type.return_type or types.UnknownType()

        if (
            isinstance(caller_type, types.ClassType)
            and caller_type.is_instantiable_class()
        ):
            # TODO: validate args for __init__()
            return caller_type.clone_as_instance()

        if caller_type.is_class_instance():
            # TODO: validate args.
            magic_call_ret = self.get_type_of_magic_method_call(caller_type, "__call__")
            if magic_call_ret:
                return magic_call_ret

        return types.UnknownType()

    def validate_arg_types(
        self,
        args: MatchArgsToParamsResult,
    ) -> None:
        """Validate that the argument types can be assigned to the parameter types."""
        for arg, param in args.arg_params.items():
            if param is None or param.param_type is None:
                continue
            if isinstance(arg, uni.KWPair):
                arg_type = self.get_type_of_expression(arg.value)
            else:
                arg_type = self.get_type_of_expression(arg)

            if not self.assign_type(arg_type, param.param_type):
                self.add_diagnostic(
                    arg,
                    f"Cannot assign {arg_type} to parameter '{param.name}' of type {param.param_type}",
                )
