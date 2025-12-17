"""
Type system evaluator for JacLang.

PyrightReference:
    packages/pyright-internal/src/analyzer/typeEvaluator.ts
    packages/pyright-internal/src/analyzer/typeEvaluatorTypes.ts
"""

import ast as py_ast;
import os;
import from dataclasses { dataclass }
import from pathlib { Path }
import from typing { Callable, TYPE_CHECKING, cast }

import jaclang.pycore.unitree as uni;
import from jaclang.pycore.jac_parser { TOKEN_MAP }
import from jaclang.pycore.constant { SymbolType, Tokens as Tok }
import from jaclang.compiler.passes.main.pyast_load_pass { PyastBuildPass }
import from jaclang.pycore.passes.sym_tab_build_pass { SymTabBuildPass }
import from jaclang.compiler.type_system { types }
import from jaclang.runtimelib.utils { read_file_with_encoding }
import from jaclang.pycore.settings { settings }

with entry {
    if TYPE_CHECKING {
        import from jaclang.pycore.program { JacProgram }
    }
}

# FIXME: Conver the bellow to dot import (from . import ...)
# Currently its not possible with jac+python hybrid repos.
import from jaclang.compiler.type_system {
    operations
}
import from jaclang.compiler.type_system { type_utils }
import from jaclang.compiler.type_system.types { TypeBase }

# The callback type definition for the diagnostic messages.
glob DiagnosticCallback = Callable[
    [uni.UniNode, str, bool],
    None
];

"""Types whose definitions are prefetched and cached by the type evaluator."""
obj PrefetchedTypes {
    has none_type_class: TypeBase | None = None,
        object_class: TypeBase | None = None,
        type_class: TypeBase | None = None,
        union_type_class: TypeBase | None = None,
        awaitable_class: TypeBase | None = None,
        function_class: TypeBase | None = None,
        method_class: TypeBase | None = None,
        tuple_class: TypeBase | None = None,
        bool_class: TypeBase | None = None,
        int_class: TypeBase | None = None,
        float_class: TypeBase | None = None,
        str_class: TypeBase | None = None,
        dict_class: TypeBase | None = None,
        module_type_class: TypeBase | None = None,
        typed_dict_class: TypeBase | None = None,
        typed_dict_private_class: TypeBase | None = None,
        supports_keys_and_get_item_class: TypeBase | None = None,
        mapping_class: TypeBase | None = None,
        template_class: TypeBase | None = None,
        type_var_class: TypeBase | None = None,
        # Prefetch from typing.pyi file
        protocol_class: TypeBase | None = None,
        # Prefetched from jac_builtins.pyi file
        root_class: TypeBase | None = None;
}

"""Represents a single entry in the symbol resolution stack."""
obj SymbolResolutionStackEntry {
    has symbol: uni.Symbol,
        # Initially true, it's set to false if a recursion
        # is detected.
        is_result_valid: bool = True,
        # Some limited forms of recursion are allowed. In these
        # cases, a partially-constructed type can be registered.
        partial_type: TypeBase | None = None;
}

"""Result of matching arguments to parameters."""
obj MatchArgsToParamsResult {
    has arg_params: dict[(uni.Expr | uni.KWPair, types.Parameter | None)],
        overload: types.FunctionType | None = None,
        argument_errors: bool = False;
}

"""Type evaluator for JacLang."""
class TypeEvaluator {
    has _BUILTINS_STUB_FILE_PATH: str = os.path.join(
        os.path.dirname(__file__), "../../vendor/typeshed/stdlib/builtins.pyi"
    ),
        _TYPING_STUB_FILE_PATH: str = os.path.join(
            os.path.dirname(__file__), "../../vendor/typeshed/stdlib/typing.pyi"
        ),
        _TYPES_STUB_FILE_PATH: str = os.path.join(
            os.path.dirname(__file__), "../../vendor/typeshed/stdlib/types.pyi"
        ),
        _JAC_BUILTINS_STUB_FILE_PATH: str = os.path.join(
            os.path.dirname(__file__), "jac_builtins.pyi"
        );

    """Initialize the type evaluator with prefetched types.

    Implementation Note:
    --------------------
    Pyright is prefetching the builtins when an evaluation is requested
    on a node and from that node it does lookup for the builtins scope
    and does the prefetch once, however if we forgot to call prefetch
    in some place then it will not be available in the evaluator, So we
    are prefetching the builtins at the constructor level once.
    """
    def init(self: TypeEvaluator, program: "JacProgram") -> None {
        self.program = program;
        self.symbol_resolution_stack: list[SymbolResolutionStackEntry] = [];
        self.prefetch: PrefetchedTypes = PrefetchedTypes();
        self.diagnostic_callback: DiagnosticCallback | None = None;
        self.builtins_module: uni.Module | None = None;
        # Cache for module types by resolved path to avoid redundant lookups.
        self._module_type_cache: dict[str, types.ModuleType] = {};

        # NOTE: The initialization order here is important.
        self.typing_module = self._load_stub_module(
            TypeEvaluator._TYPING_STUB_FILE_PATH
        );
        self.types_module = self._load_stub_module(TypeEvaluator._TYPES_STUB_FILE_PATH);

        # These prefetch type are essential for the builtin types.
        self.prefetch.type_var_class = self._get_type_from_module(
            self.typing_module, "TypeVar"
        );
        self.builtins_module = self._load_stub_module(
            TypeEvaluator._BUILTINS_STUB_FILE_PATH
        );
        self.jac_builtins_module = self._load_stub_module(
            TypeEvaluator._JAC_BUILTINS_STUB_FILE_PATH
        );

        self._prefetch_types();
    }

    """Load and return builtins stub module."""
    def _load_stub_module(self: TypeEvaluator, path: str) -> uni.Module {
        if not os.path.exists(path) {
            if not settings.all_warnings {
                raise FileNotFoundError(f"Stub file not found at {path}") ;
            } else {
                print(f"Warning: Stub file not found at {path}");
                exit(0);
            }
        }
        file_content = read_file_with_encoding(path);
        uni_source = uni.Source(file_content, path);
        mod = PyastBuildPass(
            ir_in=uni.PythonModuleAst(py_ast.parse(file_content), orig_src=uni_source,),
            prog=self.program,
        ).ir_out;
        SymTabBuildPass(ir_in=mod, prog=self.program);
        self.program.mod.hub[path] = mod;
        return mod;
    }

