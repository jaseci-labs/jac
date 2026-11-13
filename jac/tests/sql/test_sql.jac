import from .sql_cases { SQLTests, run_case }

test "SQLite: module is portable with implementation" {
    run_case(SQLTests("test_module_is_portable_with_implementation"));
}

test "SQLite: select parameters and order" {
    run_case(SQLTests("test_select_parameters_and_order"));
}

test "SQLite: join and shared parameter" {
    run_case(SQLTests("test_join_and_shared_parameter"));
}

test "SQLite: group by count" {
    run_case(SQLTests("test_group_by_count"));
}

test "SQLite: aggregate empty is one row" {
    run_case(SQLTests("test_aggregate_empty_is_one_row"));
}

test "SQLite: scalar optional empty yields null" {
    run_case(SQLTests("test_scalar_optional_empty_yields_null"));
}

test "SQLite: scalar requires proof and one column" {
    run_case(SQLTests("test_scalar_requires_proof_and_one_column"));
}

test "SQLite: correlated exists" {
    run_case(SQLTests("test_correlated_exists"));
}

test "SQLite: derived schema and scope" {
    run_case(SQLTests("test_derived_schema_and_scope"));
}

test "SQLite: union schema and arm limits" {
    run_case(SQLTests("test_union_schema_and_arm_limits"));
}

test "SQLite: cte" {
    run_case(SQLTests("test_cte"));
}

test "SQLite: recursive cte" {
    run_case(SQLTests("test_recursive_cte"));
}

test "SQLite: cte dependencies and recursive anchor validation" {
    run_case(SQLTests("test_cte_dependencies_and_recursive_anchor_validation"));
}

test "SQLite: recursive step eligibility" {
    run_case(SQLTests("test_recursive_step_eligibility"));
}

test "SQLite: nullable three valued predicate" {
    run_case(SQLTests("test_nullable_three_valued_predicate"));
}

test "SQLite: parameter value type and bounds" {
    run_case(SQLTests("test_parameter_value_type_and_bounds"));
}

test "SQLite: injection is bound and identifiers are quoted" {
    run_case(SQLTests("test_injection_is_bound_and_identifiers_are_quoted"));
}

test "SQLite: wrong expression categories and types" {
    run_case(SQLTests("test_wrong_expression_categories_and_types"));
}

test "SQLite: alias and join scopes" {
    run_case(SQLTests("test_alias_and_join_scopes"));
}

test "SQLite: aggregate validation" {
    run_case(SQLTests("test_aggregate_validation"));
}

test "SQLite: compiled query survives ast edits" {
    run_case(SQLTests("test_compiled_query_survives_ast_edits"));
}

test "SQLite: source field schema validation" {
    run_case(SQLTests("test_source_field_schema_validation"));
}

test "SQLite: edited projection type is checked" {
    run_case(SQLTests("test_edited_projection_type_is_checked"));
}

test "SQLite: derived schema comes from query" {
    run_case(SQLTests("test_derived_schema_comes_from_query"));
}

test "SQLite: edited projection nullability is checked" {
    run_case(SQLTests("test_edited_projection_nullability_is_checked"));
}

test "SQLite: query rebuild preserves original" {
    run_case(SQLTests("test_query_rebuild_preserves_original"));
}

test "SQLite: recursive anchor clauses limit" {
    run_case(SQLTests("test_recursive_anchor_limit"));
}

test "SQLite: recursive anchor clauses order" {
    run_case(SQLTests("test_recursive_anchor_order"));
}

test "SQLite: recursive anchor clauses order and limit" {
    run_case(SQLTests("test_recursive_anchor_order_limit"));
}

test "SQLite: cte names do not capture physical tables" {
    run_case(SQLTests("test_cte_names_do_not_capture_physical_tables"));
}

test "SQLite: generated names avoid physical prefixes" {
    run_case(SQLTests("test_generated_names_avoid_physical_prefixes"));
}

test "SQLite: cte reuse and independent bindings" {
    run_case(SQLTests("test_cte_reuse_and_independent_bindings"));
}

test "SQLite: distinct cte objects have distinct names" {
    run_case(SQLTests("test_distinct_cte_objects_have_distinct_names"));
}

test "SQLite: cte dependencies in subqueries" {
    run_case(SQLTests("test_cte_dependencies_in_subqueries"));
}

test "SQLite: cte missing definition cycles and redefinition" {
    run_case(SQLTests("test_cte_missing_definition_cycles_and_redefinition"));
}

test "SQLite: cte cannot capture outer columns" {
    run_case(SQLTests("test_cte_cannot_capture_outer_columns"));
}

test "SQLite: generated names are deterministic" {
    run_case(SQLTests("test_generated_names_are_deterministic"));
}

test "SQLite: auto source aliases for self join" {
    run_case(SQLTests("test_auto_source_aliases_for_self_join"));
}

test "SQLite: edited recursive union is checked" {
    run_case(SQLTests("test_edited_recursive_union_is_checked"));
}

test "SQLite: recursive step can be reused" {
    run_case(SQLTests("test_recursive_step_can_be_reused"));
}

test "SQLite: cte bindings share target schema" {
    run_case(SQLTests("test_cte_bindings_share_target_schema"));
}

test "SQLite: correlated aggregate local grouping" {
    run_case(SQLTests("test_correlated_aggregate_local_grouping"));
}

test "SQLite: constructor inputs are snapshotted" {
    run_case(SQLTests("test_constructor_inputs_are_snapshotted"));
}

test "SQLite: validation precedes rendering" {
    run_case(SQLTests("test_validation_precedes_rendering"));
}

test "SQLite: invalid raw nodes are rejected" {
    run_case(SQLTests("test_invalid_raw_nodes_are_rejected"));
}

test "SQLite: empty membership preserves aggregate rows" {
    run_case(SQLTests("test_empty_membership_preserves_aggregate_rows"));
}

test "SQLite: windows over grouped counts" {
    run_case(SQLTests("test_windows_over_grouped_counts"));
}

test "SQLite: windows preserve implicit group proof" {
    run_case(SQLTests("test_windows_preserve_implicit_group_proof"));
}

test "SQLite: grouped windows keep stage checks" {
    run_case(SQLTests("test_grouped_windows_keep_stage_checks"));
}

test "SQLite: named slot rebind" {
    run_case(SQLTests("test_named_slot_rebind"));
}

test "SQLite: named slot literal_collision" {
    run_case(SQLTests("test_named_slot_literal_collision"));
}

test "SQLite: named slot names_are_validated" {
    run_case(SQLTests("test_named_slot_names_are_validated"));
}

test "SQLite: named slot conflicting_types" {
    run_case(SQLTests("test_named_slot_conflicting_types"));
}

test "SQLite: named slot bind_checks" {
    run_case(SQLTests("test_named_slot_bind_checks"));
}

test "SQLite: named slot does_not_retain_ast" {
    run_case(SQLTests("test_named_slot_does_not_retain_ast"));
}

test "SQLite: named slot injection_is_bound" {
    run_case(SQLTests("test_named_slot_injection_is_bound"));
}


test "SQLite: sort options are closed" {
    run_case(SQLTests("test_sort_options_are_closed"));
}


test "SQLite: exactly one is checked at construction" {
    run_case(SQLTests("test_exactly_one_is_checked_at_construction"));
}
