# Compiler tests on the kernel (#10471 step 15)

The kernel is the only compiler, and compiler modules are native-only, so no
test can build a host `JacProgram` and read its tree any more. On the host,
`JacProgram().compile(...)` goes through the kernel and returns a stub module
(`gen.py_bytecode`, `gen.js`, `loc.mod_path`); its diagnostics land in
`errors_had` / `warnings_had`. Every test takes one of two forms:

- **Compile-and-check tests** compile or check through the kernel and assert on
  what comes back: `KernelDiagnostic` records, `CompiledUnit` products (code
  object, `client_js`, `native_ir`, `native_mir`, `demoted`, `native_iface`,
  `interop`, `sections`), coverage and placement rows, or session answers.
- **Internals tests** inspect compiler data structures (the unitree, symbol
  tables, types, pass outputs, layouts, MIR objects). They are kernel test
  cases: they are compiled into the kernel and run there, natively, against
  the compiler's own objects.

This file is the sorted remainder: every test file that still drives the host
compiler, the form it moves to, and the rule that moves it.

## The helpers

All of them are in `jac/tests/support.jac`.

| Need | Helper |
|---|---|
| Diagnostics for a file or a source string | `kernel_check_file(path, options, native_coverage, placements, closure, sources)`, `kernel_check_source(source, name, options)`, `error_codes`, `warning_codes`, `diagnostics_text`, `has_error_code`, `has_warning_code` |
| Products of a compile | `kernel_compile_file(path, options, products, sources)`, `kernel_compile_source(...)`, then `result.unit(path)`. Product names: `"bytecode"`, `"mir"`; empty means analysis only |
| JIT a native fixture | `compile_native(fixture, fixture_dir, options, sources) -> (engine, KernelFixture)`, plus `get_func`, `native_str_func`, `native_address` |
| What the decision step did | `compile_mir(fixture)` / `compile_native_ir(fixture)`, then `fx.mir()`, `fx.demoted()`, `fx.is_demoted(name)`, `fx.reason(name)`, `fx.llvm_ir()`, `fx.iface()`, `fx.symbol(name)` |
| A required-native refusal | `compile_native_refused(fixture)`, then `"E5092" in error_codes(result)` |
| `jac check --native-coverage` | `native_coverage_rows(path)` |
| Placement verdicts | `kernel_check_file(path, placements=True).placements` |
| Tooling features | `project.kernel_call.open_kernel_session(root)`, then `update`, `diagnostics`, `hover`, `definition`, `references`, `completion`, `semantic_tokens`, `inlay_hints`, `symbols`, `rename`, `format`, `lint_fix`, `compile`, `check` |
| Run kernel test cases | `kernel_cases()`, `run_kernel_case(case)` (used by `tests/compiler/test_kernel_suites.jac`) |

## Kernel test cases

- **Where they live.** A suite is a module in `jac/jaclang/compiler/kernel_tests/`. Its cases are plain functions that raise on failure, listed in a `<topic>_cases() -> list[KernelCase]` function.
- **How the kernel finds them.** `compiler/kernel_testing.jac` lists every suite (`kernel_suites`); `find_suite` looks one up by name, and `run_case` runs one case. Each case gets its own scratch directory, and the host is left neutral afterwards.
- **The module interface.** The kernel module exports `tests()` and `run_tests(request)`. Their records (`KernelTestCase`, `KernelTestRequest`, `KernelTestOutcome`) and functions (`kernel_test_cases`, `run_kernel_tests`) are declared in `compiler/kernel_api.jac`.
- **How they run.** The host calls the kernel through `project.kernel_call.kernel_tests` / `call_kernel_tests`. `tests/compiler/test_kernel_suites.jac` turns each case into one host test, named `kernel [<suite>: <case>]`, so `jac test` runs them all. A failure carries the message the case raised inside the kernel.
- **Writing a case.** Use the helpers in `compiler/kernel_tests/kit.jac`:
  - `analyse(text, name, options) -> Analysis`, which has `program`, `module`, `path`, `error_codes()`, `warning_codes()` and `messages()`;
  - `analyse_file(path, options)` and `checkout_path("tests/...")` for checkout fixtures;
  - `parse_text(text, name)`;
  - `lower_text(text, name) -> Lowered`, which has `lowering`, `mir`, `symbol_of(name)`, `demoted(name)` and `reason(name)`.