    """Return the built-in type with the given name."""
    def _get_type_from_module(
        self: TypeEvaluator, module: uni.Module, name: str
    ) -> TypeBase {
        if (symbol := type_utils.lookup_symtab(module, name, self.builtins_module)) is not None {
            return self.get_type_of_symbol(symbol);
        }
        return types.UnknownType();
    }

    """Return the prefetched types for the type evaluator."""
    def _prefetch_types(self: TypeEvaluator) {
        get_types_type = lambda  type_name: str  -> types.TypeBase:
            self._get_type_from_module(self.types_module, type_name);
        get_typing_type = lambda  type_name: str  -> types.TypeBase:
            self._get_type_from_module(self.typing_module, type_name);
        get_builtin_type = lambda  type_name: str  -> types.TypeBase:
            self._get_type_from_module(self.builtins_module, type_name);
        get_jac_builtin_type = lambda  type_name: str  -> types.TypeBase:
            self._get_type_from_module(self.jac_builtins_module, type_name);

        # TODO: Pyright first try load NoneType from typeshed and if it cannot
        # then it set to unknown type.
        self.prefetch.none_type_class = get_types_type("NoneType");
        self.prefetch.object_class = get_builtin_type("object");
        self.prefetch.type_class = get_builtin_type("type");
        self.prefetch.union_type_class = get_types_type("UnionType");
        # self.prefetch.awaitable_class =
        # self.prefetch.function_class =
        # self.prefetch.method_class =
        self.prefetch.tuple_class = get_builtin_type("tuple");
        self.prefetch.bool_class = get_builtin_type("bool");
        self.prefetch.int_class = get_builtin_type("int");
        self.prefetch.float_class = get_builtin_type("float");
        self.prefetch.str_class = get_builtin_type("str");
        self.prefetch.dict_class = get_builtin_type("dict");
        # self.prefetch.module_type_class =
        # self.prefetch.typed_dict_class =
        # self.prefetch.typed_dict_private_class =
        # self.prefetch.supports_keys_and_get_item_class =
        # self.prefetch.mapping_class =
        # self.prefetch.template_class =
        self.prefetch.protocol_class = get_typing_type("Protocol");

        self.prefetch.root_class = get_jac_builtin_type("Root");
        self.prefetch.root_class.shared.is_root_class = True;
    }

    def get_none_type(self: TypeEvaluator) -> TypeBase {
        if self.prefetch and self.prefetch.none_type_class {
            return self.prefetch.none_type_class;
        }
        return types.UnknownType();
    }

    """Add a diagnostic message to the program."""
    def add_diagnostic(
        self: TypeEvaluator, node: uni.UniNode, message: str, warning: bool = False
    ) -> None {
        if self.diagnostic_callback {
            self.diagnostic_callback(node, message, warning);
        }
    }

    # -------------------------------------------------------------------------
    # Symbol resolution stack
    # -------------------------------------------------------------------------
    """Get the index of a symbol in the resolution stack."""
    def get_index_of_symbol_resolution(
        self: TypeEvaluator, symbol: uni.Symbol
    ) -> int | None {
        for (i, entry_) in enumerate(self.symbol_resolution_stack) {
            if entry_.symbol == symbol {
                return i;
            }
        }
        return None;
    }

    """
    Push a symbol onto the resolution stack.

    Return False if recursion detected and in that case it won't push the symbol.
    """
    def push_symbol_resolution(self: TypeEvaluator, symbol: uni.Symbol) -> bool {
        idx = self.get_index_of_symbol_resolution(symbol);
        if idx is not None {
            # Mark all of the entries between these two as invalid.
            for i in range(idx, len(self.symbol_resolution_stack)) {
                entry_ = self.symbol_resolution_stack[i];
                entry_.is_result_valid = False;
            }
            return False;
        }
        self.symbol_resolution_stack.append(SymbolResolutionStackEntry(symbol=symbol));
        return True;
    }

    """Pop a symbol from the resolution stack."""
    def pop_symbol_resolution(self: TypeEvaluator, symbol: uni.Symbol) -> bool {
        popped_entry = self.symbol_resolution_stack.pop();
        assert popped_entry.symbol == symbol;
        return popped_entry.is_result_valid;
    }

    # Pyright equivalent function name = getEffectiveTypeOfSymbol.
    """Return the effective type of the symbol."""
    def get_type_of_symbol(self: TypeEvaluator, symbol: uni.Symbol) -> TypeBase {
        if self.push_symbol_resolution(symbol) {
            try {
                return self._get_type_of_symbol(symbol);
            } finally {
                self.pop_symbol_resolution(symbol);
            }
        }

        # If we reached here that means we have a cyclic symbolic reference.
        return types.UnknownType();
    }

    # NOTE: This function doesn't exists in pyright, however it exists as a helper function
    # for the following functions.
    """Import a module from the given path."""
    def _import_module_from_path(self: TypeEvaluator, path: str) -> uni.Module {
        # -----------------------------------------------------------------------
        # TODO: Implement stub file resolution properly, this is a ad-hoc mess.
        # FIXME: This is ad-hoc way to override the typeing.py with typeing.pyi file
        # implemented to make it work for now, please revisit this and implement it properly.
        if path.endswith("typing.py") {
            path = TypeEvaluator._TYPING_STUB_FILE_PATH;
        }
        if path.endswith("abc.py") {
            path = TypeEvaluator._TYPING_STUB_FILE_PATH;
        }
        # -----------------------------------------------------------------------

        # Get the module, if it's not loaded yet, compile and get it.
        #
        # TODO:
        # We're not typechecking inside the module itself however we
        # need to check if the module path is site-package or not and
        # do typecheck inside as well.
        mod: uni.Module;
        if path in self.program.mod.hub {
            mod = self.program.mod.hub[path];
        } else {
            # Use symtab_ir_only=True to skip semantic analysis and CFG passes.
            mod = self.program.compile(
                path, no_cgen=True, type_check=False, symtab_ir_only=True
            );
            # FIXME: Inherit from builtin symbol table logic is currently implemented
            # here and checker pass, however it should be in one location, since we're
            # doing type_check=False, it doesn't set parent_scope to builtins, this
            # needs to be done properly. The way jaclang handles symbol table is different
            # than pyright, so we cannot strictly follow them, however as long as a new
            # module has a parent scope as builtin scope, we're aligned with pyright.
            if mod.parent_scope is None and mod is not self.builtins_module {
                mod.parent_scope = self.builtins_module;
            }
        }
        return mod;
    }

