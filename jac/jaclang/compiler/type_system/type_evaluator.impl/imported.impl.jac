"""Return the effective type of the module item."""

impl TypeEvaluator.get_type_of_module_item(node_: uni.ModuleItem) -> types.TypeBase {
    # Module item can be both a module or a member of a module.
    # import from .. { mod }   # <-- Here mod is not a member but a module itself.
    # import from mod { item } # <-- Here item is not a module but a member of mod.
    # Note: node_.name can be a Token (for default/star imports) or a Name node.
    # Only Name nodes have a .type attribute.
    if isinstance(node_.name, uni.Name) and node_.name.type is not None {
        return node_.name.type;
    }
    # TODO: Implement proper type resolution for default/star imports.
    if isinstance(node_.name, uni.Name) { } else {
        return types.UnknownType();
    }
    import_node = node_.parent_of_type(uni.Import);
    assert import_node.from_loc is not None;
    # Resolve the base directory for the from-clause (e.g. from . import utils → current dir).
    from_path = self._resolve_from_path(import_node.from_loc);
    from_mod_type = self.get_type_of_module(import_node.from_loc);
    if isinstance(from_mod_type, types.ModuleType) or from_path.exists() {
        is_dir = from_path.is_dir() or (from_path.stem == "__init__");
        if is_dir {
            mod_dir = from_path.parent if not from_path.is_dir() else from_path;
            for ext in (".jac", ".py", ".pyi", ".js", ".ts", ".jsx", ".tsx") {
                candidate_paths = [
                    (mod_dir / f"{node_.name.value}{ext}").resolve(),
                    # Check for subpackage: e.g., llvmlite/ir/__init__.py
                    (mod_dir / node_.name.value / f"__init__{ext}").resolve(),
                    (mod_dir / f"__init__{ext}").resolve(),

                ];

                for path in candidate_paths {
                    if not path.exists() {
                        continue;
                    }
                    mod = self._import_module_from_path(str(path));

                    # Check if this is a subpackage's __init__ file (e.g., subpkg/__init__.py)
                    # vs the parent module's __init__ file
                    is_subpackage_init = (
                        path.name.startswith("__init__")
                        and path.parent.name == node_.name.value
                    );
                    is_parent_init = (
                        path.name.startswith("__init__")
                        and path.parent.name != node_.name.value
                    );

                    if is_parent_init {
                        # Look up the symbol in the parent's __init__.py
                        if sym := type_utils.lookup_symtab(
                            mod, node_.name.value, self.builtins_module
                        ) {
                            return self._set_module_item_symbol_and_type(node_, sym);
                        }
                        # Fallback: follow star imports (from .submod import *)
                        # to find re-exported symbols (e.g., asyncio.Queue from asyncio.queues).
                        if sym := self._resolve_star_import_symbol(
                            mod, node_.name.value
                        ) {
                            return self._set_module_item_symbol_and_type(node_, sym);
                        }
                        continue;
                    }

                    # For regular modules and subpackage __init__.py, create ModuleType
                    flags = type_utils.compute_module_source_flags(str(path));
                    mod_type = types.ModuleType(
                        mod_name=node_.name.sym_name,
                        file_uri=path,
                        symbol_table=mod,
                        is_stub_file=flags.is_stub_file,
                        is_stdlib_stub=flags.is_stdlib_stub,
                        is_typing_stub=flags.is_typing_stub,
                        is_builtin_stub=flags.is_builtin_stub,
                    );

                    node_.name.type = mod_type;

                    node_.name._sym_category = SymbolType.MODULE;
                    return mod_type;
                }
            }
        } else {
            mod_type = self.get_type_of_module(import_node.from_loc);
            if not isinstance(mod_type, types.ModuleType) {
                node_.name.type = types.UnknownType();
                return node_.name.type;
            }
            if sym := type_utils.lookup_symtab(
                mod_type.symbol_table, node_.name.value, self.builtins_module
            ) {
                return self._set_module_item_symbol_and_type(node_, sym);
            }
            # Fallback: follow star imports for re-exported symbols.
            if isinstance(mod_type.symbol_table, uni.Module) {
                if sym := self._resolve_star_import_symbol(
                    mod_type.symbol_table, node_.name.value
                ) {
                    return self._set_module_item_symbol_and_type(node_, sym);
                }
            }
        }
    }
    return types.UnknownType();
}