- **What is ported so far.** Four suites:
  - `type_position` (13 cases), from `tests/compiler/test_type_position.jac`;
  - `scopes` (3), from `test_scope_walk.jac` and `passes/test_sub_node_pass.jac`;
  - `context_bindings` (2), from `test_context_bindings.jac`;
  - `mir_decisions` (3, new): the decision step's native, refused and propagated verdicts.
- **Editing a suite** makes the development kernel stale, so run `jac native build kernel` first, as for any compiler source. A case's imports between jaclang modules are wires in `archwire.jac`, and every suite module has an entry in `compiler/native_scope.jac`.

## The mechanical rules

### Internals to a kernel suite

1. **Pick the suite.** Use the topic named in the table below. Create `compiler/kernel_tests/<topic>.jac` if it does not exist yet. Then:
   - add a `NativeScopeEntry` for it in `compiler/native_scope.jac`;
   - add `KernelSuite(name="<topic>", cases=<topic>_cases())` to `kernel_suites` in `compiler/impl/kernel_testing.impl.jac`;
   - wire `kernel_tests.<topic> ++> kernel_testing { <topic>_cases }` and `kernel_testing ++> kernel_tests.<topic> { KernelCase }`.
2. **Convert each test.** `test "<name>" { body }` becomes `def <snake_name> { body }`, with `KernelCase("<name>", <snake_name>)` listed in `<topic>_cases()`. Helper `def`s, `walker`s and `glob`s move across unchanged.
3. **Replace the host-only calls.**
   - `JacProgram().compile(use_str=src, file_path=name, options=o)` becomes `analyse(src, name, o)`; the case reads `.module` and `.program`.
   - `rd_parse(src, path, prog=...)` / `parse(...)` becomes `parse_text(src, name)`.
   - A fixture file becomes `analyse_file(checkout_path("tests/<rel>"))`.
   - `prog.errors_had` codes become `analysis.error_codes()`.
4. **Replace the imports.** `import from jaclang.<x> { names }` lines become wires `<x relative to compiler> ++> kernel_tests.<topic> { names }`. A suite has no `import from jaclang` lines.
5. **Keep it lowerable.** A case must be native: no `getattr` on strings, `importlib`, `patch`/`unittest.mock`, `subprocess` or host files outside the scratch directory and checkout fixtures. A test that needs those is a host compile-and-check test, not an internals test.
6. **Delete the host test once its cases are ported.** If the host file keeps other tests, delete only the ported ones.

### Compile-and-check onto the kernel entry

1. A `check_src` / `check_receiver` helper that builds a `JacProgram`, compiles `use_str` with `no_cgen` and returns `[str(e) for e in prog.errors_had]` becomes `[f"{d.code}: {d.message}" for d in kernel_check_source(src, name, opts).errors]`. Drop `no_cgen` from `opts`; the check entry sets it. The script at the end of this file applies the rule; it has already converted 11 files.
2. `prog.compile(path)` followed by `errors_had`/`warnings_had` code lists becomes:
   - `error_codes(kernel_check_file(path))` when the test only checks;
   - `error_codes` / `warning_codes(kernel_compile_file(path, CompileOptions(aot_mode=True, ...)))` when the diagnostic comes from codegen or native lowering (W5032, E13xx, W1312, E1401, E5092).
3. Locations: `e.loc.first_line` becomes `diag.span.line`. Messages: `e.pretty_print()` / `str(e)` becomes `diag.message`, and the code is `diag.code`.
4. Generated Python is read from the unit's code object (`result.unit(path).code`: `co_names`, `co_consts`, `co_name`), not from a `py_ast`. Client output is read from `result.unit(path).client_js`. The interop manifest is `json.loads(unit.interop)` and the client manifest is `unit.client_manifest`.
5. Formatter, linter and language-server tests open a session and call `format`, `lint_fix`, `diagnostics` and the position queries.
6. Placement and codespace verdicts come from `kernel_check_file(path, placements=True).placements` (`PlacementRow(symbol, placement, reason)`) and `native_coverage_rows(path)`.

### Native tests (the MIR backend's oracle)

These are already converted (see "Done").