    """Return the effective type of the module."""
    def get_type_of_module(
        self: TypeEvaluator, node_: uni.ModulePath
    ) -> types.TypeBase {
        if node_.path {
            # If the type is already computed, return it.
            if node_.path[-1].type {
                return node_.path[-1].type;
            }
            # Compute path list once before the loop.
            path_list = node_.resolve_relative_path_list();
            for (idx, npath) in enumerate(node_.path) {
                mod_path = path_list[idx];

                # Check module type cache first.
                if mod_path in self._module_type_cache {
                    npath.type = self._module_type_cache[mod_path];
                    npath._sym_category = SymbolType.MODULE;
                    continue;
                }

                # If the path doesn't exist, return unknown type.
                # eg: import from ..mod { item }  # <-- Here ..mod might not exist.
                if not Path(mod_path).exists() {
                    npath.type = types.UnknownType();
                    npath._sym_category = SymbolType.MODULE;
                    self.add_diagnostic(npath, 'Module not found', warning=True);
                    return npath.type;
                }

                mod: uni.Module = self._import_module_from_path(mod_path);
                mod_type = types.ModuleType(
                    mod_name=npath.value,
                    file_uri=Path(mod_path).resolve(),
                    symbol_table=mod
                );
                npath.type = mod_type;
                npath._sym_category = SymbolType.MODULE;
                # Cache the module type for future lookups.
                self._module_type_cache[mod_path] = mod_type;
            }
            if node_.alias {
                node_.alias.type = node_.path[-1].type;
                node_.alias._sym_category = SymbolType.MODULE;
            }
            return node_.path[-1].type;
        }
        return types.UnknownType();
    }

    """Return the effective type of the module item."""
    def get_type_of_module_item(
        self: TypeEvaluator, node_: uni.ModuleItem
    ) -> types.TypeBase {
        # Module item can be both a module or a member of a module.
        # import from .. { mod }   # <-- Here mod is not a member but a module itself.
        # import from mod { item } # <-- Here item is not a module but a member of mod.
        if node_.name.type is not None {
            return node_.name.type;
        }

        import_node = node_.parent_of_type(uni.Import);
        assert import_node.from_loc is not None;
        if isinstance(self.get_type_of_module(import_node.from_loc), types.ModuleType) {
            from_path = Path(import_node.from_loc.resolve_relative_path());
            is_dir = from_path.is_dir() or (from_path.stem == "__init__");
            # import from .. { mod }
            # import from package.subpackage { item}
            #                     ^^^^^^^^^^^
            # subpackage can be a module or a package (dir with __init__.jac)
            if is_dir {
                mod_dir = from_path.parent if not from_path.is_dir() else from_path;
                # FIXME: Implement module resolution properly.
                for ext in (".jac", ".py", ".pyi", ".js", ".ts", ".jsx", ".tsx") {
                    # Try resolving both "__init__" module and direct module file.
                    candidate_paths = [
                        (mod_dir / f"__init__{ext}").resolve(),
                        (mod_dir / f"{node_.name.value}{ext}").resolve(),

                    ];
                    for path in candidate_paths {
                        if not path.exists() {
                            continue;
                        }

                        mod = self._import_module_from_path(str(path));

                        # Case 1: Look for symbol inside __init__.ext module
                        if path.name.startswith("__init__") {
                            if sym := type_utils.lookup_symtab(
                                mod, node_.name.value, self.builtins_module
                            ) {
                                return self._set_module_item_symbol_and_type(
                                    node_, sym
                                );
                            }
                            continue;  # Try next candidate
                        }

                        # Case 2: The module itself (mod_name.ext)
                        mod_type = types.ModuleType(
                            mod_name=node_.name.sym_name,
                            file_uri=path,
                            symbol_table=mod,
                        );
                        # Cache the type.
                        node_.name.type = mod_type;

                        # FIXME: goto definition works on imported symbol by checking if it's a MODULE
                        # type and in that case it'll call resolve_relative_path on the parent node of
                        # the symbol's definition node (a module path), So the goto definition to work
                        # properly the category should be module on a module path, If we set like this
                        # below should work but because of the above assumption (should be a mod path)
                        # it won't, This needs to be discussed.
                        #
                        node_.name._sym_category = SymbolType.MODULE;
                        return mod_type;
                    }
                }
            } else {
                mod_type = self.get_type_of_module(import_node.from_loc);
                if not isinstance(mod_type, types.ModuleType) {
                    node_.name.type = types.UnknownType();
                    # TODO: Add diagnostic that from_loc is not accessible.
                    # Eg: 'Import "scipy" could not be resolved'
                    return node_.name.type;
                }
                if sym := type_utils.lookup_symtab(
                    mod_type.symbol_table, node_.name.value, self.builtins_module
                ) {
                    return self._set_module_item_symbol_and_type(node_, sym);
                }
            }
        }

        return types.UnknownType();
    }

    def _extract_type_params(
        self: TypeEvaluator, node_: uni.Archetype
    ) -> list[types.TypeVarType] {
        type_params: list[types.TypeVarType] = [];
        for base_class in node_.base_classes or [] {
            if (not isinstance(base_class, uni.AtomTrailer))
            or base_class.is_attr
            or base_class.is_null_ok {
                continue;
            }

            if isinstance(base_class.right, uni.IndexSlice) and base_class.right.slices {
                type_vars = base_class.right.slices[0].start;
                if isinstance(type_vars, uni.TupleVal) {
                    for val in type_vars.values {
                        type_var_type = self.get_type_of_expression(val);
                        if isinstance(type_var_type, types.TypeVarType) {
                            type_params.append(type_var_type);
                        }
                    }
                } else {
                    type_var_type = self.get_type_of_expression(type_vars);
                    if isinstance(type_var_type, types.TypeVarType) {
                        type_params.append(type_var_type);
                    }
                }
            }
        }
        return type_params;
    }

