# Compiler tests on the kernel (#10471 step 15)

With a kernel loaded, the kernel is the only compiler: `JacProgram().compile(...)`
asks the kernel and adopts its result, so a host test sees a module stub, not
the compiler's tree. Tests take one of two forms.

- **Compile-and-check tests** compile or check through the kernel's entries and
  assert on what comes back: `KernelDiagnostic` records, `CompiledUnit`
  products (`bytecode`, `python_source`, `client_js`, `native_ir`,
  `native_iface`, `interop`, `sections`), coverage and placement rows, module
  facts, or session answers. They run with or without a kernel: without one,
  `project/kernel_call.jac` serves the same request in process.
- **Internals tests** inspect compiler data structures: the unitree, symbol
  tables, types, pass outputs and layouts. They need the compiler's own
  objects.

## Where internals tests run until step 17

`[test] bytecode_compiler` in the root `jac.toml` lists the files and
directories that hold internals tests. `jac test` runs them in a child process
with the kernel left out (`JAC_KIT_OMIT=kernel`), on the bytecode-hosted
compiler, which is built from the same Jac sources as the kernel. A `!`
pattern takes a file back out, and the last matching pattern wins, as in
`[native] require`. When no kernel is loaded at all, every file runs in one
process.

A test that watches the kernel's own entry points (for example by patching
`jac_kernel.compile`) calls `tests.support.loaded_kernel()`, which skips it on
a kit that leaves the kernel out.

Step 17 deletes the bytecode-hosted compiler. Before it can, every internals
test in the tables below moves into the kernel as a kernel test case.

## The helpers

All of them are in `jac/tests/support.jac`.

| Need | Helper |
|---|---|
| Diagnostics for a file or a source string | `kernel_check_file(path, options, native_coverage, placements, closure, sources)`, `kernel_check_source(source, name, options)`, then `error_codes`, `warning_codes`, `diagnostics_text`, `has_error_code`, `has_warning_code` |
| Products of a compile | `kernel_compile_file(path, options, products, sources)`, `kernel_compile_source(...)`, then `result.unit(path)`; `unit_code(unit)` is the unit's code object |
| Module facts | `project.kernel_compile.kernel_module_facts(...)`, then `result.module_fact(path)`; `kernel_module_spaces(...)` for each module's code spaces |
| A scratch source file | `write_case(source, name)` |
| Python parsed the way the compiler parses it | `python_tree(source, path)` |
| JIT a native fixture | `compile_native(fixture, fixture_dir)`, plus `get_func`, `native_str_func`, `native_address`, `runtime_address` |
| Tooling features | `project.kernel_call.tool_session(root)`, then `update`, `diagnostics`, `hover`, `definition`, `references`, `completion`, `semantic_tokens`, `inlay_hints`, `symbols`, `rename`, `format`, `lint_fix`, `strip_markers`, `access_plan` |

## Kernel test cases (step 17)