"""Resolve a symbol through star imports (from .X import *) in a module.

Python packages like asyncio re-export symbols from submodules via star imports
in __init__.pyi. When a direct lookup in the module's symbol table fails, this
method follows star imports to find the symbol in submodules. Uses a visited set
to prevent infinite recursion from circular star imports.
"""
impl TypeEvaluator._resolve_star_import_symbol(
    mod: uni.Module, name: str, visited: set[int] | None = None
) -> uni.Symbol | None {
    mod_id = id(mod);
    if visited is None {
        visited = set();
    }
    if mod_id in visited {
        return None;
    }
    visited.add(mod_id);
    for imp in mod.get_all_sub_nodes(uni.Import) {
        if not imp.is_absorb or not imp.items {
            continue;
        }
        # Star imports store the source module path in items[0] (a ModulePath).
        star_mod_path = imp.items[0];
        if not isinstance(star_mod_path, uni.ModulePath) {
            continue;
        }
        # Resolve the submodule path (e.g., .queues -> asyncio/queues.pyi).
        resolved = star_mod_path.resolve_relative_path_list();
        if not resolved or len(resolved) < 2 {
            continue;
        }
        submod_base = resolved[-1];  # e.g., ".../asyncio/queues"
        # Try common extensions to find the actual file.
        submod: uni.Module | None = None;
        for ext in (".pyi", ".py", ".jac") {
            candidate = submod_base + ext;
            if Path(candidate).exists() {
                submod = self._import_module_from_path(candidate);
                break;
            }
        }
        if submod is None {
            continue;
        }
        # Look up the symbol in the submodule.
        if sym := type_utils.lookup_symtab(submod, name, self.builtins_module) {
            return sym;
        }
        # Recursively follow star imports in the submodule.
        if sym := self._resolve_star_import_symbol(submod, name, visited) {
            return sym;
        }
    }
    return None;
}