    """Return the effective type of the class."""
    def get_type_of_class(self: TypeEvaluator, node_: uni.Archetype) -> types.ClassType {
        # Is this type already cached?
        if node_.name_spec.type is not None {
            return cast(types.ClassType, node_.name_spec.type);
        }

        # Gather type parameters.
        type_params = self._extract_type_params(node_);

        base_classes: list[TypeBase] = [];
        for base_class in node_.base_classes or [] {
            base_class_type = self.get_type_of_expression(base_class);
            base_classes.append(base_class_type);
        }
        is_builtin_class = node_.find_parent_of_type(uni.Module) == self.builtins_module;

        # NOTE: obj, walker, node, edge are dataclass with symbol type as such but
        # other classes are with symbol type TYPE.
        # TODO: We need to handle @dataclass decorator as well.
        is_data_class = node_.sym_category != SymbolType.TYPE;

        cls_type = types.ClassType(
            types.ClassType.ClassDetailsShared(
                class_name=node_.name_spec.sym_name,
                symbol_table=node_,
                type_params=type_params,
                base_classes=base_classes,
                is_builtin_class=is_builtin_class,
                is_data_class=is_data_class,
            ),
            private=None,
            flags=types.TypeFlags.Instantiable,
        );

        # Compute the MRO for the class.
        type_utils.compute_mro_linearization(cls_type);

        # Cache the type, pyright is doing invalidateTypeCacheIfCanceled()
        # we're not doing that any time sooner.
        node_.name_spec.type = cls_type;
        return cls_type;
    }

    """Return the effective type of an ability."""
    def get_type_of_ability(self: TypeEvaluator, node_: uni.Ability) -> TypeBase {
        if node_.name_spec.type is not None {
            return node_.name_spec.type;
        }

        if not isinstance(node_.signature, uni.FuncSignature) {
            func_type = types.FunctionType(
                func_name=node_.name_spec.sym_name,
                return_type=types.UnknownType(),
                parameters=None,
            );
            node_.name_spec.type = func_type;
            return node_.name_spec.type;
        }

        return_type: TypeBase = types.UnknownType();
        if isinstance(node_.signature.return_type, uni.Expr) {
            return_type = self._convert_to_instance(
                self.get_type_of_expression(node_.signature.return_type)
            );
        } else {
            if self.prefetch and self.prefetch.none_type_class {
                return_type = self._convert_to_instance(self.prefetch.none_type_class);
            }
        }

        # Define helper function for parameter conversion.
        def _get_param_category(param: uni.ParamVar) -> types.ParameterCategory {
            if param.is_vararg {
                return types.ParameterCategory.ArgsList;
            }
            if param.is_kwargs {
                return types.ParameterCategory.KwargsDict;
            }
            return types.ParameterCategory.Positional;
        }

        # Define helper function for parameter kind conversion.
        def _convert_param_kind(kind: uni.ParamKind) -> types.ParamKind {
            match kind {
                case uni.ParamKind.POSONLY:
                    return types.ParamKind.POSONLY;

                case uni.ParamKind.NORMAL:
                    return types.ParamKind.NORMAL;

                case uni.ParamKind.VARARG:
                    return types.ParamKind.VARARG;

                case uni.ParamKind.KWONLY:
                    return types.ParamKind.KWONLY;

                case uni.ParamKind.KWARG:
                    return types.ParamKind.KWARG;
                    return types.ParamKind.NORMAL;

            }
        }

        parameters: list[types.Parameter] = [];
        for (idx, param) in enumerate(node_.signature.get_parameters()) {
            # TODO: Set parameter category for *args, and **kwargs
            param_type: TypeBase | None = None;

            if param.type_tag {
                param_type_cls = self.get_type_of_expression(param.type_tag.tag);
                param_type = self._convert_to_instance(param_type_cls);
            }

            parameters.append(
                types.Parameter(
                    name=param.name.value,
                    category=_get_param_category(param),
                    param_type=param_type,
                    default_value=param.value,
                    is_self=(idx == 0 and self._is_expr_self(param.name)),
                    param_kind=_convert_param_kind(param.param_kind),
                )
            );
        }

        func_type = types.FunctionType(
            func_name=node_.name_spec.sym_name,
            return_type=return_type,
            parameters=parameters,
        );

        node_.name_spec.type = func_type;
        return func_type;
    }

    """Return the effective type of the string."""
    def get_type_of_string(
        self: TypeEvaluator, node: uni.String | uni.MultiString
    ) -> TypeBase {
        # FIXME: Strings are a type of LiteralString type:
        # "foo" is not `str` but Literal["foo"], however for now we'll
        # not considering that and make it work and will implement that
        # later.
        #
        # see: getTypeOfString() in pyright (it requires parsing the sub
        # file of the typing module).
        assert self.prefetch.str_class is not None;
        return self.prefetch.str_class;
    }

    """Return the effective type of the int."""
    def get_type_of_int(self: TypeEvaluator, node: uni.Int) -> TypeBase {
        assert self.prefetch.int_class is not None;
        return self.prefetch.int_class;
    }

    """Return the effective type of the float."""
    def get_type_of_float(self: TypeEvaluator, node: uni.Float) -> TypeBase {
        assert self.prefetch.float_class is not None;
        return self.prefetch.float_class;
    }

    # Pyright equivalent function name = getTypeOfExpression();
    """Return the effective type of the expression."""
    def get_type_of_expression(self: TypeEvaluator, node_: uni.Expr) -> TypeBase {
        # To support JS style IIFE, abilities should be treated as expressions.
        if isinstance(node_, uni.Ability) {
            return self.get_type_of_ability(node_);
        }

        # If it's alreay "cached" return it.
        if node_.type is not None {
            return node_.type;
        }

        result = self._get_type_of_expression_core(node_);
        # If the context has an expected type, pyright does a compatibility and set
        # a diagnostics here, I don't understand why that might be necessary here.
        node_.type = result;  # Cache the result
        return result;
    }

    # Comments from pyright:
    # // Determines if the source type can be assigned to the dest type.
    # // If constraint are provided, type variables within the destType are
    # // matched against existing type variables in the map. If a type variable
    # // in the dest type is not in the type map already, it is assigned a type
    # // and added to the map.
    #
    # dest_type = src_type;
    """Assign the source type to the destination type."""
    def assign_type(
        self: TypeEvaluator, src_type: TypeBase, dest_type: TypeBase
    ) -> bool {
        if types.TypeCategory.Unknown in (src_type.category, dest_type.category) {
            # NOTE: For now if we don't have the type info, we assume it's compatible.
            # For strict mode we should disallow usage of unknown unless explicitly ignored.
            return True;
        }

        if src_type == dest_type {
            return True;
        }

        # If destination is a union type, check if source is compatible with any of the
        # constituent types.
        if isinstance(dest_type, types.UnionType) {
            for union_type in dest_type.types {
                new_dest_type = self._convert_to_instance(union_type);
                if self.assign_type(src_type, new_dest_type) {
                    return True;
                }
            }
        }

        if dest_type.is_class_instance() and src_type.is_class_instance() {
            assert isinstance(dest_type, types.ClassType);
            assert isinstance(src_type, types.ClassType);
            return self._assign_class(src_type, dest_type);
        }

        return False;
    }

