import from .postgres_cases { PostgresTests }
import from .sql_cases { run_case }

test "PostgreSQL: module is portable with implementation" {
    run_case(PostgresTests("test_module_is_portable_with_implementation"));
}

test "PostgreSQL: select parameters and order" {
    run_case(PostgresTests("test_select_parameters_and_order"));
}

test "PostgreSQL: join and shared parameter" {
    run_case(PostgresTests("test_join_and_shared_parameter"));
}

test "PostgreSQL: group by count" {
    run_case(PostgresTests("test_group_by_count"));
}

test "PostgreSQL: aggregate empty is one row" {
    run_case(PostgresTests("test_aggregate_empty_is_one_row"));
}

test "PostgreSQL: scalar optional empty yields null" {
    run_case(PostgresTests("test_scalar_optional_empty_yields_null"));
}

test "PostgreSQL: scalar requires proof and one column" {
    run_case(PostgresTests("test_scalar_requires_proof_and_one_column"));
}

test "PostgreSQL: correlated exists" {
    run_case(PostgresTests("test_correlated_exists"));
}

test "PostgreSQL: derived schema and scope" {
    run_case(PostgresTests("test_derived_schema_and_scope"));
}

test "PostgreSQL: union schema and arm limits" {
    run_case(PostgresTests("test_union_schema_and_arm_limits"));
}

test "PostgreSQL: cte" {
    run_case(PostgresTests("test_cte"));
}

test "PostgreSQL: recursive cte" {
    run_case(PostgresTests("test_recursive_cte"));
}

test "PostgreSQL: cte dependencies and recursive anchor validation" {
    run_case(PostgresTests("test_cte_dependencies_and_recursive_anchor_validation"));
}

test "PostgreSQL: recursive step eligibility" {
    run_case(PostgresTests("test_recursive_step_eligibility"));
}

test "PostgreSQL: nullable three valued predicate" {
    run_case(PostgresTests("test_nullable_three_valued_predicate"));
}

test "PostgreSQL: parameter value type and bounds" {
    run_case(PostgresTests("test_parameter_value_type_and_bounds"));
}

test "PostgreSQL: injection is bound and identifiers are quoted" {
    run_case(PostgresTests("test_injection_is_bound_and_identifiers_are_quoted"));
}

test "PostgreSQL: wrong expression categories and types" {
    run_case(PostgresTests("test_wrong_expression_categories_and_types"));
}

test "PostgreSQL: alias and join scopes" {
    run_case(PostgresTests("test_alias_and_join_scopes"));
}

test "PostgreSQL: aggregate validation" {
    run_case(PostgresTests("test_aggregate_validation"));
}

test "PostgreSQL: query and expression are immutable" {
    run_case(PostgresTests("test_query_and_expression_are_immutable"));
}

test "PostgreSQL: source field schema validation" {
    run_case(PostgresTests("test_source_field_schema_validation"));
}

test "PostgreSQL: projection expression is immutable" {
    run_case(PostgresTests("test_projection_expression_is_immutable"));
}

test "PostgreSQL: derived schema comes from query" {
    run_case(PostgresTests("test_derived_schema_comes_from_query"));
}

test "PostgreSQL: projection nullability is immutable" {
    run_case(PostgresTests("test_projection_nullability_is_immutable"));
}

test "PostgreSQL: query rebuild preserves original" {
    run_case(PostgresTests("test_query_rebuild_preserves_original"));
}

test "PostgreSQL: recursive anchor clauses limit" {
    run_case(PostgresTests("test_recursive_anchor_limit"));
}

test "PostgreSQL: recursive anchor clauses order" {
    run_case(PostgresTests("test_recursive_anchor_order"));
}

test "PostgreSQL: recursive anchor clauses order and limit" {
    run_case(PostgresTests("test_recursive_anchor_order_limit"));
}

test "PostgreSQL: cte names do not capture physical tables" {
    run_case(PostgresTests("test_cte_names_do_not_capture_physical_tables"));
}

test "PostgreSQL: generated names avoid physical prefixes" {
    run_case(PostgresTests("test_generated_names_avoid_physical_prefixes"));
}

test "PostgreSQL: cte reuse and independent bindings" {
    run_case(PostgresTests("test_cte_reuse_and_independent_bindings"));
}

test "PostgreSQL: distinct cte objects have distinct names" {
    run_case(PostgresTests("test_distinct_cte_objects_have_distinct_names"));
}

test "PostgreSQL: cte dependencies in subqueries" {
    run_case(PostgresTests("test_cte_dependencies_in_subqueries"));
}

test "PostgreSQL: cte missing definition cycles and redefinition" {
    run_case(PostgresTests("test_cte_missing_definition_cycles_and_redefinition"));
}

test "PostgreSQL: cte cannot capture outer columns" {
    run_case(PostgresTests("test_cte_cannot_capture_outer_columns"));
}

test "PostgreSQL: generated names are deterministic" {
    run_case(PostgresTests("test_generated_names_are_deterministic"));
}

test "PostgreSQL: auto source aliases for self join" {
    run_case(PostgresTests("test_auto_source_aliases_for_self_join"));
}

test "PostgreSQL: recursive union is immutable" {
    run_case(PostgresTests("test_recursive_union_is_immutable"));
}

test "PostgreSQL: recursive step can be reused" {
    run_case(PostgresTests("test_recursive_step_can_be_reused"));
}

test "PostgreSQL: cte bindings share target schema" {
    run_case(PostgresTests("test_cte_bindings_share_target_schema"));
}

test "PostgreSQL: correlated aggregate local grouping" {
    run_case(PostgresTests("test_correlated_aggregate_local_grouping"));
}

test "PostgreSQL: constructor inputs are snapshotted" {
    run_case(PostgresTests("test_constructor_inputs_are_snapshotted"));
}

test "PostgreSQL: validation precedes rendering" {
    run_case(PostgresTests("test_validation_precedes_rendering"));
}

test "PostgreSQL: invalid raw nodes are rejected" {
    run_case(PostgresTests("test_invalid_raw_nodes_are_rejected"));
}

test "PostgreSQL: empty membership preserves aggregate rows" {
    run_case(PostgresTests("test_empty_membership_preserves_aggregate_rows"));
}

test "PostgreSQL: windows over grouped counts" {
    run_case(PostgresTests("test_windows_over_grouped_counts"));
}

test "PostgreSQL: windows preserve implicit group proof" {
    run_case(PostgresTests("test_windows_preserve_implicit_group_proof"));
}

test "PostgreSQL: grouped windows keep stage checks" {
    run_case(PostgresTests("test_grouped_windows_keep_stage_checks"));
}

test "PostgreSQL: named slot rebind" {
    run_case(PostgresTests("test_named_slot_rebind"));
}

test "PostgreSQL: named slot literal_collision" {
    run_case(PostgresTests("test_named_slot_literal_collision"));
}

test "PostgreSQL: named slot names_are_validated" {
    run_case(PostgresTests("test_named_slot_names_are_validated"));
}

test "PostgreSQL: named slot conflicting_types" {
    run_case(PostgresTests("test_named_slot_conflicting_types"));
}

test "PostgreSQL: named slot bind_checks" {
    run_case(PostgresTests("test_named_slot_bind_checks"));
}

test "PostgreSQL: named slot does_not_retain_ast" {
    run_case(PostgresTests("test_named_slot_does_not_retain_ast"));
}

test "PostgreSQL: named slot injection_is_bound" {
    run_case(PostgresTests("test_named_slot_injection_is_bound"));
}
