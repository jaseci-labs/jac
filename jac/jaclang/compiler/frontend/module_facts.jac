obj ModuleFacts {
    static def ability_is_generator(ability: Ability) -> bool;
    static def literal_exports(module: Module) -> set[str] | None;
    static def exported_import_names(module: Module) -> dict[str, set[str]];
    static def unwrap_body(
        nd: Archetype | Enum | Ability | ImplDef
    ) -> (Sequence[UniNode] | None);

    static def merged_body(module: Module) -> list[UniNode];
    static def iter_woven_segments(module: Module) -> list[tuple[list[UniNode], bool]];
    static def iter_context_stmts(
        module: Module, ctx: (CodeContext | None) = None
    ) -> list[ElementStmt];

    static def iter_placement_stmts(module: Module) -> list[UniNode];
    static def is_test_code(nd: UniNode) -> bool;
    static def iter_module_imports(
        module: Module, ctx: (CodeContext | None) = None
    ) -> list[Import];

    static def iter_nested_imports(
        module: Module, ctx: (CodeContext | None) = None
    ) -> list[Import];

    static def has_native_context_stmts(module: Module) -> bool;
    static def is_type_alias_decl(assign: Assignment) -> bool;
    static def is_type_param_decl(assign: Assignment) -> bool;
    static def is_erased_type_decl(assign: Assignment) -> bool;
    static def archetype_refs(nd: UniNode) -> list[str];
    static def shared_archetypes_for_context(
        module: Module, ctx: CodeContext
    ) -> list[Archetype];
}

def client_capability_violations(mod: Module) -> list[tuple[(UniNode, str)]];