    # TODO: This should take an argument list as parameter.
    """Return the effective return type of a magic method call."""
    def get_type_of_magic_method_call(
        self: TypeEvaluator, obj_type: TypeBase, method_name: str
    ) -> TypeBase | None {
        if obj_type.category == types.TypeCategory.Class {
            # TODO: getTypeOfBoundMember() <-- Implement this if needed, for the simple case
            # we'll directly call member lookup.
            #
            # WE'RE DAVIATING FROM PYRIGHT FOR THIS METHOD HEAVILY HOWEVER THIS CAN BE RE-WRITTEN IF NEEDED.
            #
            assert isinstance(obj_type, types.ClassType);  # <-- To make typecheck happy.
            if member := self._lookup_class_member(obj_type, method_name) {
                member_ty = self.get_type_of_symbol(member.symbol);
                if isinstance(member_ty, types.FunctionType) {
                    return member_ty.specialize(obj_type).return_type;
                }
                # If we reached here, magic method is not a function.
                # 1. recursively check __call__() on the type, TODO
                # 2. if any or unknown, return getUnknownTypeForCallable() TODO
                # 3. return undefined.
                return None;
            }
        }
        return None;
    }

    def is_sub_class(
        self: TypeEvaluator, super_cls: types.ClassType, sub_cls: types.ClassType
    ) -> bool {
        for cls in sub_cls.shared.mro {
            if cls.shared == super_cls.shared {
                return True;
            }
        }
        return False;
    }

    """Assign the source class type to the destination class type."""
    def _assign_class(
        self: TypeEvaluator, src_type: types.ClassType, dest_type: types.ClassType
    ) -> bool {
        if src_type.shared == dest_type.shared {
            return True;
        }

        # Check if src class is a subclass of dest class.
        if self.is_sub_class(dest_type, src_type) {
            return True;
        }

        # Everything is assignable to an object.
        if dest_type.is_builtin("object") {
            # TODO: Invariance not handled yet
            # invariant contexts to avoid list[int] <: list[object] errors.
            return True;
        }

        # Integers can be used where floats are expected.
        if src_type.is_builtin("int") and dest_type.is_builtin("float") {
            return True;
        }

        # Check if dest_type is a protocol and src_type implements it.
        for base_cls in dest_type.shared.base_classes {
            if base_cls.shared == self.prefetch.protocol_class.shared {
                if type_utils.class_implements_protocol(src_type, dest_type) {
                    return True;
                }
                # TODO: The dest_class can have other base classes as well, do this
                # Recursively.
                break;
            }
        }

        return False;
    }

    # This function is a combination of the bellow pyright functions.
    #  - getDeclaredTypeOfSymbol
    #  - getTypeForDeclaration
    #
    # Implementation Note:
    # Pyright is actually have some duplicate logic for handling declared
    # type and inferred type, we're going to unify them (if it's required
    # in the future, we can refactor this).
    """Return the declared type of the symbol."""
    def _get_type_of_symbol(self: TypeEvaluator, symbol: uni.Symbol) -> TypeBase {
        node_ = symbol.decl.name_of;
        match node_ {
            case uni.Archetype() | uni.Enum():
                return self.get_type_of_class(node_);

            case uni.Ability():
                return self.get_type_of_ability(node_);

            case uni.ParamVar():
                if node_.type_tag {
                    annotation_type = self.get_type_of_expression(node_.type_tag.tag);
                    return self._convert_to_instance(annotation_type);
                }

            # This actually defined in the function getTypeForDeclaration();
            # Pyright has DeclarationType.Variable.
            case uni.Name():
                # ---- Handle simple assignment: var = <expr> ----
                if isinstance(node_.parent, uni.Assignment) {
                    if node_.parent.type_tag is not None {
                        annotation_type = self.get_type_of_expression(
                            node_.parent.type_tag.tag
                        );
                        return self._convert_to_instance(annotation_type);
                    } else {  # Assignment without a type annotation.

                        if node_.parent.value is not None {
                            return self.get_type_of_expression(node_.parent.value);
                        }
                    }
                }

                # ---- Handle member assignment: obj.attr = <expr> ----
                # Pyright handles this in getDeclInfoForNameNode()
                if (
                    isinstance(node_.parent, uni.AtomTrailer)
                    and node_.parent.parent
                    and isinstance(node_.parent.parent, uni.Assignment)
                ) {
                    # Member assignment with a type annotation: obj.member: <type> = <expr>
                    if node_.parent.parent.type_tag is not None {
                        annotation_type = self.get_type_of_expression(
                            node_.parent.parent.type_tag.tag
                        );
                        return self._convert_to_instance(annotation_type);
                    } else {
                        if node_.parent.parent.value is not None {
                            return self.get_type_of_expression(
                                node_.parent.parent.value
                            );
                        }
                    }
                }

                # ---- Handle member assignment: for <name> in <expr> ----
                if isinstance(node_.parent, uni.InForStmt) {
                    collection_type = self.get_type_of_expression(
                        node_.parent.collection
                    );
                    # FIXME: This is the proper way to do it however Iterator[T] cannot be
                    # resolved as a generic type because of the definition. So I'm doing this ad-hoc
                    # way, will come back and have to fix it properly.
                    #
                    # iter_type = self.get_type_of_magic_method_call(collection_type, "__iter__");
                    #
                    iter_type = self.get_type_of_magic_method_call(
                        collection_type, "__getitem__"
                    );
                    return iter_type or types.UnknownType();
                }

                if isinstance(node_.parent, uni.ModulePath) {
                    return self.get_type_of_module(node_.parent);
                }
                if isinstance(node_.parent, uni.ModuleItem) {
                    return self.get_type_of_module_item(node_.parent);
                }

            case uni.HasVar():
                if node_.type_tag is not None {
                    annotation_type = self.get_type_of_expression(node_.type_tag.tag);
                    return self._convert_to_instance(annotation_type);
                } else {
                    if node_.value is not None {
                        return self.get_type_of_expression(node_.value);
                    }
                }

        }

        # TODO: Implement for functions, parameters, explicit type
        # annotations in assignment etc.
        return types.UnknownType();
    }