- **Behavior tests** JIT through `compile_native`.
- **LLVM-text tests** now assert behavior, or the MIR decision (`compile_mir`: `fx.mir()`, `fx.demoted()`). An emitted-LLVM fact is kept only when MIR emission must preserve it: ABI, symbol names, linkage, attributes, or retain/release counts, which MIR text cannot show because it is rendered before RC insertion.
- **Must-demote tests** read `fx.demoted()` and `fx.reason()`, or `compile_native_refused` + E5092.
- **Must-not-demote tests** are kept.

## Done in this step

- **Deleted, because they covered only removed code.** 13 files:
  - Callback channel, census and KernelInputs JSON: `test_kernel_host`.
  - Parse-only route (`jc_run`, `jc_materialize`): `test_native_kernel`.
  - NaIRGenPass internals: `test_native_extern_declarations`, `test_native_layout_param_names`, `test_native_type_cache`, `test_native_unwind_shadow_slots`.
  - Emitted helpers that are gone: `test_native_alloc_fast_path`, `test_native_exception_context`.
  - The rc debug-trace codegen: `test_native_options_object`.
  - Ported to kernel suites: `test_type_position`, `test_scope_walk`, `passes/test_sub_node_pass`, `test_context_bindings`.
- **Obsolete tests removed inside kept files.** Removing them is most of the drop from 9,956 to 9,818 host test blocks; 2,280 to 2,197 of those are native tests. The rest are ported, not lost: the 21 kernel cases replace the 18 host tests they came from, plus 3 new ones. What went:
  - in-process parity, CompileReport/KernelInputs JSON, fork crash isolation, `host_deferred`, `host_preparing`, ask-host-once;
  - native parse versus store parser, `require_stub_catalog`;
  - NaIRGenPass source guards and sanctions, seam warnings;
  - lowering metadata (`NativeLoweringIssue`), demotion stubs, `__jac_demoted`;
  - old helper and label shapes, NaIRGenPass monkeypatches.
- **Native backend tests.** 225 files rewritten (`tests/compiler/backends/native/`):
  - about 25 IR-text tests rewritten to behavior;
  - about 60 to MIR;
  - about 70 must-demote tests to the MIR demoted set or E5092;
  - about 120 must-not-demote checks kept, or rewritten from coverage APIs;
  - every other test changed only through the helpers, `compile_native` returning a `KernelFixture`.
- **Kernel plumbing tests.** 30 files rewritten onto `kernel_compile_file`, `kernel_check_file`, `load_kernel`, the `jac_kernel.so` layout and E1408 for another compiler's tree. Among them are `test_native_compile`, `test_native_analyze`, `test_native_in_kernel`, `test_kernel_resolve` and `test_application_preparation`.
- **Compile-and-check tests.** 19 files moved to the kernel check and compile entries.
- **Equivalence lanes.** `jaclang/compiler/tests/xbackend_equiv.jac` (`compile_native`, `jit_through_kernel`, `compile_native_errors`) compiles and JITs through the kernel, and the equivalence lanes follow it.

## Left: sorted by target

These are the files that still build a host `JacProgram`, call `rd_parse` / `run_walker`, or read `gen.*` / `hub` / `type_evaluator` off a compiled module. There are 225 files with 3,186 tests, but most files are mixed: their diagnostic-only tests move to the compile entry and their tree-reading tests move to the suite. In the "Today" column:

- "reads the tree / pass outputs": at least one test is internals.
- "diagnostics only": the whole file is compile-and-check.
- "host compile, no tree reads": the host compile goes through the kernel already and only needs the helper switch.

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

Rule: parse trees and positions: kernel suite (`kit.parse_text` / `kit.analyse_file(kit.checkout_path(...))`); generated Python: `python_ast` product

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
| `jac/tests/compiler/test_native_legality.jac` | 21 | reads the tree / pass outputs | compile-and-check + internals cases |
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