The draft (#10489, commit aad415b0df) designed the in-kernel harness and
wrote three suites that this list carries forward:

- **Where they live.** A suite is a module in `jaclang/compiler/kernel_tests/`.
  Its cases are plain functions that raise on failure, listed by a
  `<topic>_cases() -> list[KernelCase]` function.
  `compiler/kernel_testing.jac` lists every suite and runs one case at a time
  in its own scratch directory.
- **The module interface.** The kernel module gains `tests()` and
  `run_tests(request)`, with `KernelTestCase`, `KernelTestRequest` and
  `KernelTestOutcome` records in `compiler/kernel_api.jac`. The host reaches
  them through `project/kernel_call.jac`, and
  `tests/compiler/test_kernel_suites.jac` turns each case into one host test.
- **Writing a case.** A kit module gives cases `analyse(text, name, options)`,
  `analyse_file(path, options)`, `checkout_path(rel)` and
  `parse_text(text, name)`. A case must lower natively: no `getattr` on
  strings, `importlib`, `unittest.mock`, `subprocess`, or files outside its
  scratch directory and checkout fixtures. A test that needs those is a host
  compile-and-check test.
- **Dev kernels only.** Release kernels leave the suites out. Release and
  development kernels are both built by `jac native build kernel`
  (`build-kernel.yml` serves CI and releases alike), so the split needs a build
  profile: a development root module that adds `tests` and `run_tests` to the
  method table and pulls in the suites, chosen through `KernelTarget`
  (`root_module`, `scope_modules`), and a release flag that
  `build-kernel.yml` passes for release builds. The kernel record already
  names its own units, so staleness checks follow whichever profile built it.

## The mechanical rules

### Internals to a kernel suite

1. Pick the suite named in the table below and create
   `compiler/kernel_tests/<topic>.jac` if it does not exist yet: add it to the
   development roster and to `kernel_suites`, and wire its imports in
   `archwire.jac`.
2. `test "<name>" { body }` becomes `def <snake_name> { body }`, listed as
   `KernelCase("<name>", <snake_name>)` in `<topic>_cases()`. Helper `def`s,
   `walker`s and `glob`s move across unchanged.
3. `JacProgram().compile(use_str=src, file_path=name, options=o)` becomes
   `analyse(src, name, o)`; `prog.errors_had` codes become
   `analysis.error_codes()`; a fixture file becomes
   `analyse_file(checkout_path("tests/<rel>"))`.
4. Delete the host test once its cases are ported, and take its file out of
   `[test] bytecode_compiler` when nothing internal is left in it.

### Compile-and-check onto the kernel entry

1. A helper that compiles `use_str` with `no_cgen` and returns
   `[str(e) for e in prog.errors_had]` becomes
   `[f"{d.code}: {d.message}" for d in kernel_check_source(src, name, opts).errors]`.
   The check entry sets `no_cgen` itself.
2. `prog.compile(path)` followed by code lists becomes
   `error_codes(kernel_check_file(path))` when the test only checks, and
   `error_codes(kernel_compile_file(path, CompileOptions(aot_mode=True, ...)))`
   when the diagnostic comes from codegen or native lowering.
3. `e.loc.first_line` becomes `diag.span.line`, `str(e)` becomes
   `diag.message`, and the code is `diag.code`.
4. Generated Python is read from `unit_code(result.unit(path))` (`co_names`,
   `co_consts`) or the `python_source` product; client output from
   `unit.client_js`; the interop manifest is `json.loads(unit.interop)`.
5. Formatter, linter and language-server tests open `tool_session(root)` and
   call its queries.

## Left: sorted by target

These are the files that still build a host `JacProgram`, call `rd_parse` / `run_walker`, or read `gen.*` / `hub` / `type_evaluator` off a compiled module. There are 229 files with 3,208 tests, but most files are mixed: their diagnostic-only tests move to the compile entry and their tree-reading tests move to the suite. In the "Today" column:

- "reads the tree / pass outputs": at least one test is internals.
- "diagnostics only": the whole file is compile-and-check.
- "host compile, no tree reads": the compile already goes through the kernel entry and only needs the helper switch.

### Checker and diagnostics (suite `checker`)

Rule: compile + diagnostics: `kernel_compile_file`; MTIR facts: `CompiledUnit.sections` (SEC_MTIR) or kernel suite

| File | Tests | Today | Target |
|---|---|---|---|
| `jac/jaclang/byllm/tests/test_byllm.jac` | 56 | diagnostics only | compile-and-check |
| `jac/jaclang/byllm/tests/test_mtir_integration.jac` | 30 | diagnostics only | compile-and-check |
| `jac/jaclang/compiler/tests/test_batch_decl_identity.jac` | 3 | diagnostics only | compile-and-check |
| `jac/jaclang/compiler/tests/test_global_narrowing.jac` | 4 | diagnostics only | compile-and-check |
| `jac/jaclang/compiler/tests/test_subscript_assignment.jac` | 7 | diagnostics only | compile-and-check |
| `jac/jaclang/compiler/tests/test_unknown_cascade.jac` | 9 | diagnostics only | compile-and-check |
| `jac/jaclang/compiler/tests/test_untyped_third_party.jac` | 4 | diagnostics only | compile-and-check |
| `jac/tests/compiler/passes/test_access_control.jac` | 8 | diagnostics only | compile-and-check |
| `jac/tests/compiler/passes/test_checker_browser_hostapis.jac` | 2 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/passes/test_checker_bugs.jac` | 92 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/passes/test_checker_fixed_width.jac` | 35 | diagnostics only | compile-and-check |
| `jac/tests/compiler/passes/test_checker_gaps.jac` | 29 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/passes/test_checker_js_globals.jac` | 3 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/passes/test_checker_pass.jac` | 155 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/passes/test_checker_production.jac` | 10 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/passes/test_checker_shortcomings.jac` | 11 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/passes/test_fw_range_elision.jac` | 9 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/passes/test_kwarg_key_slot.jac` | 7 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/passes/test_mtir_gen_pass.jac` | 8 | diagnostics only | compile-and-check |
| `jac/tests/compiler/passes/test_new_diagnostics.jac` | 110 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/passes/test_portability_check_pass.jac` | 27 | diagnostics only | compile-and-check |
| `jac/tests/compiler/passes/test_static_analysis_pass.jac` | 25 | diagnostics only | compile-and-check |
| `jac/tests/compiler/passes/test_typevar.jac` | 22 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_annotation_arguments.jac` | 3 | diagnostics only | compile-and-check |
| `jac/tests/compiler/test_builtin_extensions.jac` | 3 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_comptime_cache_keys.jac` | 15 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_comptime_determinism.jac` | 1 | host compile, no tree reads | compile-and-check |
| `jac/tests/compiler/test_comptime_operators.jac` | 2 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_comptime_type_parameters.jac` | 3 | diagnostics only | compile-and-check |
| `jac/tests/compiler/test_comptime_values.jac` | 9 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_distinct_types.jac` | 13 | diagnostics only | compile-and-check |
| `jac/tests/compiler/test_edge_endpoint_contract.jac` | 6 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_generic_base_identity.jac` | 4 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_graph_construction.jac` | 16 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_graph_query_sublanguage.jac` | 9 | diagnostics only | compile-and-check |
| `jac/tests/compiler/test_isinstance_tuple_glob.jac` | 3 | diagnostics only | compile-and-check |
| `jac/tests/compiler/test_literal_decoding.jac` | 8 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_metaclass_and_gated_overloads.jac` | 5 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_new_builtin.jac` | 13 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_object_fields.jac` | 13 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_quoted_type_expressions.jac` | 7 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_reserved_words.jac` | 4 | diagnostics only | compile-and-check |
| `jac/tests/compiler/test_self_referential_base.jac` | 3 | diagnostics only | compile-and-check |
| `jac/tests/compiler/test_stub_lens_stability.jac` | 4 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_type_memos.jac` | 4 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_typecheck_critical_path.jac` | 6 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_typed_interop.jac` | 37 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_unpack_any_element.jac` | 5 | diagnostics only | compile-and-check |
| `jac/tests/compiler/test_variant_agreement.jac` | 5 | diagnostics only | compile-and-check |

### Symbol tables and impl matching (suite `symtab`)

Rule: symbol tables / impl matching on the tree: kernel suite (`kit.analyse` + walk); E-code tests: `kernel_check_source`

| File | Tests | Today | Target |
|---|---|---|---|
| `jac/tests/compiler/passes/test_ambient_identity_audit.jac` | 21 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/passes/test_decl_impl_match_pass.jac` | 20 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/passes/test_import_pass.jac` | 7 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/passes/test_sem_def_match_pass.jac` | 3 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/passes/test_sym_tab_build_pass.jac` | 14 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/test_decl_impl_one_element.jac` | 11 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/test_jsx_child_truthiness.jac` | 1 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/test_jsx_single_node.jac` | 2 | reads the tree / pass outputs | internals |

### Parser, positions and source maps (suite `parser`)

Rule: parse trees and positions: kernel suite (`kit.parse_text` / `kit.analyse_file(kit.checkout_path(...))`); generated Python: the `python_source` product

| File | Tests | Today | Target |
|---|---|---|---|
| `jac/tests/compiler/test_micro_suite.jac` | 0 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/test_parser.jac` | 41 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/test_rd_parser_validation.jac` | 0 | reads the tree / pass outputs | internals |
| `jac/tests/language/test_py_infra.jac` | 33 | reads the tree / pass outputs | internals |
| `jac/tests/runtimelib/test_source_mapping.jac` | 26 | reads the tree / pass outputs | internals |

### Ownership, nogc and layout passes (suite `ownership_layout`)

Rule: diagnostics: `kernel_compile_file(..., CompileOptions(aot_mode=True, memory_profile=...))` + codes; pass facts (rc facts, layouts): kernel suite

| File | Tests | Today | Target |
|---|---|---|---|
| `jac/tests/compiler/passes/test_layout_acyclic_field_type.jac` | 4 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/passes/test_layout_native_names.jac` | 3 | host compile, no tree reads | compile-and-check |
| `jac/tests/compiler/passes/test_layout_pass.jac` | 16 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/passes/test_nogc_container_fence.jac` | 24 | diagnostics only | compile-and-check |
| `jac/tests/compiler/passes/test_nogc_enforce_infer.jac` | 7 | diagnostics only | compile-and-check |
| `jac/tests/compiler/passes/test_nogc_local_inference.jac` | 5 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/passes/test_nogc_nested_containers.jac` | 2 | diagnostics only | compile-and-check |
| `jac/tests/compiler/passes/test_nogc_own_containers.jac` | 3 | diagnostics only | compile-and-check |
| `jac/tests/compiler/passes/test_nogc_own_fields.jac` | 3 | diagnostics only | compile-and-check |
| `jac/tests/compiler/passes/test_ownership_regressions.jac` | 3 | diagnostics only | compile-and-check |
| `jac/tests/compiler/passes/test_rc_facts_pass.jac` | 6 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/passes/test_wasm_contract.jac` | 7 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_alert_delivery.jac` | 6 | reads the tree / pass outputs | compile-and-check + internals cases |

### Placement and codespace (suite `placement`)

Rule: verdicts: `kernel_check_file(placements=True).placements` rows and `native_coverage_rows`; placement evidence / legality internals: kernel suite

| File | Tests | Today | Target |
|---|---|---|---|
| `jac/tests/compiler/test_boundary_audit.jac` | 1 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_boundary_rules.jac` | 12 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_boundary_scopes.jac` | 2 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_by_llm_placement.jac` | 4 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_client_placement_cache.jac` | 3 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_codespace_inference.jac` | 58 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_cross_app_import.jac` | 16 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_front_end_native_idioms.jac` | 23 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_kind_codespace.jac` | 9 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_na_edge_decided_placement.jac` | 3 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_na_import_edge.jac` | 9 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_native_legality.jac` | 22 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_placement_evidence.jac` | 8 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_placement_facts.jac` | 10 | host compile, no tree reads | compile-and-check |
| `jac/tests/compiler/test_placement_npm_python_collision.jac` | 5 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_placement_pins.jac` | 4 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_placement_work.jac` | 8 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_test_origin_placement.jac` | 10 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_warm_cache_codespace.jac` | 12 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/packages/test_boundary.jac` | 2 | diagnostics only | compile-and-check |

### Import resolution and wiring (suite `imports`)

Rule: resolution outcomes: `kernel_check_file` diagnostics and `CompileResult.reached`; resolver internals: kernel suite

| File | Tests | Today | Target |
|---|---|---|---|
| `jac/jaclang/compiler/tests/test_client_npm_entry_root.jac` | 3 | diagnostics only | compile-and-check |
| `jac/tests/compiler/test_import_universe_resolution.jac` | 10 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_import_wiring.jac` | 61 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_importer.jac` | 26 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_package_module_binding.jac` | 7 | diagnostics only | compile-and-check |
| `jac/tests/compiler/test_schedule_validation.jac` | 11 | diagnostics only | compile-and-check |
| `jac/tests/compiler/test_self_tree_resolution.jac` | 5 | diagnostics only | compile-and-check |
| `jac/tests/compiler/test_type_only_imports.jac` | 18 | reads the tree / pass outputs | compile-and-check + internals cases |
| `jac/tests/compiler/test_workspace_compile_scope.jac` | 1 | diagnostics only | compile-and-check |
| `jac/tests/compiler/test_workspace_facts.jac` | 9 | diagnostics only | compile-and-check |
| `jac/tests/runtimelib/test_find_module.jac` | 3 | reads the tree / pass outputs | compile-and-check + internals cases |

### Bytecode and client codegen (suite `codegen`)

Rule: generated code: `unit_code(unit)` (`co_names`/`co_consts`) or `client_js`; manifests: `CompiledUnit.interop` / `client_manifest`; codegen AST internals: kernel suite

| File | Tests | Today | Target |
|---|---|---|---|
| `jac/jaclang/compiler/tests/test_client_codegen_facts.jac` | 5 | reads the tree / pass outputs | compile products + internals cases |
| `jac/jaclang/compiler/tests/test_pipeline_products.jac` | 3 | reads the tree / pass outputs | compile products + internals cases |
| `jac/jaclang/compiler/tests/test_test_block_analysis.jac` | 4 | reads the tree / pass outputs | compile products + internals cases |
| `jac/tests/compiler/test_client_codegen.jac` | 15 | reads the tree / pass outputs | compile products + internals cases |
| `jac/tests/compiler/test_client_value_refs.jac` | 8 | reads the tree / pass outputs | compile products + internals cases |
| `jac/tests/compiler/test_compilation.jac` | 9 | diagnostics only | compile products |
| `jac/tests/compiler/test_interop_manifest.jac` | 9 | reads the tree / pass outputs | compile products + internals cases |
| `jac/tests/compiler/test_pyast_gen_pass.jac` | 27 | reads the tree / pass outputs | compile products + internals cases |
| `jac/tests/runtimelib/test_client_runtime_parity.jac` | 6 | reads the tree / pass outputs | compile products + internals cases |
| `jac/tests/runtimelib/test_closures.jac` | 1 | reads the tree / pass outputs | compile products + internals cases |

### ECMAScript backend (suite `es_codegen`)

Rule: JS text: `kernel_compile_file(p).unit(p).client_js`; EsastGenPass / `es_ast` inspection: kernel suite

| File | Tests | Today | Target |
|---|---|---|---|
| `jac/tests/compiler/backends/es/test_acceptance_matrix.jac` | 13 | diagnostics only | compile entry (verify no tree reads) |
| `jac/tests/compiler/backends/es/test_accessors.jac` | 2 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/es/test_arena_host.jac` | 1 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/es/test_esast_gen_pass.jac` | 44 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/es/test_identifier_slot_lowering.jac` | 4 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/es/test_js_coercions.jac` | 4 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/es/test_js_generation.jac` | 122 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/es/test_jsx_except_awaiting_spec.jac` | 2 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/es/test_jsx_forward_ref_spec.jac` | 2 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/es/test_jsx_ref_spec.jac` | 3 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/es/test_loop_else.jac` | 12 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/es/test_operator_call_lowering.jac` | 5 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/es/test_optional_chaining.jac` | 8 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/es/test_preact_backend.jac` | 16 | diagnostics only | compile entry (verify no tree reads) |
| `jac/tests/compiler/backends/es/test_slot_child_positions.jac` | 5 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/es/test_slot_extensions.jac` | 8 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/es/test_solid_backend.jac` | 30 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/es/test_state_store_lowering.jac` | 6 | diagnostics only | compile entry (verify no tree reads) |

### Native backend leftovers (suite `native_layout`)

Rule: the listed tests read layouts, tree facts or placement scans: kernel suite; the rest of the file is already kernel-backed

| File | Tests | Today | Target |
|---|---|---|---|
| `jac/tests/compiler/backends/native/test_anon_region_infer.jac` | 5 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_inherited_slot_headers.jac` | 7 | diagnostics only | compile entry (verify no tree reads) |
| `jac/tests/compiler/backends/native/test_native_abc_erasure.jac` | 6 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_clib_abi.jac` | 9 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_closed_world.jac` | 6 | diagnostics only | compile entry (verify no tree reads) |
| `jac/tests/compiler/backends/native/test_native_container_temporaries.jac` | 2 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_enum_ctor.jac` | 9 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_erased_any.jac` | 4 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_error_gate.jac` | 5 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_from_import_capability.jac` | 16 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_func_body_import.jac` | 4 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_gate.jac` | 5 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_gen_pass.jac` | 227 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_hetero_matrix.jac` | 14 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_iface.jac` | 11 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_interface_class_names.jac` | 1 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_interop_callbacks.jac` | 5 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_intrinsic_registry.jac` | 11 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_lowering_verdict.jac` | 6 | host compile, no tree reads | compile entry (verify no tree reads) |
| `jac/tests/compiler/backends/native/test_native_optional_temporaries.jac` | 2 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_rc_ownership.jac` | 24 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_reloaded_base_layout.jac` | 3 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_seam_order.jac` | 5 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_string_lifetime.jac` | 1 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_type_position_erasure.jac` | 14 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_xmod_inherited_fields.jac` | 7 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_pyast_native_import_fact.jac` | 14 | reads the tree / pass outputs | internals |

### Native link plan and registry (suite `native_link`)

Rule: link-plan / registry assertions: kernel suite (link runs in the kernel, step 10); artifacts: `native_build` CLI

| File | Tests | Today | Target |
|---|---|---|---|
| `jac/tests/compiler/backends/native/test_link_plan.jac` | 47 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_glue_symbols_cache.jac` | 3 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_publication.jac` | 7 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_object_emit_pool.jac` | 3 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_region_partition.jac` | 3 | host compile, no tree reads | compile entry (verify no tree reads) |
| `jac/tests/compiler/backends/native/test_session_heap.jac` | 5 | host compile, no tree reads | compile entry (verify no tree reads) |
| `jac/tests/compiler/backends/native/test_shared_lib.jac` | 26 | host compile, no tree reads | compile entry (verify no tree reads) |
| `jac/tests/compiler/backends/native/test_wasm_build.jac` | 16 | host compile, no tree reads | compile entry (verify no tree reads) |

### Caches, interfaces and retention (suite `driver_caches`)

Rule: cache contents and retention live in the kernel now: kernel suite; staleness seen from the host: `CompileResult.reads` / `reached`

| File | Tests | Today | Target |
|---|---|---|---|
| `jac/jaclang/compiler/tests/test_jac_mobui_typing.jac` | 4 | reads the tree / pass outputs | internals |
| `jac/jaclang/compiler/tests/test_missing_local_import.jac` | 15 | reads the tree / pass outputs | internals |
| `jac/jaclang/compiler/tests/test_module_exports.jac` | 5 | reads the tree / pass outputs | internals |
| `jac/jaclang/compiler/tests/test_stubcat_roundtrip.jac` | 6 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/test_cache_verdict_determinism.jac` | 3 | diagnostics only | compile entry (verify no tree reads) |
| `jac/tests/compiler/test_client_artifact_cache.jac` | 6 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/test_compile_artifact_retention.jac` | 7 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/test_compile_lifetime.jac` | 3 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/test_failed_module_reparse.jac` | 6 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/test_iface_cache.jac` | 37 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/test_module_release.jac` | 12 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/test_precompiled_interfaces.jac` | 9 | reads the tree / pass outputs | internals |

### Formatter (session `format`)

Rule: formatted text: session `format(path)`; unparse/AST round trips: kernel suite

| File | Tests | Today | Target |
|---|---|---|---|
| `jac/tests/compiler/tools/test_jac_format_pass.jac` | 43 | diagnostics only | session |
| `jac/tests/compiler/tools/test_unparse_validate.jac` | 9 | reads the tree / pass outputs | session + internals cases |

### Linter (session `lint_fix` / `diagnostics`)

Rule: fixed text: session `lint_fix(path)`; lint diagnostics: session `diagnostics(path)`

| File | Tests | Today | Target |
|---|---|---|---|
| `jac/tests/compiler/tools/test_jac_auto_lint_pass.jac` | 83 | diagnostics only | session |
| `jac/tests/compiler/tools/test_jac_lint_report.jac` | 2 | reads the tree / pass outputs | session + internals cases |

### Grammar extraction (suite `grammar`)

Rule: grammar extraction walks the parser tree: kernel suite

| File | Tests | Today | Target |
|---|---|---|---|
| `jac/tests/compiler/tools/test_grammar_extract_pass.jac` | 42 | reads the tree / pass outputs | internals |

### Language server (session queries)

Rule: every LSP feature is a session query (`open_kernel_session`: update/diagnostics/hover/definition/references/completion/semantic_tokens/inlay_hints/symbols/rename/format)

| File | Tests | Today | Target |
|---|---|---|---|
| `jac/tests/langserve/test_server.jac` | 35 | diagnostics only | session |

### Host adoption of kernel results (host, compile entry)

Rule: host adoption of kernel results: stays on the host through `kernel_compile` / `call_compile` (already partly rewritten); remaining tree reads: kernel suite

| File | Tests | Today | Target |
|---|---|---|---|
| `jac/tests/compiler/test_application_preparation.jac` | 38 | reads the tree / pass outputs | host, compile entry + internals cases |
| `jac/tests/compiler/test_compile_options.jac` | 22 | reads the tree / pass outputs | host, compile entry + internals cases |
| `jac/tests/compiler/test_compiler_module_carry.jac` | 18 | reads the tree / pass outputs | host, compile entry + internals cases |
| `jac/tests/compiler/test_native_analyze.jac` | 4 | diagnostics only | host, compile entry |
| `jac/tests/compiler/test_native_compile.jac` | 22 | reads the tree / pass outputs | host, compile entry + internals cases |
| `jac/tests/compiler/test_native_in_kernel.jac` | 7 | diagnostics only | host, compile entry |

### Host tool paths (compile entry products)

Rule: host tool paths (bundling, publishing, CLI): compile through `kernel_compile_file` and read unit products; CLI subprocess tests need no change

| File | Tests | Today | Target |
|---|---|---|---|
| `jac/tests/cli/test_shadcn_registry.jac` | 6 | reads the tree / pass outputs | host, compile entry + internals cases |
| `jac/tests/client/test_client_build_warm_start.jac` | 2 | reads the tree / pass outputs | host, compile entry + internals cases |
| `jac/tests/client/test_external_module_paths.jac` | 3 | reads the tree / pass outputs | host, compile entry + internals cases |
| `jac/tests/client/test_mobile_target.jac` | 65 | reads the tree / pass outputs | host, compile entry + internals cases |
| `jac/tests/dist/test_build_jab.jac` | 8 | reads the tree / pass outputs | host, compile entry + internals cases |
| `jac/tests/dist/test_native_product_export.jac` | 5 | diagnostics only | host, compile entry |
| `jac/tests/language/test_cli.jac` | 98 | diagnostics only | host, compile entry |
| `jac/tests/publish/test_npm_publish.jac` | 22 | host compile, no tree reads | host, compile entry |
| `jac/tests/publish/test_runtime_vendor.jac` | 3 | reads the tree / pass outputs | host, compile entry + internals cases |
| `jac/tests/runtimelib/test_client_bundle.jac` | 14 | diagnostics only | host, compile entry |
| `jac/tests/runtimelib/test_client_bundle_preparation.jac` | 3 | host compile, no tree reads | host, compile entry |
| `jac/tests/runtimelib/test_solid_effect_cleanup.jac` | 1 | diagnostics only | host, compile entry |
| `jac/tests/runtimelib/test_solid_jsdom.jac` | 5 | diagnostics only | host, compile entry |
| `jac/tests/runtimelib/test_sv_walker_hydration.jac` | 5 | host compile, no tree reads | host, compile entry |
| `jac/tests/toolchains/test_c_backend.jac` | 5 | diagnostics only | host, compile entry |

### Other compile-entry tests

Rule: compile-and-check: kernel entry; tree reads: kernel suite

| File | Tests | Today | Target |
|---|---|---|---|
| `jac/jaclang/compiler/tests/test_graph_fragment_equivalence.jac` | 4 | diagnostics only | compile-and-check |
| `jac/jaclang/compiler/tests/test_native_kernel_cache.jac` | 1 | host compile, no tree reads | compile-and-check |
| `jac/tests/compiler/test_analysis_ledger.jac` | 5 | host compile, no tree reads | compile-and-check |
| `jac/tests/compiler/test_application_contexts.jac` | 3 | host compile, no tree reads | compile-and-check |
| `jac/tests/compiler/test_compile_progress.jac` | 4 | host compile, no tree reads | compile-and-check |
| `jac/tests/compiler/test_ct_definition_deps.jac` | 10 | host compile, no tree reads | compile-and-check |
| `jac/tests/compiler/test_interface_memory.jac` | 2 | host compile, no tree reads | compile-and-check |
| `jac/tests/compiler/test_kernel_resolve.jac` | 21 | host compile, no tree reads | compile-and-check |
| `jac/tests/compiler/test_native_build_key_memo.jac` | 2 | host compile, no tree reads | compile-and-check |
| `jac/tests/compiler/test_native_library_conformance.jac` | 3 | host compile, no tree reads | compile-and-check |
| `jac/tests/compiler/test_persistent_identity.jac` | 10 | host compile, no tree reads | compile-and-check |
| `jac/tests/compiler/test_stub_use_retention.jac` | 3 | host compile, no tree reads | compile-and-check |
| `jac/tests/compiler/test_super_mro.jac` | 4 | host compile, no tree reads | compile-and-check |
| `jac/tests/compiler/test_unit_products.jac` | 6 | host compile, no tree reads | compile-and-check |
| `jac/tests/compiler/test_walker_execution.jac` | 1 | host compile, no tree reads | compile-and-check |

### Bytecode-hosted compiler (delete with step 17)

Rule: covers selfhost / jac0 / the bootstrap cache: deleted with step 17

| File | Tests | Today | Target |
|---|---|---|---|
| `jac/tests/compiler/test_selfhost_cache.jac` | 5 | selfhost | delete (step 17) |
| `jac/tests/compiler/test_selfhost_routing.jac` | 6 | selfhost | delete (step 17) |

### Drafted as kernel suites (suites `type_position`, `scopes`, `context_bindings`)

Rule: the draft (#10489) already wrote these as kernel cases; they land with the in-kernel harness

| File | Tests | Today | Target |
|---|---|---|---|
| `jac/tests/compiler/test_type_position.jac` | 13 | reads the tree / pass outputs | suite `type_position` |
| `jac/tests/compiler/test_scope_walk.jac` | 2 | reads the tree / pass outputs | suite `scopes` |
| `jac/tests/compiler/passes/test_sub_node_pass.jac` | 1 | reads the tree / pass outputs | suite `scopes` |
| `jac/tests/compiler/test_context_bindings.jac` | 2 | reads the tree / pass outputs | suite `context_bindings` |