    # Pyright equivalent function name = getTypeOfExpressionCore();
    """Core function to get the type of the expression."""
    def _get_type_of_expression_core(self: TypeEvaluator, expr: uni.Expr) -> TypeBase {
        match expr {
            # ----------------------------------------------------------------------
            # Prefetched types: These types may not have prefetched and we need to
            # check if they are available, if the're not, we're inside builtins or
            # typeshed module itself and in that case we can just return unknown type.
            # ----------------------------------------------------------------------
            case uni.String() | uni.MultiString():
                if self.prefetch {
                    return self._convert_to_instance(self.get_type_of_string(expr));
                }

            case uni.Int():
                if self.prefetch {
                    return self._convert_to_instance(self.get_type_of_int(expr));
                }

            case uni.Float():
                if self.prefetch {
                    return self._convert_to_instance(self.get_type_of_float(expr));
                }

            case uni.Null():
                if self.prefetch and self.prefetch.none_type_class {
                    return self._convert_to_instance(self.prefetch.none_type_class);
                }

            # TODO: Boolean literals.

            # ----------------------------------------------------------------------
            # End of prefetched types
            # ----------------------------------------------------------------------
            case uni.AtomTrailer():
                # NOTE: Pyright is using CFG to figure out the member type by narrowing the base
                # type and filtering the members. We're not doing that anytime sooner.
                base_type = self.get_type_of_expression(expr.target);

                if expr.is_attr {  # <expr>.member

                    assert isinstance(expr.right, uni.Name);
                    if isinstance(base_type, types.ModuleType) {
                        # getTypeOfMemberAccessWithBaseType()
                        if sym := type_utils.lookup_symtab(
                            base_type.symbol_table,
                            expr.right.value,
                            self.builtins_module
                        ) {
                            return self._set_symbol_to_expr(expr.right, sym);
                        }
                        return types.UnknownType();
                    } elif base_type.is_instantiable_class() {
                        assert isinstance(base_type, types.ClassType);
                        if member := self._lookup_class_member(
                            base_type, expr.right.value
                        ) {
                            return self._set_symbol_to_expr(expr.right, member.symbol);
                        }
                        return types.UnknownType();
                    } elif base_type.is_class_instance() {
                        assert isinstance(base_type, types.ClassType);
                        if member := self._lookup_object_member(
                            base_type, expr.right.value
                        ) {
                            expr_type = self._set_symbol_to_expr(
                                expr.right, member.symbol
                            );
                            if isinstance(expr_type, types.FunctionType) {
                                expr_type = expr_type.specialize(base_type);
                            }
                            return expr_type;
                        }
                        return types.UnknownType();
                    }
                } elif expr.is_null_ok {
                    # TODO:
                    # <expr>?.member
                } elif isinstance(expr.right, uni.AssignCompr) {
                    # base_type should be a sequence of [T].
                    if not isinstance(base_type, types.ClassType) {
                        self.add_diagnostic(
                            expr,
                            f'Cannot perform assignment comprehension on type "{base_type}"',
                        );
                        return base_type;
                    }
                    # TODO: Ensure the base_type is a Sequence[T], for now I'm only checking
                    # if it's a generic of T.
                    if len(base_type.private.type_args) == 1 {
                        sequence_of = self._convert_to_instance(
                            base_type.private.type_args[0]
                        );
                        for assign in expr.right.assigns {
                            if assign.key is not None {
                                if member := self._lookup_object_member(
                                    sequence_of, assign.key.sym_name
                                ) {
                                    self._set_symbol_to_expr(assign.key, member.symbol);
                                } else {
                                    self.add_diagnostic(
                                        assign.key,
                                        f'Member "{assign.key.sym_name}" not found on type "{sequence_of}"',
                                    );
                                }
                                dest_type = self.get_type_of_expression(assign.key);
                                src_type = self.get_type_of_expression(assign.value);
                                if not self.assign_type(src_type, dest_type) {
                                    self.add_diagnostic(
                                        assign.value,
                                        f'Type "{src_type}" is not assignable to type "{dest_type}"',
                                    );
                                }
                            }
                        }
                    }
                    # Evaluate KW pair values.
                    for assign in expr.right.assigns {
                        self.get_type_of_expression(assign.value);
                    }
                    return base_type;
                } else {  # <expr>[<expr>]

                    # if <expr> is a class type, the atom trailer will be the type params.
                    if isinstance(base_type, types.ClassType)
                    and base_type.is_instantiable_class() {
                        # Collect the type arguments.
                        type_args: list[types.TypeBase] = [];
                        if isinstance(expr.right, uni.IndexSlice) and expr.right.slices {
                            type_args_vals = expr.right.slices[0].start;
                            if isinstance(type_args_vals, uni.TupleVal) {
                                for val in type_args_vals.values {
                                    type_arg_type = self.get_type_of_expression(val);
                                    type_args.append(type_arg_type);
                                }
                            } else {
                                type_arg_type = self.get_type_of_expression(
                                    type_args_vals
                                );
                                type_args.append(type_arg_type);
                            }
                        }
                        return base_type.specialize_generics(type_args);
                    }
                    # Regular <expr>[<expr>] case, we need to call __getitem__()
                    return self.get_type_of_magic_method_call(base_type, "__getitem__")
                    or types.UnknownType();
                }

            case uni.AtomUnit():
                return self.get_type_of_expression(expr.value);

            case uni.FuncCall():
                return self.validate_call_args(expr);

            case uni.BinaryExpr():
                return operations.get_type_of_binary_operation(self, expr);

            case uni.FilterCompr():
                if expr.f_type {
                    filter_type = self.get_type_of_expression(expr.f_type);
                    if isinstance(filter_type, types.ClassType) {
                        # For each compare in the filter comprehension, set symbol to the right name.
                        for cmp in expr.compares {
                            if isinstance(cmp.left, uni.Name)
                            and (
                                sym := filter_type.lookup_member_symbol(cmp.left.value)
                            ) {
                                self._set_symbol_to_expr(cmp.left, sym);
                            } else {
                                self.add_diagnostic(
                                    cmp.left,
                                    f'Member "{cmp.left.value}" not found on type "{filter_type}"',
                                );
                            }

                            left_type = self.get_type_of_expression(cmp.left);
                            right_type = self.get_type_of_expression(cmp.rights[0]);
                            # TODO: Check if those two types are comparable.
                            # if  not self.???(right_type, left_type) {
                            #     self.add_diagnostic(
                            #         cmp.right,
                            #         f'Type "{right_type}" is not comparable to type "{left_type}"',
                            #     );
                            # }
                        }
                    }
                }

            case uni.Name() | uni.SpecialVarRef():
                if isinstance(expr, uni.SpecialVarRef) {
                    if expr.name == Tok.KW_ROOT {
                        return self._get_type_of_root(expr);
                    }
                    # Handle "here" and "visitor" special name ref.
                    if expr.name in (Tok.KW_HERE, Tok.KW_VISITOR) {
                        if (method := self._get_enclosing_method(expr)) {
                            if isinstance(method.signature, uni.EventSignature) {
                                if arch := method.signature.arch_tag_info {
                                    type_arch_cls = self.get_type_of_expression(arch);
                                    type_arch_inst = self._convert_to_instance(
                                        type_arch_cls
                                    );
                                    if isinstance(type_arch_cls, types.ClassType) {
                                        self._set_symbol_to_expr(
                                            expr, type_arch_inst.get_class_symbol()
                                        );
                                    }
                                    return type_arch_inst;
                                }
                            }
                        }
                    }
                }

                # NOTE: For self's type pyright is getting the first parameter of a method and
                # the name can be anything not just self, however we don't have the first parameter
                # and self is a keyword, we need to do it in this way.
                if self._is_expr_self(expr) {
                    return self._get_type_of_self(expr);
                }

                if symbol := expr.sym_tab.lookup(
                    expr.value, deep=True, incl_inner_scope=True
                ) {
                    symbol = self.resolve_imported_symbols(symbol);
                    symbol.add_use(expr);
                    return self.get_type_of_symbol(symbol);
                }

            case uni.TypeRef():
                ty = self.get_type_of_expression(expr.target);
                if isinstance(ty, types.ClassType) {
                    return ty.clone_as_class();
                }

        }

        # TODO: More expressions.
        return types.UnknownType();
    }