"""Return the effective type of the module."""
impl TypeEvaluator.get_type_of_module(node_: uni.ModulePath) -> types.TypeBase {
    if node_.path {
        if node_.path[-1].type {
            return node_.path[-1].type;
        }
        path_list = node_.resolve_relative_path_list();
        # Calculate offset for relative imports from Python packages:
        # leading dots produce extra segments in resolve_relative_path_list()
        # that don't have corresponding entries in node_.path.
        # E.g., "from .base import X" has path=[base] but path_list=[__init__.py, base.jac]
        # Only apply offset when importing from Python __init__.py (not jaclang internals)
        # to avoid circular import issues during compiler bootstrap.
        offset = 0;
        if node_.path and len(path_list) > len(node_.path) and node_.level > 0 {
            first_path = path_list[0] if path_list else "";
            # Only for Python __init__ files, not Jac __init__.jac
            is_python_init = first_path.endswith(("__init__.py", "__init__.pyi"));
            if is_python_init {
                offset = len(path_list) - len(node_.path);
            }
        }
        for (idx, npath) in enumerate(node_.path) {
            mod_path = path_list[idx + offset];

            if mod_path in self._module_type_cache {
                npath.type = self._module_type_cache[mod_path];
                npath._sym_category = SymbolType.MODULE;
                continue;
            }

            if not Path(mod_path).exists() {
                # For intermediate path segments (not the last), skip rather than
                # bail out. Namespace packages and directory-based imports may not
                # resolve individually but the full path (last segment) may still
                # resolve correctly.
                npath._sym_category = SymbolType.MODULE;
                if idx < len(node_.path) - 1 {
                    continue;
                }
                npath.type = types.UnknownType();
                self.emit_diag(W1100, npath);
                return npath.type;
            }

            if Path(mod_path).is_dir() {
                npath._sym_category = SymbolType.MODULE;
                continue;
            }
            mod: uni.Module = self._import_module_from_path(mod_path);
            flags = type_utils.compute_module_source_flags(mod_path);
            mod_type = types.ModuleType(
                mod_name=npath.value,
                file_uri=Path(mod_path).resolve(),
                symbol_table=mod,
                is_stub_file=flags.is_stub_file,
                is_stdlib_stub=flags.is_stdlib_stub,
                is_typing_stub=flags.is_typing_stub,
                is_builtin_stub=flags.is_builtin_stub,
            );
            npath.type = mod_type;
            npath._sym_category = SymbolType.MODULE;

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

"""Import a module from the given path."""
impl TypeEvaluator._import_module_from_path(path: str) -> uni.Module {
    # "../os/path.pyi" and "/abs/os/path.pyi" are the same file but different strings.
    # resolve() converts both to "/abs/os/path.pyi" so hub always returns the same cached module.
    resolved_path = str(Path(path).resolve());
    # Determine the correct hub: jaclang-internal imports (typeshed stubs,
    # compiler modules, etc.) go to the compiler's internal hub so they
    # don't pollute the user's module hub.
    compiler = self.program._get_compiler();
    target_program = compiler._resolve_program(resolved_path, self.program);
    target_hub = target_program.mod.hub;
    mod: uni.Module;
    if resolved_path in self.program.mod.hub {
        mod = self.program.mod.hub[resolved_path];
    } elif resolved_path in target_hub {
        mod = target_hub[resolved_path];
    } else {
        # Try JIR cache first for .jac files
        jir_mod: (uni.Module | None) = None;
        if resolved_path.endswith('.jac') {
            jir_mod = self._try_read_jir_cache(resolved_path);
        }
        if jir_mod is not None {
            mod = jir_mod;
            if mod.parent_scope is None and mod is not self.builtins_module {
                mod.parent_scope = self.builtins_module;
            }
            target_hub[resolved_path] = mod;
        } else {
            # Cache miss — full compile
            mod = self.program.compile(
                path, no_cgen=True, type_check=False, symtab_ir_only=True
            );
            if mod.parent_scope is None and mod is not self.builtins_module {
                mod.parent_scope = self.builtins_module;
            }
            target_hub[resolved_path] = mod;
            # Write JIR module cache for .jac files (best-effort).
            # Only write if no valid cache exists yet — symtab-only compiles
            # lack bytecode and must not overwrite a full cache that has it.
            if resolved_path.endswith('.jac') {
                try {
                    import from jaclang.jac0core.jir {
                        get_module_cache_path,
                        is_module_cache_valid,
                        SEC_BYTECODE
                    }
                    import from jaclang.jac0core.jir_passes { JirWriter }
                    cache_path = get_module_cache_path(resolved_path);
                    if not is_module_cache_valid(resolved_path, cache_path) {
                        cache_path.parent.mkdir(parents=True, exist_ok=True);
                        writer = JirWriter();
                        sections: (dict[int, bytes] | None) = None;
                        bc = getattr(mod.gen, 'py_bytecode', None);
                        if bc is not None {
                            sections = {SEC_BYTECODE: bc};
                        }
                        jir_bytes = writer.write_module(mod, sections=sections);
                        tmp_path = cache_path.with_suffix('.tmp');
                        tmp_path.write_bytes(jir_bytes);
                        tmp_path.rename(cache_path);
                    }
                } except Exception {
                    ;
                }
            }
        }
    }
    return mod;
}

"""Try to read a compiled .jac module from the JIR cache. Returns None on any failure."""
impl TypeEvaluator._try_read_jir_cache(resolved_path: str) -> (uni.Module | None) {
    import from jaclang.jac0core.jir { get_module_cache_path, is_module_cache_valid }
    import from jaclang.jac0core.jir_passes { JirReader }
    import traceback;
    try {
        cache_path = get_module_cache_path(resolved_path);
        if not is_module_cache_valid(resolved_path, cache_path) {
            return None;
        }
        data = cache_path.read_bytes();
        reader = JirReader(_source_path=resolved_path);
        mod = reader.read_module(data);

        # Re-attach impl modules after JIR load.
        # JIR doesn't serialize impl_mod, so symbols defined in impl files
        # (e.g., self.x = value in __init__) would be lost. Re-discover and
        # re-attach impl files, then re-run DeclImplMatchPass to restore them.
        if mod is not None and resolved_path.endswith('.jac') {
            self._reattach_impl_modules(mod, resolved_path);
        }

        return mod;
    } except Exception {
        # Log but don't crash — fall back to full compile
        traceback.print_exc();
        return None;
    }
}

"""Re-attach impl modules after JIR load to restore impl-defined symbols."""
impl TypeEvaluator._reattach_impl_modules(mod: uni.Module, source_path: str) -> None {
    import from jaclang.jac0core.bccache { discover_annex_files }
    import from jaclang.jac0core.passes { DeclImplMatchPass }

    # Skip annex files (they don't have their own annexes)
    if source_path.endswith('.impl.jac')
    or source_path.endswith('.test.jac')
    or mod.annexable_by is not None {
        return;
    }

    # Compile impl files fresh (impl symbol defn nodes aren't serialized in JIR)
    for impl_path in discover_annex_files(source_path, '.impl.jac') {
        impl_mod = self.program.compile(
            impl_path, no_cgen=True, type_check=False, symtab_ir_only=True
        );
        if impl_mod is not None and impl_mod not in mod.impl_mod {
            mod.impl_mod.append(impl_mod);
            impl_mod.parent_scope = mod;
        }
    }

    # Re-run DeclImplMatchPass to restore instance variable symbols (e.g., self.x in __init__)
    if mod.impl_mod {
        DeclImplMatchPass(ir_in=mod, prog=self.program);
    }
}

"""Return the effective type of the symbol."""
impl TypeEvaluator.get_type_of_symbol(symbol: uni.Symbol) -> TypeBase {
    if self.push_symbol_resolution(symbol) {
        try {
            result = self._get_type_of_symbol(symbol);
            return result;
        } finally {
            self.pop_symbol_resolution(symbol);
        }
    }
    return types.UnknownType();
}
