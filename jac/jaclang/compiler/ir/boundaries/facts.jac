obj ImportBoundaryFacts {
    has native_from_path: (str | None) = None,
        from_loc_resolved: (str | None) = None,
        is_service: bool = False,
        pinned_server: bool = False,
        client_native_edge: bool = False,
        sv_abilities: dict[(str, Ability)] = {},
        sv_walkers: dict[(str, Archetype)] = {},
        na_target_decls: dict[(str, Ability)] = {},
        na_unmappable_targets: list[str] = [],
        native_absorb_path: (str | None) = None,
        native_item_paths: dict[(str, str)] = {},
        bridged_decls: dict[(str, Ability)] = {},
        cross_app_kind: str = "local";
}