    # -----------------------------------------------------------------------------
    # Helper functions
    # -----------------------------------------------------------------------------
    """Set symbol and type for a module item node and its alias if present."""
    def _set_module_item_symbol_and_type(
        self: TypeEvaluator, node_: uni.ModuleItem, sym: uni.Symbol
    ) -> TypeBase {
        node_.name.sym = sym;
        if node_.alias {
            node_.alias.sym = sym;
        }
        # Cache the type.
        node_.name.type = self.get_type_of_symbol(sym);
        return node_.name.type;
    }

    """Resolve the imported symbols to the actual symbol."""
    def resolve_imported_symbols(self: TypeEvaluator, sym: uni.Symbol) -> uni.Symbol {
        if (
            isinstance(sym.decl, uni.Name)
            and sym.decl.find_parent_of_type(uni.ModuleItem)
        ) {
            # If the symbol is from a module item, we need to resolve it to the actual symbol.
            mod_item = sym.decl.find_parent_of_type(uni.ModuleItem);
            assert (mod_item is not None);
            self.get_type_of_module(mod_item.from_mod_path);
            return (mod_item.name.sym or sym);
        }
        return sym;
    }

    def _set_symbol_to_expr(
        self: TypeEvaluator, expr: uni.Expr, sym: uni.Symbol
    ) -> TypeBase {
        sym.add_use(expr);
        expr.type = self.get_type_of_symbol(sym);
        return expr.type;
    }

    """Check if the expression is Name that is 'self' and in the method context."""
    def _is_expr_self(self: TypeEvaluator, expr: uni.Expr) -> bool {
        if (
            isinstance(expr, uni.Name)
            and (expr.value == TOKEN_MAP[Tok.KW_SELF])
            and (fn := self._get_enclosing_method(expr))
            and (not fn.is_static)
            and (not fn.is_cls_method)
        ) {
            return True;
        }
        return False;
    }

    """Get the enclosing function (ability) of the given node."""
    def _get_enclosing_function(
        self: TypeEvaluator, node: uni.UniNode
    ) -> uni.Ability | None {
        if (impl := node.find_parent_of_type(uni.ImplDef))
        and (isinstance(impl.decl_link, uni.Ability)) {
            return impl.decl_link;
        }
        return node.find_parent_of_type(uni.Ability);
    }

    """Get the enclosing method (ability) of the given node."""
    def _get_enclosing_method(
        self: TypeEvaluator, node: uni.UniNode
    ) -> uni.Ability | None {
        enclosing_fn = self._get_enclosing_function(node);
        while enclosing_fn and (not enclosing_fn.is_method) {
            enclosing_fn = self._get_enclosing_function(enclosing_fn);
        }
        if enclosing_fn and enclosing_fn.is_method {
            return enclosing_fn;
        }
        return None;
    }

    """Return the effective type of self."""
    def _get_type_of_self(self: TypeEvaluator, node_: uni.SpecialVarRef) -> TypeBase {
        if method := self._get_enclosing_method(node_) {
            cls = method.method_owner;
            if isinstance(cls, uni.Archetype) {
                node_.sym = type_utils.lookup_symtab(
                    method, node_.value, self.builtins_module
                );
                node_.type = self.get_type_of_class(cls).clone_as_instance();
                return node_.type;
            }
            if isinstance(cls, uni.Enum) {
                # TODO: Implement type from enum.
            }
        }
        return types.UnknownType();
    }

    """Return the effective type of root."""
    def _get_type_of_root(self: TypeEvaluator, node_: uni.SpecialVarRef) -> TypeBase {
        node_.sym = self.prefetch.root_class.get_class_symbol();
        node_.type = self.prefetch.root_class.clone_as_instance();
        return node_.type;
    }

    """Convert a class type to an instance type."""
    def _convert_to_instance(self: TypeEvaluator, jtype: TypeBase) -> TypeBase {
        # TODO: Grep pyright "Handle type[x] as a special case." They handle `type[x]` as a special case:
        #
        # foo: int = 42;       # <-- Here `int` is instantiable class and, become instance after this method.
        # foo: type[int] = int # <-- Here `type[int]`, this should be `int` that's instantiable.
        #
        if jtype.is_instantiable_class() {
            assert isinstance(jtype, types.ClassType);
            return jtype.clone_as_instance();
        }
        return jtype;
    }

    """Lookup the class member type."""
    def _lookup_class_member(
        self: TypeEvaluator, base_type: types.ClassType, member: str
    ) -> type_utils.ClassMember | None {
        # FIXME: Pyright's way: Implement class member iterator (based on mro and the multiple inheritance)
        # return the first found member from the iterator.

        # NOTE: This is a simple implementation to make it work and more robust implementation will
        # be done in a future PR.
        for cls in base_type.shared.mro {
            if sym := cls.lookup_member_symbol(member) {
                return type_utils.ClassMember(sym, cls);
            }
        }
        return None;
    }