Rule: generated code: `CompiledUnit.code` (`co_names`/`co_consts`) or `client_js`; manifests: `CompiledUnit.interop` / `client_manifest`; codegen AST internals: kernel suite

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
| `jac/tests/compiler/backends/native/test_inherited_slot_headers.jac` | 9 | diagnostics only | compile entry (verify no tree reads) |
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
| `jac/tests/compiler/backends/native/test_native_gen_pass.jac` | 225 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_hetero_matrix.jac` | 14 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_iface.jac` | 11 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_interface_class_names.jac` | 1 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_interop_callbacks.jac` | 5 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_intrinsic_registry.jac` | 11 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_lowering_verdict.jac` | 3 | host compile, no tree reads | compile entry (verify no tree reads) |
| `jac/tests/compiler/backends/native/test_native_optional_temporaries.jac` | 2 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_rc_ownership.jac` | 24 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_reloaded_base_layout.jac` | 3 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_seam_order.jac` | 5 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_string_lifetime.jac` | 1 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_type_position_erasure.jac` | 14 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_xmod_inherited_fields.jac` | 8 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_pyast_native_import_fact.jac` | 15 | reads the tree / pass outputs | internals |

### Native link plan and registry (suite `native_link`)

Rule: link-plan / registry assertions: kernel suite (link runs in the kernel, step 10); artifacts: `native_build` CLI

| File | Tests | Today | Target |
|---|---|---|---|
| `jac/tests/compiler/backends/native/test_link_plan.jac` | 46 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_glue_symbols_cache.jac` | 3 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/backends/native/test_native_publication.jac` | 6 | reads the tree / pass outputs | internals |
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
| `jac/jaclang/compiler/tests/test_stubcat_roundtrip.jac` | 5 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/test_cache_verdict_determinism.jac` | 3 | diagnostics only | compile entry (verify no tree reads) |
| `jac/tests/compiler/test_client_artifact_cache.jac` | 6 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/test_compile_artifact_retention.jac` | 7 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/test_compile_lifetime.jac` | 3 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/test_failed_module_reparse.jac` | 6 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/test_iface_cache.jac` | 36 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/test_module_release.jac` | 12 | reads the tree / pass outputs | internals |
| `jac/tests/compiler/test_precompiled_interfaces.jac` | 10 | reads the tree / pass outputs | internals |

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
| `jac/tests/compiler/test_native_in_kernel.jac` | 8 | diagnostics only | host, compile entry |

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

## Individual tests left in converted files

These native and plumbing files are on the kernel helpers except for the tests below. Each still reads a host tree or registry and moves to the suite named.

| File | Tests | Reads | Suite |
|---|---|---|---|
| `backends/native/test_inherited_slot_headers.jac` | 4 "layout adoption" tests | `gen.layout_registry` | `native_layout` |
| `backends/native/test_native_xmod_inherited_fields.jac` | 3, plus the layout half of 1 | `get_layout_registry` field, method and vtable slots | `native_layout` |
| `backends/native/test_native_enum_ctor.jac` | 1 | `get_enum_layout("Flags")` | `native_layout` |
| `backends/native/test_native_reloaded_base_layout.jac` | 2 | `prog.mod.hub`, `get_layout_registry`, `gen.native_layout` | `native_layout` |
| `backends/native/test_native_interface_class_names.jac` | 1 | hub tree, `archetype_native_name`, the type evaluator | `native_layout` |
| `backends/native/test_pyast_native_import_fact.jac` | 6 | `native_only_drop`, `python_side_name_refs`, `import_bound_names`, `clib_decls`, `decided_codespace` | `codegen` |
| `backends/native/test_native_func_body_import.jac` | "nested imports are harvested only from native-context elements" | `ModuleFacts.iter_context_stmts` / `iter_nested_imports` | `placement` |
| `backends/native/test_native_type_position_erasure.jac` | 5 + 2 + 2 | `native_capability_violations`; `scan_native_blockers` on `rd_parse`; ABC parents / vtable slots in `get_layout_registry` | `placement`, `native_layout` |
| `backends/native/test_native_abc_erasure.jac` | 4 | `rd_parse` + `scan_native_blockers` | `placement` |
| `backends/native/test_native_erased_any.jac` | 2 | `scan_native_blockers`, `ModuleFacts.is_erased_type_decl` | `placement` |
| `backends/native/test_native_from_import_capability.jac` | 6 | host `rd_parse` + `scan_native_blockers` | `placement` |
| `backends/native/test_native_gate.jac` | 2 | `ModuleFacts.has_native_context_stmts` | `placement` |
| `backends/native/test_anon_region_infer.jac` | 3 `OpenStmt` tests | the RegionInferPass output tree | `ownership_layout` |
| `backends/native/test_native_seam_order.jac` | 1 | `uni.Test.code_context` | `mir_decisions` |
| `backends/native/test_native_closed_world.jac` | 1 | `build_native_legality`, a mutated `interop_manifest` | `placement` |
| `backends/native/test_native_iface.jac` | 1 | host JIR cache, `native_units().stamp_for` | `driver_caches` |
| `backends/native/test_native_publication.jac` | 1 | `native_units().object_for`, `get_bytecode`, cache sections | `driver_caches` |
| `backends/native/test_link_plan.jac` | 3, and the file's `build_link_plan` dependence | `record_module` on a real tree, analysis-only events, `NativeBuildSession` internals | `native_link` |
| `backends/native/test_native_inline_checked_helpers.jac` | "a checked accessor inlines into every caller of its unit" | the unit's optimized bitcode, which no kernel product exposes | `native_link` |
| `backends/native/test_native_gen_pass.jac` | func_ptr_fields and test-table layout probes (deleted from the host file) | struct field representation, the tagged optional slot, the test table | `mir_decisions` |
| `backends/native/test_native_iteration_facts.jac`, `test_native_intrinsic_registry.jac`, `test_native_class_const_read.jac`, `test_native_enum_auto.jac`, `test_native_type_cache.jac` (deleted) | dropped tree halves | tuple iteration target types; `FuncCall` types against the registry; `field_index` / `has_vtable` / enum values; MIR type cache identity | `native_layout`, `mir_decisions` |
| `test_codespace_inference.jac` | about 55 | `stamp_of`, `gen.js`, `client_manifest`, `native_engine` | `placement`; many become `kernel_check_file(placements=True)` rows |
| `test_native_legality.jac` | 21 | `placed_by_name`, `capability_notes_of`, parse counts, `native_placement_candidate` | `placement` |
| `test_front_end_native_idioms.jac` | "scan_native_blockers names the offending node" | placement scan | `placement` |
| `test_iface_cache.jac` | most | interface sections and hydration | `driver_caches` |
| `test_warm_cache_codespace.jac` | schedule and bootstrap-tier tests | host selfhost | delete with step 17 |
| `test_no_llvm_degradation.jac` | 2 `pipeline.resolve` tests, and the deleted "no-llvm run degrades to server" | the shim verdict | `native_link` (availability) |

## Oracle tests ahead of MIR

These native tests now assert what the MIR backend must do. They fail until MIR does it, and that is intended: they are the backend's oracle.

- **C ABI coercion.** sret, byval and eightbyte classification are not done; `abi.impl.jac` exists but MIR emission does not use it. Affected: SysV, AArch64, struct coercion, bytes arguments.
- **Memory.** `memory_profile` / `na_gc_mode` (RC-free IR under nogc, per-gc-mode fan-out), borrow awareness (no-retain walks, noalias/readonly attributes), region runtime calls, stack promotion, move elision, `&mut` lending, `preserve_none`.
- **Representations.** `list.aos`, views in chunked flow bodies, `str.make` slices, `opt` payloads, pthread flow tasks, `**kwargs` callees, and E5095 on `__list_data_ptr`.
- **Interfaces.** `NativeIface.classes`, `clib_symbol_lib`, `layout` and `headerless` are not filled by `MirNativePass.interface`.
- **Refusal reasons.** Some tests expect the refused construct named in the reason (`Merger.merge`, `struct.pack`, ABC and enum names). Today's reasons are `"<kind> '<name>'"`, `"calls <symbol>, which is not native"` and `"an override in its vtable is not native"`.
- **Retired codes.** MIR reports only E5092. The E5088/E5089 pins are dropped, and the tier_conformance walker test checks the required-native E5092.

## The check_src rewrite script

```python
# python3 xform.py apply  (run from jac/, over the files listed above)
pat = re.compile(r'''(?P<indent>[ ]*)(?P<p>\w+) = JacProgram\(\);\n(?P=indent)(?P=p)\.compile\(\s*(?:file_path=)?(?P<fp>"[^"]+"),\s*use_str=(?P<src>\w+),\s*options=CompileOptions\((?P<opts>[^)]*)\)\s*\);\n(?P=indent)return \[str\((?P<e>\w+)\) for (?P=e) in (?P=p)\.errors_had\];''')
# -> return [f"{diag.code}: {diag.message}" for diag in kernel_check_source(src, "name", CompileOptions(<opts minus no_cgen>)).errors];
# then drop the JacProgram / CompileOptions imports when unused and add kernel_check_source to the tests.support import.
```