    """Lookup the object member type."""
    def _lookup_object_member(
        self: TypeEvaluator, base_type: types.ClassType, member: str
    ) -> type_utils.ClassMember | None {
        assert self.prefetch.int_class is not None;
        if isinstance(base_type, types.ClassType) and base_type.is_class_instance() {
            # TODO: We need to implement Member lookup flags and set SkipInstanceMember to 0.
            return self._lookup_class_member(base_type, member);
        }
        return None;
    }

    """
    Match arguments passed to a function to the corresponding parameters in that function.

    This matching is done based on positions and keywords. Type evaluation and
    validation is left to the caller.
    This logic is based on PEP 3102: https://www.python.org/dev/peps/pep-3102/
    """
    def match_args_to_params(
        self: TypeEvaluator, expr: uni.FuncCall, func_type: types.FunctionType
    ) -> MatchArgsToParamsResult {
        arg_params: dict[uni.Expr | uni.KWPair, types.Parameter | None] = {};
        argument_errors = False;

        params_to_match = func_type.parameters.copy();

        # Skip `self` for method calls.
        if len(func_type.parameters) >= 1 and func_type.parameters[0].is_self {
            params_to_match.pop(0);
        }

        # Create a tracker for parameter assignment.
        param_tracker = type_utils.ParamAssignmentTracker(params_to_match);

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
        for arg in expr.params {
            try {
                if isinstance(arg, uni.KWPair) {
                    # Match parameter based on name lookup.
                    matching_param = param_tracker.match_named_argument(arg);
                    arg_params[arg] = matching_param;
                } else {  # Match parameter based on the position of the argument.

                    matching_param = param_tracker.match_positional_argument(arg);
                    arg_params[arg] = matching_param;
                }
            } except Exception as e {
                self.add_diagnostic(arg, str(e));
                argument_errors = True;
            }
        }

        if unmatched_params := param_tracker.get_unmatched_required_params() {
            names = ", ".join([f"'{p.name}'" for p in unmatched_params]);
            argument_errors = True;
            self.add_diagnostic(
                expr,
                f"Not all required parameters were provided in the function call: {names}",
            );
        }

        return MatchArgsToParamsResult(
            arg_params=arg_params, argument_errors=argument_errors
        );
    }

    """
    Validate that the arguments can be assigned to the call's parameter list.

    Specializes the call based on arg types, and returns the specialized
    type of the return value. If it detects an error along the way, it emits
    a diagnostic and sets argumentErrors to true.
    """
    def validate_call_args(self: TypeEvaluator, expr: uni.FuncCall) -> TypeBase {
        caller_type = self.get_type_of_expression(expr.target);

        # 1. Call to a function.
        if isinstance(caller_type, types.FunctionType) {
            arg_param_match = self.match_args_to_params(expr, caller_type);
            if not arg_param_match.argument_errors {
                self.validate_arg_types(arg_param_match);
            }
            return caller_type.return_type or types.UnknownType();
        }

        # 2. Call to TypeVar.
        if isinstance(caller_type, types.ClassType)
        and caller_type.shared == (
            self.prefetch and self.prefetch.type_var_class.shared
        ) {
            # TODO: validate the args and pass the typevar name.
            return types.TypeVarType();
        }

        # 3. Call to an instantiable class.
        if (
            isinstance(caller_type, types.ClassType)
            and caller_type.is_instantiable_class()
        ) {
            # TODO: validate args for __init__()

            # If it has __init__ method, try to call it.
            if init_method := self._lookup_class_member(caller_type, "__init__") {
                init_fn_type = self.get_type_of_symbol(init_method.symbol);
                if isinstance(init_fn_type, types.FunctionType) {
                    arg_param_match = self.match_args_to_params(expr, init_fn_type);
                    if not arg_param_match.argument_errors {
                        self.validate_arg_types(arg_param_match);
                    }
                }
            } elif caller_type.is_data_class() {
                init_fn_type = self._create_dataclass_init_method(caller_type);
                arg_param_match = self.match_args_to_params(expr, init_fn_type);
                if not arg_param_match.argument_errors {
                    self.validate_arg_types(arg_param_match);
                }
            }
            return caller_type.clone_as_instance();
        }

        # 4. Call to a callable object (__call__).
        if caller_type.is_class_instance() {
            # TODO: validate args.
            magic_call_ret = self.get_type_of_magic_method_call(
                caller_type, "__call__"
            );
            if magic_call_ret {
                return magic_call_ret;
            }
        }

        return types.UnknownType();
    }

    """Validate that the argument types can be assigned to the parameter types."""
    def validate_arg_types(self: TypeEvaluator, args: MatchArgsToParamsResult) -> None {
        for (arg, param) in args.arg_params.items() {
            if param is None or param.param_type is None {
                continue;
            }
            if isinstance(arg, uni.KWPair) {
                arg_type = self.get_type_of_expression(arg.value);
            } else {
                arg_type = self.get_type_of_expression(arg);
            }

            if not self.assign_type(arg_type, param.param_type) {
                self.add_diagnostic(
                    arg,
                    f"Cannot assign {arg_type} to parameter '{param.name}' of type {param.param_type}",
                );
            }
        }
    }

    def _create_dataclass_init_method(
        self: TypeEvaluator, class_type: types.ClassType
    ) -> types.FunctionType {
        parameters: list[types.Parameter] = [];

        for cls in class_type.shared.mro[::-1] {
            # Iterate over the has vars and create parameters.
            for has_var in cls.shared.symbol_table.get_has_vars() {
                # Get parameter type.
                param_type: TypeBase | None = None;
                if has_var.type_tag {
                    var_type_expr = has_var.type_tag.tag;
                    type_cls = self.get_type_of_expression(var_type_expr);
                    param_type = self._convert_to_instance(type_cls);
                }

                # Create parameter.
                parameters.append(
                    types.Parameter(
                        name=has_var.name.value,
                        category=types.ParameterCategory.Positional,
                        param_type=param_type,
                        default_value=has_var.value,
                        is_self=False,
                        param_kind=types.ParamKind.NORMAL,
                    )
                );
            }
        }

        # Create and return the __init__ method type.
        return types.FunctionType(
            func_name="__init__",
            return_type=types.UnknownType(),
            parameters=parameters,
        );
    }
}
# FIXME: This class implementation is modified from pyright to make it
# simple and work for now, however this needs to be revisited and
# implemented properly.

# NOTE: This is done in the binder pass of pyright, however I'm doing this
# here, cause this will be the entry point of the type checker and we're not
# relying on the binder pass at the moment and we can go back to binder pass
# in the future if we needed it.
