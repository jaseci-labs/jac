"""The type-system stage's native measurement, pinned the way the unitree seal is.

`types.jac` is the keystone: nothing else in `jaclang.compiler.type_system` can
enter a native unit until the module that defines `ClassType` lowers, because
every other module in the stage carries its types in fields and signatures. A
module-scoped refusal denies the whole module its IR, so a seam coverage report taken
against it reads "not reached" rather than "clean" -- which is why `has_ir` is
asserted before any seam count is believed.

Seven measurements, one memoized coverage run each, and they answer different
questions:

* `types.jac` -- does the keystone reach codegen at all, and which of its
  methods still seam. Its closure membership is pinned too: a new native
  dependency (a module-level import replacing a typing-only or function-local
  one) has to reach zero seams before the stage can seal, so it fails loudly
  here rather than at seal time.
* `properties.jac` -- lowers whole. It is the first module above the keystone
  to do so, and it does it with no waiver of its own, which is the shape the
  rest of the stage is aiming at.
* `ts_decl_parser.jac` -- already clean, and pinned so it stays that way.
* `type_evaluator.jac` -- the stage's upper half. Field declarations were
  the last construct no callable owned: since #8234 a constructor owns its own
  body and since #8285 a signature owns its own annotation, but a `has` type is
  resolved while the struct is laid out, outside every body, so one
  un-lowerable declaration cost the module its IR and all two hundred of its
  abilities their measurement. The declaration owns its refusal now, the module
  keeps its IR, and the seam map below is the stage's upper half measured
  rather than refused. Being measured is what retired one of the two
  declarations: the refusal named a whole `dict` type, and measuring it said
  the bare `tuple` key was the only un-lowerable half.
* `type_checker_pass.jac` -- the evaluator's only consumer, and the other half
  of the pair M2 has to seal. It reaches codegen already; what it does not
  reach is the evaluator, and the coverage says so in one number.
* `enum_utils.jac` and `operations.jac` -- measurable since #8285. A parameter
  typed `TypeEvaluator` is resolved when the ability is declared, which used to
  be before any body opened a demotion window, so it stranded the module the
  way a field declaration does. The declaration owns the refusal now: each
  callable that names an evaluator-side type in its signature is a seam, every
  other body in both modules lowers, and the module keeps its IR.

Waivers are enumerated one at a time and name what blocks each, so the suite
never degrades into a "fewer than N" threshold: an un-waived seam fails, a
waiver that stops matching a real seam fails too, and a seam that starts
demoting for a different reason than the one recorded fails as well, which
keeps the baseline current as the backend grows. The two big tables are keyed
cause-first -- one cause, the members that demote on it -- because that is the
shape the measurement actually has: 80 evaluator seams across 41 causes, 42
checker seams across 8, and in the checker the largest single cause is worth
more than four fifths of the file. Every member is still named individually, so
nothing here is a count.

Only seams in files this stage owns are enumerated -- `unitree.jac`,
`type_utils.jac` and `helpers.jac` ride in `types.jac`'s closure and their
seams are owned by `test_unitree_seal_baseline.jac`, the seal's own gate, which
would double-book them here.
"""

import os;
import jaclang;
import from pathlib { Path }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_coverage_begin, na_coverage_end }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.sealed { native_artifact_for }

glob PKG_PATH = Path(jaclang.__file__).parent,
     TS_PATH = PKG_PATH / "compiler" / "type_system",
     CHECKER_SRC = PKG_PATH / "compiler" / "passes" / "main" / "type_checker_pass.jac";

"""Every module the native compile of `types.jac` puts in its closure.

`operations` and the evaluator are deliberately absent: the methods that reach
them are seams, so their calls never become native edges. `unitree` is present
and cannot be avoided -- `ClassDetailsShared.symbol_table` is a `UniScopeNode`
field, which is a layout dependency no matter that the import is `import type`.

`type_utils` is present now and was not before. `ClassVar` becoming a
compile-time import name made `types.jac` linkable, which closed the
`unitree <-> types` layout cycle in the other direction too, and the modules
on the far side of it are in the unit whichever end is the root. This set is
`unitree`'s closure exactly -- `test_unitree_seal_baseline.jac` pins the same
eleven from the other root, and that is the seal's own view.
"""
glob TYPES_CLOSURE: tuple = (
         "_hashlib_native.jac",
         "constant.jac",
         "fnmatch.jac",
         "hashlib.jac",
         "helpers.jac",
         "pathlib.jac",
         "srcloc.jac",
         "type_registry.jac",
         "type_utils.jac",
         "types.jac",
         "unitree.jac"
     ),
     DECL_PARSER_CLOSURE: tuple = ("ts_decl_parser.jac", ),
     # `properties.jac` links the keystone and nothing above it, so its unit is
     # the eleven minus `type_utils`'s own leaves that it does not reach.
     PROPERTIES_CLOSURE: tuple = (
         "_hashlib_native.jac",
         "constant.jac",
         "fnmatch.jac",
         "hashlib.jac",
         "helpers.jac",
         "pathlib.jac",
         "properties.jac",
         "srcloc.jac",
         "type_registry.jac",
         "type_utils.jac",
         "types.jac",
         "unitree.jac"
     ),
     # The two modules whose evaluator-side signatures demote (#8285) reach the
     # same set, so it is named once and the module's own file is added per
     # case. A signature refusal costs its callable a native body, not the unit
     # around it, so this is the closure of a module that lowers.
     SIGNATURE_SEAM_CLOSURE: tuple = (
         "_hashlib_native.jac",
         "const_fold.jac",
         "constant.jac",
         "diagnostics.jac",
         "fnmatch.jac",
         "hashlib.jac",
         "helpers.jac",
         "pathlib.jac",
         "srcloc.jac",
         "type_registry.jac",
         "type_utils.jac",
         "types.jac",
         "unitree.jac"
     );

"""Files this stage owns; seams outside them belong to another coverage test."""
glob STAGE_FILES: tuple = ("types.jac", "ts_decl_parser.jac");

"""Seams that stay, each naming what has to land before it goes.

Keyed `<module>::<Type>.<method>` exactly as `_seal_demotions` keys them, so an
entry reads the same as one in `NATIVE_SEAL_DEMOTION_WAIVERS` when the stage
eventually joins `NATIVE_SEAL_ROOTS`. A `<field>.__get__` entry is a property;
#8074 made accessors lower as methods, so their bodies reach the backend.

Five element-erasure waivers left this table when optional containers learned
to keep their element layout: `TypeBase.mangle`, `ClassType.__str__`,
`FunctionType.__str__`, `UnionType.__str__` and `ClassType.clone_with_literal`
walked or sliced `list[T] | None` slots and now lower. Three entries survived
that erasure but for a reason their old text did not name -- the two
remaining `clone_*` methods and `specialize_func_type_vars` -- so their
waivers were rewritten rather than kept.

A sixth left when `ClassType.get_class_symbol` stopped needing a waiver at
all. It was waived as "Python-only", but the real defect was a declared type:
`ClassDetailsShared.symbol_table` is typed `UniScopeNode`, which has no
`name`, while every caller passes the `Archetype` that does. Narrowing to the
`Archetype` made both the checker and the backend accept it, so the method
lowers rather than being excused.

A seventh left with #8256. `TypeBase.category.__get__` reads `self.CATEGORY`,
a `ClassVar` the abstract base declares without a value and every subclass
redefines. The backend now gives each declaring class its own constant and
picks between them on the receiver's vtable, so the accessor lowers and the
read answers per class rather than defaulting.

The two `clone_as_*` waivers left with #8266. `TypeFlags(...)` is a
value-to-member lookup, and for an int-valued enum the member *is* the value,
so the emitter checks it against the declared member table and raises the
`ValueError` CPython raises. `create_callable_type` was recorded as unaffected
by that change, and it was: its `ParameterCategory` members are `auto()`, and
no fold reached them, so the table its read needed could not be encoded.

That waiver is gone now, and it is the ninth. `auto()` has no value of its own
to fold -- CPython generates one from the members already assigned -- so the
answer belongs beside the enum's layout rather than in the constant folder.
The members are read in source order and the generated value is
`max(seen) + 1`, which gives `ParameterCategory` its table and lets a member
read off the class lower. `test_native_enum_auto.jac` owns the rule; the size
of what it bought is recorded in the evaluator's table below, because
`ArgsList` was the same read.

An eighth left when `type_utils` joined the closure.
`FunctionType.specialize_func_type_vars` was waived as calling a function
"outside this closure", and it is inside now, so it lowers.

Two arrived in their place, and both are cross-module cascades #8272 made
measurable: `FunctionType.specialize` and `ClassType.lookup_member_symbol`
each call a `type_utils` function that demotes. Before that protocol the
importer emitted their call sites before the dependency's verdicts existed,
so the caller lowered and the artifact linked against a name the demotion had
renamed away. Every seam this table holds is identical to the one the unitree
coverage records for `types.jac` from the other root, which is the point: the
seal reads the closure, not the entry it was reached from.
"""
glob TYPES_SEAM_WAIVERS: dict[(str, str)] = {
         "types.jac::ClassType.lookup_member_symbol": (
             "Cascade: calls `type_utils.collect_member_syms`, which demotes "
             "on `helpers.evaluate_version_condition` and is waived in the "
             "unitree coverage."
         ),
         "types.jac::FunctionType.specialize": (
             "Cascade: calls `type_utils.build_type_var_solution`, waived in "
             "the unitree coverage for its `enumerate(...)` for-loop iterable."
         )
     },
     DECL_PARSER_SEAM_WAIVERS: dict[(str, str)] = {
         "ts_decl_parser.jac::_parse_dts_inner": (
             "Backend gap: `set.add` on a set built from an inferred element "
             "type; the emitter has no layout for the set's element."
         )
     };

"""Every module the native compile of `type_evaluator.jac` puts in its closure.

Nine more than the keystone's, and every one of them arrives through a
module-level import in the evaluator itself: `enum_utils`, `operations`,
`properties`, `ts_decl_parser` and `diagnostics` directly, `const_fold`,
`client_kind` and `client_kind_paths` behind them. `type_evaluator.jac` is in
its own closure, which is the whole point of this file: before a declaration
could own its refusal the module had no IR to be in anyone's closure with.

`program.jac` is deliberately absent even though `TypeEvaluator.program` is
typed `JacProgram`. `import type` keeps it out, and the declaration erases to
an opaque slot rather than dragging the compiler driver into the type system's
unit -- measured, not assumed: unquoting the annotation moves the refusal's
label from `[MultiString]` to `JacProgram` and changes nothing else, not this
list and not the seam count.
"""
glob EVALUATOR_CLOSURE: tuple = (
         "_hashlib_native.jac",
         "client_kind.jac",
         "client_kind_paths.jac",
         "const_fold.jac",
         "constant.jac",
         "diagnostics.jac",
         "enum_utils.jac",
         "fnmatch.jac",
         "hashlib.jac",
         "helpers.jac",
         "operations.jac",
         "pathlib.jac",
         "properties.jac",
         "srcloc.jac",
         "ts_decl_parser.jac",
         "type_evaluator.jac",
         "type_registry.jac",
         "type_utils.jac",
         "types.jac",
         "unitree.jac"
     );

"""The evaluator's coverage: 80 seams, keyed by the cause they share.

Keyed cause-first because the measurement has that shape. Forty-eight of the
80 are cascades on a sibling method -- a body whose only refusal is that it
calls something the backend already demoted -- so a flat table would print
the same sentence forty-eight times and hide the fact that the file's fate
rests on a handful of roots.

It read 109 across 50 causes when it was first taken and 106 across 46 after
`test_native_enum_auto.jac`'s rule generated `auto()`'s values. It reads 80
across 41 now, and one declaration closed the difference: `_pass` was typed
`object | None`.

That is the whole of the `**` gap, and it was never a `**` gap. The coverage
recorded `TypeEvaluator.emit_diag` as demoting on `call argument unpacking
'**'` and read the spelling as the cause, with thirty seams hanging off it --
`emit_diag`, its seven callers, and the twenty-one behind
`get_type_of_expression`. Measured, the backend lowers `f(**kwargs)` fine
whenever it can *see* a `**kwargs` sink on the callee: `Transform.emit`
forwards to `DiagnosticInfo.format_message(**kwargs)` inside its own unit and
reaches zero seams doing it. What it cannot do is find a sink on a receiver
typed `object`. So the refusal named the argument shape at the call while the
defect was the annotation on the field being called through, and the fix is
one word: `_pass: Transform | None`.

Typing it retired four causes outright and cost nothing anywhere else -- the
closure below is unchanged, because `Transform` erases to an opaque slot here
for a reason recorded under the checker's table. A method call through an
erased slot still lowers, through the Python-object bridge that carries the
receiver; a *field read* through one does not, and that asymmetry is the
whole of what typing `_pass` did and did not buy:

* `call argument unpacking '**'` and `method 'TypeEvaluator.emit_diag'` --
  gone, with all thirty seams behind them. `get_type_of_expression` lowers,
  and its twenty-one-method cascade lowers with it.
* `attribute access 'emit'` and `method 'TypeEvaluator.match_args_to_params'`
  -- gone. `match_args_to_params` called `self._pass.emit(E1051, ...)`
  directly and refused on the attribute; the call resolves now.
* `attribute access 'cur_node'` and `'errors_had'` -- still here, and they
  are the field reads. `_in_native_context` reads `self._pass?.cur_node` and
  `_resolve_type_alias_rhs` reads `pass_ref.errors_had`, and an erased slot
  has no offset to read them from. They clear when `transform.jac` joins a
  closure, which is the one mechanism the checker's table names.
* `attribute access 'prog'` -- gone as a cause and returned as
  `'errors_had'`, one read further along the same body.

Three module-level imports left with the same change, and they are not
cosmetic: they are what `native_default_path_ok` scans. `PyastBuildPass` and
`SymTabBuildPass` were imported and never used anywhere in the stage, and
`pyast_load_pass.jac` carries a `non-native import 'ast'` blocker, so the
dead import alone denied the evaluator every native closure it might join.
`symbol_utils.jac` reaches `compiler.jac`, whose blocker is `root access
(persistent graph)`; its one use is a single call in
`create_key_for_reference`, so the import moved into that body, where the
placement scan skips it. `int_subscript_suffix` is still a seam and still
filed as one -- the point of the move is the blocker, not the seam.

The roots that are left, which is what M2 has to spend its work on:

* `attribute access 'symbol'`, `'_sym_category'`, `'cur_node'`,
  `'errors_had'`, `'name'` -- reads the backend cannot place.
* `Python module import 'ast'` -- four methods that read CPython's parser for
  `__all__`, ambient imports and string annotations. No native unit can host
  these; they are the stage's honest Python floor, and per decision 1 of
  #8323 they ride as waived seams rather than blocking the seal.
* `function '...'` entries naming a callee outside this unit -- the `client_*`
  and project-root helpers are filesystem probes; `int_subscript_suffix` is
  the hoist described above.
* `type 'JacProgram'` -- the one field declaration left, below.
* `erased field 'TypeEvaluator.program'` -- the four methods that touch the
  erased slot, refusing inside themselves rather than at the declaration.

The declaration seam is the reason this table exists at all. A `has` type is
resolved while the archetype's struct is laid out, outside every ability body,
so an `E5092` raised there had no demotion window: it survived to the end of
the run, where a non-empty `errors_had` withholds the module's IR, and every
importer that compiled the evaluator as a dependency inherited the refusal. The
seven CPython `ast` handles that used to head that list moved into
`_read_dunder_all` and `_read_ambient_imports_by_module` (#8237); the three
that `postinit` used to strand became owned seams with #8234; three more named
`enum_utils` and `operations` and became signature seams with #8285. Field
declarations were the last kind left. They are seams on the field now: the slot
erases to an opaque pointer, joins the foreign set, and every read, write and
constructor argument that touches it refuses inside the callable performing it.

`TypeEvaluator.program` clears when `JacProgram` acquires a native layout, and
nothing smaller will do it: the annotation reaches the backend through an
`import type`, which is what keeps `program.jac` out of the closure above, and
the erasure is what keeps it out now that the annotation is unquoted.
"""
glob EVALUATOR_SEAM_WAIVERS: dict[(str, tuple)] = {
         "method 'TypeEvaluator.assign_type'": (
             "TypeEvaluator._assign_callable",
             "TypeEvaluator._assign_class",
             "TypeEvaluator._get_type_of_expression_core",
             "TypeEvaluator._validate_component_jsx_props",
             "TypeEvaluator._validate_intrinsic_jsx_props",
             "TypeEvaluator.assign_type_to_type_var",
             "TypeEvaluator.validate_arg_types"
         ),
         "expression 'FuncCall'": (
             "TypeEvaluator.__post_init__",
             "TypeEvaluator._extract_tuple_element_type",
             "TypeEvaluator._get_signature_type_params",
             "TypeEvaluator._is_sv_async_call",
             "TypeEvaluator._map_ts_type",
             "TypeEvaluator._resolve_star_import_symbol"
         ),
         "method 'TypeEvaluator.create_key_for_reference'": (
             "TypeEvaluator._extract_callable_info",
             "TypeEvaluator._extract_hasattr_info",
             "TypeEvaluator._extract_isinstance_info",
             "TypeEvaluator._extract_type_guard_info",
             "TypeEvaluator.classify_condition",
             "TypeEvaluator.get_narrowed_type_for_expr"
         ),
         "method 'TypeEvaluator.get_type_of_class'": (
             "TypeEvaluator._get_outer_scope_type_params",
             "TypeEvaluator._get_type_of_self",
             "TypeEvaluator._get_type_of_super",
             "TypeEvaluator._type_var_bound_in_scope",
             "TypeEvaluator.validate_typevar_variance"
         ),
         "erased field 'TypeEvaluator.program'": (
             "TypeEvaluator._client_entry_mod_path",
             "TypeEvaluator._import_module_from_path",
             "TypeEvaluator._is_mobui_module",
             "TypeEvaluator._load_stub_module"
         ),
         "method 'TypeEvaluator.is_sub_class'": (
             "TypeEvaluator._find_predicate_for",
             "TypeEvaluator._narrow_member_to",
             "TypeEvaluator._specialize_narrow_from_base",
             "TypeEvaluator._type_matches_isinstance"
         ),
         "unsupported Python module import 'ast'": (
             "TypeEvaluator._read_ambient_imports_by_module",
             "TypeEvaluator._read_dunder_all",
             "TypeEvaluator._resolve_py_ast_type_node",
             "TypeEvaluator._resolve_string_type_expr"
         ),
         "attribute access 'symbol'": (
             "TypeEvaluator._get_method_with_overloads",
             "TypeEvaluator.get_type_of_member"
         ),
         "for-loop iterable 'FuncCall'": (
             "TypeEvaluator._build_field_params",
             "TypeEvaluator._build_typeddict_fields"
         ),
         "function 'collect_assignment_target_keys'": (
             "TypeEvaluator._get_type_from_flow_node",
             "TypeEvaluator._loop_body_writes_target"
         ),
         "function 'get_special_enum_value_type_from_bases'": (
             "TypeEvaluator.get_type_of_class",
             "TypeEvaluator.get_type_of_enum"
         ),
         "method 'TypeEvaluator._build_field_params'": (
             "TypeEvaluator._create_dataclass_init_method",
             "TypeEvaluator._create_namedtuple_new_method"
         ),
         "method 'TypeEvaluator._extract_tuple_element_type'": (
             "TypeEvaluator._extract_tuple_element_type_path",
             "TypeEvaluator._tuple_literal_index_type"
         ),
         "method 'TypeEvaluator._in_native_context'": (
             "TypeEvaluator.assign_type",
             "TypeEvaluator.validate_call_args"
         ),
         "method 'TypeEvaluator.get_type_of_enum'": (
             "TypeEvaluator._get_enum_member_type_for_decl",
             "TypeEvaluator._get_type_of_symbol"
         ),
         "method 'TypeEvaluator.get_type_of_module'": (
             "TypeEvaluator.get_type_of_module_item",
             "TypeEvaluator.resolve_imported_symbols"
         ),
         "unsupported Python module import 'jaclang.compiler.type_system'": (
             "TypeEvaluator._get_declared_return_type",
             "TypeEvaluator._infer_lambda_block_return_type"
         ),
         "attribute access 'cur_node'": ("TypeEvaluator._in_native_context", ),
         "attribute access 'errors_had'": ("TypeEvaluator._resolve_type_alias_rhs", ),
         "builtin call 'isinstance against `UniCFGNode`'": ("_find_cfg_node_for", ),
         "builtin call 'isinstance'": ("TypeEvaluator._union_narrowed_types", ),
         "expression 'CompareExpr'": ("TypeEvaluator._synthesize_typeddict_method", ),
         "expression 'comprehension over an element-erased collection'": (
             "TypeEvaluator._ts_synth_class_types",

         ),
         "function 'build_type_var_solution'": (
             "TypeEvaluator.specialize_member_type",

         ),
         "function 'compute_mro_linearization'": ("TypeEvaluator.is_sub_class", ),
         "function 'find_destructure_index_path'": (
             "TypeEvaluator._get_type_of_lhs_assignment",

         ),
         "function 'find_jac_project_root'": (
             "TypeEvaluator._untyped_external_is_error",

         ),
         "function 'has_client_npm_package'": ("TypeEvaluator._client_npm_base", ),
         "function 'int_subscript_suffix'": (
             "TypeEvaluator.create_key_for_reference",

         ),
         "function 'is_untyped_third_party_module'": (
             "TypeEvaluator._resolve_submodule_attr",

         ),
         "function 'open'": ("TypeEvaluator._load_ts_declarations", ),
         "function 'resolve_client_npm_package'": (
             "TypeEvaluator._resolve_client_npm_module",

         ),
         "function 'resolve_importer_path_from_node'": (
             "TypeEvaluator._resolve_importer_path",

         ),
         "function 'sibling_declaration_file'": (
             "TypeEvaluator._get_ts_declared_item_type",

         ),
         "method 'TypeEvaluator._create_dataclass_init_method'": (
             "TypeEvaluator._find_matching_raw_constructor",

         ),
         "method 'TypeEvaluator._get_signature_type_params'": (
             "TypeEvaluator._get_function_type_params",

         ),
         "method 'TypeEvaluator._get_type_from_flow_node'": (
             "TypeEvaluator._if_exit_type",

         ),
         "method 'TypeEvaluator.validate_arg_types'": (
             "TypeEvaluator._validate_constructor_method",

         ),
         "type 'JacProgram'": ("TypeEvaluator.program", ),
         "unsupported attribute access '_sym_category'": (
             "TypeEvaluator.get_type_of_module",

         ),
         "unsupported attribute access 'name'": (
             "TypeEvaluator._collect_type_var_bindings",

         )
     };

"""Every module the native compile of `type_checker_pass.jac` puts in its closure.

The load-bearing entry is the one that is missing. `type_evaluator.jac` is not
here, and neither is anything the evaluator alone drags in (`enum_utils`,
`properties`, `ts_decl_parser`, `client_kind`), because the checker never names
the evaluator at module scope: it reaches one through
`self.prog.get_type_evaluator()` in `before_pass` and stores it on an attribute
it does not declare. Fifteen modules here against the evaluator's twenty, and
the two sets are not nested -- they share thirteen and each has its own.
"""
glob CHECKER_CLOSURE: tuple = (
         "_hashlib_native.jac",
         "const_fold.jac",
         "constant.jac",
         "diagnostics.jac",
         "fnmatch.jac",
         "hashlib.jac",
         "helpers.jac",
         "operations.jac",
         "pathlib.jac",
         "srcloc.jac",
         "type_checker_pass.jac",
         "type_registry.jac",
         "type_utils.jac",
         "types.jac",
         "unitree.jac"
     );

"""The checker's coverage, and the handshake decision it decides.

Forty-three seams, and 36 of them -- every visitor the pass has except the
seven that fail earlier for their own reasons -- are one cause: `self.evaluator`
is not a declared field. `TypeCheckPass` inherits from `UniPass`, a Python-side
base that no native unit contains, and `before_pass` stamps the evaluator onto
`self` without a `has` for it. The backend therefore reads it the only way it
can, through the Python-object bridge, and the bridge carries `int`, `bool`,
`float`, `str` and class handles -- not a `TypeEvaluator`. So the read refuses,
inside each of the 36 methods that performs it. `inherited field read 'prog'`
is the same mechanism one level up: `BaseTransform.prog` is typed `JacProgram`
through an `import type`, so it has no layout to bridge either.

It read 46 across 9 causes when it was first taken. The second-largest cause,
`variadic parameter '**'`, was recorded here as the evaluator's `emit_diag`
gap paid for a second time, and it was not: measured, the two spellings share
no mechanism. This one was a backend bug of its own. Jac lets a method name
its receiver, `TypeCheckPass.emit` does, and the argument binder then counted
that receiver twice -- once as the call's own offset and again as the `self`
still sitting in the parameter list it walked -- so the `**kwargs` slot was
looked for one argument past the end of the callee. The pre-flight guard that
decides whether the shape is lowerable already subtracted the receiver, so
the two disagreed about the same signature and only the guard was right.
`test_native_kwargs_explicit_self.jac` owns the rule now; four of the five
seams cleared and the fifth, `_check_explicit_any`, moved up into the
evaluator cause below. #8326's `_diag_erased_membership` then added a
thirty-sixth, which is the cause's other growth mode and the plainer one:
every new visitor that asks the evaluator a question costs one more seam
until the field is declared.

That is the measured answer to how the pair seals, and it says one closure
rather than two roots with a stamped boundary:

* A stamped boundary can only carry what the bridge carries. The thing the
  checker needs across it is an object handle with 200 methods on it, which is
  exactly what the bridge refuses -- so a boundary would have to stamp every
  answer the evaluator computes, not the evaluator, and the checker asks it
  ~130 distinct questions.
* One closure costs a module-level import and a `has evaluator: TypeEvaluator`
  on the pass. That puts the evaluator's twenty modules and the checker's
  fifteen into one unit of about twenty-two, gives `self.evaluator` a real
  struct slot, and turns 36 boundary refusals into ordinary call-site cascades
  that clear as the evaluator's own methods lower.
* `before_pass` stays a seam either way, and that is the honest stamp: one
  method crosses to Python to fetch the evaluator off `JacProgram`, and every
  method downstream of it reads a native field. #8274's driver-stamped facts
  are the same shape -- one crossing, at a named place, instead of a crossing
  per read.

What blocks doing it is measured now, and it is not the thing the first
recording of this table guessed. That reading said the field could not be
declared `TypeEvaluator` without a value and that declaring it optional would
retype 35 bodies. Neither is true: `TypeCheckPass` is a `class` archetype, so
a valueless `has evaluator: TypeEvaluator;` is an annotation and not a slot --
the same trick `pass_rim` uses for `prog` -- and it imposes no constructor
argument and no optionality on any body.

The flip was performed and measured, and then reverted, because on its own it
does not pay. Declaring the field moves every boundary seam from `inherited
field read 'evaluator'` to `erased field 'TypeCheckPass.evaluator'` and adds
two declaration seams of its own (`TypeCheckPass.evaluator` and
`TypeInferencePass.evaluator`, both `type 'TypeEvaluator'`), so the count goes
up rather than down -- and the closure does not move. `type_evaluator.jac`
still is not in it. A declaration cannot pull a module into a unit; only the
closure walk can, and the closure walk refuses.

The refusal has one name. `resolve_native_module` admits a dependency only if
`placement_solver.native_default_path_ok` says so, and that walks the
dependency's whole transitive scan and fails on the first blocker any member
reports. Measured on this tree, the evaluator reported three:

  - `pyast_load_pass.jac`: `non-native import 'ast'` -- reached by a dead
    module-level import of `PyastBuildPass`. Deleted, with `SymTabBuildPass`
    beside it; neither was used anywhere in the stage.
  - `compiler.jac`: `root access (persistent graph)` -- reached through
    `symbol_utils.jac`. That import moved into the one body that calls it,
    where the placement scan skips it.
  - `codeinfo.jac`: `inference held: 13 own seams, and a closure that reaches
    uni_pass (#8201 wave work)` -- the sole entry in
    `placement.PLACEMENT_INFERENCE_HELD`.

Two of the three are gone. The third is the whole remaining gate, and it is
not the type system's to remove: it is the entry #8323's B4 is scheduled to
empty deliberately. Emptying it locally, as a measurement and not a change,
flips `native_default_path_ok` to `True` for `type_evaluator.jac`,
`transform.jac` and `type_checker_pass.jac` alike -- three for one.

The joint seal was then built in that configuration and measured, so B4 knows
what its entry is worth before it spends the work. With the entry empty and
`has evaluator: TypeEvaluator;` declared, `type_checker_pass.jac` compiles
with IR over a **28-module closure that contains `type_evaluator.jac`**, and
its coverage reads **14 seams across 8 causes against 43 across 8**. Of the 36
boundary refusals, **31 clear outright** and five keep demoting for causes of
their own -- `_insert_builtin_symbols`, `exit_ability`, `exit_archetype` and
`exit_enum` on `inherited field access 'ir_in'`, `exit_assignment` on `field
assignment 'type'`. That distinction is this file's whole discipline and it
is kept here: the boundary read is answered, and what those five were also
waiting on behind it is now visible. The evaluator's own seams stay in the
evaluator's table where they belong. Peak RSS for that compile is **3.40 GiB**
(3.14 GiB for the evaluator
as its own root over 27 modules), which is inside the 4.5 GiB/root the seal
pool sizes on, so the grown closure needs no new capacity law -- at
`JAC_SEAL_JOBS<=3` it is about 10 GiB of the budget #8280 already provides.

What the flip does not buy is the evaluator's own count. Under the same
configuration `type_evaluator.jac` still reads 80 seams across 41 causes:
`attribute access 'cur_node'` clears, and `_in_native_context` immediately
demotes one step deeper on `isinstance(cur, UniNode)` instead, one for one.
`errors_had` does not clear at all. So `transform.jac` in the closure is
necessary for the checker's 35 and worth nothing to the evaluator's table,
which is the kind of thing only measuring finds.

The 14 are named here so the day the flip lands the table is already written.
`inherited field access 'ir_in'` (6 -- `_check_unresolved_lambda_params`,
`_insert_builtin_symbols`, `emit`, `exit_ability`, `exit_archetype`,
`exit_enum`) is the base chain's next wall, one level up from the one this
change answers: `ir_in` is declared on `BaseTransform`, and reading it needs
the same layout `evaluator` just got. `expression 'FuncCall'` (2 --
`after_pass`, `before_pass`) is the honest stamp, `before_pass` having moved
off `inherited field read 'prog'`. `field assignment 'type'` (1 --
`exit_assignment`) and the four ordinary gaps this table already carries
(`classify_call`, `get`, `is_intrinsic`, `type`) round it out, plus `type
'JacProgram'` arriving from the evaluator's declaration now that the
evaluator is in the unit. `_check_unresolved_lambda_params` is new to the
table entirely -- it was never reached before, which is the same "a rise here
can mean a gap elsewhere closed" this file records for `_check_explicit_any`.

It is the same gate three more times over, which is why it is recorded here
rather than in three places:

  - `transform.jac` is held out of every closure by that one entry alone. It
    is the reason `_pass: Transform` erases in the evaluator's table above,
    and therefore the reason `cur_node` and `errors_had` still refuse.
  - `ownership_check_pass.jac`'s eleven `emit` seams are the same wall. With
    the entry lifted, `transform.jac` and `uni_pass.jac` join its closure and
    all eleven clear: 26 own seams to 12, and the `emit` family reads empty.
    `test_pass_seal_wave3_baseline.jac` predicted exactly this and named the
    price as transform's own 33 seams; transform's rung-2 redesign since cut
    that to 3.
  - `static_analysis_pass.jac`'s twelfth seam, `_check_undefined_names`, is
    the same wall reached with an optional `str`. With the entry lifted it
    clears too, and that root reads 5 seams with IR.

So the joint seal is designed, and it is refused for one named, owned,
already-scheduled reason rather than for a list. Nothing in the pair needs a
lowering change to seal: it needs `PLACEMENT_INFERENCE_HELD` empty. What this
change lands is everything that does not: the `**` cluster collected, the two
blockers the type system owns removed, and the third pinned here so that the
day B4 empties the entry, the flip is a two-line edit whose measurement is
already written down.

The other seven seams are ordinary backend gaps and are named individually.
"""
glob CHECKER_SEAM_WAIVERS: dict[(str, tuple)] = {
         "inherited field read 'evaluator'": (
             "TypeCheckPass._body_always_returns",
             "TypeCheckPass._check_event_trigger_archetype",
             "TypeCheckPass._check_explicit_any",
             "TypeCheckPass._diag_erased_membership",
             "TypeCheckPass._enclosing_walker_report_elem_type",
             "TypeCheckPass._eval_unpacking_names",
             "TypeCheckPass._insert_builtin_symbols",
             "TypeCheckPass.enter_ability",
             "TypeCheckPass.enter_with_stmt",
             "TypeCheckPass.exit_ability",
             "TypeCheckPass.exit_archetype",
             "TypeCheckPass.exit_assert_stmt",
             "TypeCheckPass.exit_assignment",
             "TypeCheckPass.exit_atom_trailer",
             "TypeCheckPass.exit_binary_expr",
             "TypeCheckPass.exit_compare_expr",
             "TypeCheckPass.exit_delete_stmt",
             "TypeCheckPass.exit_edge_ref_trailer",
             "TypeCheckPass.exit_enum",
             "TypeCheckPass.exit_filter_compr",
             "TypeCheckPass.exit_formatted_value",
             "TypeCheckPass.exit_has_var",
             "TypeCheckPass.exit_import",
             "TypeCheckPass.exit_in_for_stmt",
             "TypeCheckPass.exit_jsx_element",
             "TypeCheckPass.exit_name",
             "TypeCheckPass.exit_param_var",
             "TypeCheckPass.exit_raise_stmt",
             "TypeCheckPass.exit_report_stmt",
             "TypeCheckPass.exit_return_stmt",
             "TypeCheckPass.exit_special_var_ref",
             "TypeCheckPass.exit_type_alias",
             "TypeCheckPass.exit_visit_stmt",
             "TypeCheckPass.exit_while_stmt",
             "TypeCheckPass.exit_with_stmt",
             "TypeCheckPass.exit_yield_expr"
         ),
         "expression 'AtomTrailer'": ("TypeCheckPass.emit", ),
         "expression 'FuncCall'": ("TypeCheckPass.after_pass", ),
         "function 'classify_call'": ("TypeCheckPass.exit_func_call", ),
         "inherited field read 'prog'": ("TypeCheckPass.before_pass", ),
         "unsupported attribute access 'get'": (
             "TypeCheckPass._check_intrinsic_call",

         ),
         "unsupported attribute access 'is_intrinsic'": (
             "TypeCheckPass._check_intrinsic_collision",

         ),
         "unsupported attribute access 'type'": ("TypeCheckPass.exit_sub_tag", )
     };

"""Seams in the two modules that used to be refused whole by a signature.

Both hold `def f(evaluator: TypeEvaluator, ...)` at module scope, and
`TypeEvaluator` is the stage's upper half -- a class with no native layout. A
signature is resolved when the ability is declared, and until #8285 that was
before any body opened a demotion window, so the failure had no owner and cost
the module its IR the way an un-lowerable field declaration does. The
declaration now owns it, which is the same clearing mechanism #8234 and #8237
applied to constructors and to `postinit` handles.

What is left is a seam per callable that names the evaluator-side type in its
signature, and nothing else: every other body in both modules lowers. These go
when `type_evaluator.jac` gets a native layout, which is M2's work, not this
table's.
"""
glob SIGNATURE_SEAM_WAIVERS: dict[(str, dict)] = {
         "enum_utils.jac": {
             "enum_utils.jac::create_enum_member_info": "TypeEvaluator",
             "enum_utils.jac::validate_enum_member_annotation": "TypeEvaluator",
             "enum_utils.jac::build_enum_members": "TypeEvaluator",
             "enum_utils.jac::get_special_enum_value_type_from_bases": (
                 "PrefetchedTypes"
             )
         },
         "operations.jac": {
             "operations.jac::get_numeric_promotion_type": "TypeEvaluator",
             "operations.jac::get_pow_result_type": "TypeEvaluator",
             "operations.jac::is_annotation_type": "TypeEvaluator",
             "operations.jac::get_type_of_binary_operation": "TypeEvaluator"
         }
     };

glob _COVERAGE_MEMO: dict[(str, tuple)] = {};

"""Compile one module the way `seal_native_artifacts` does, up to the coverage.

Returns the per-module coverage, whether the root produced LLVM IR, and the
native refusals that survived every method demotion -- the ones that own the
`has_ir` verdict.
"""
def _coverage_of(src: Path) -> tuple[(dict, bool, list)] {
    # Runs in dev trees AND inside payload lanes that still compile from
    # source. When THIS runtime serves `unitree` from its own native seal the
    # measurement is not expressible: `unitree` sits in `types.jac`'s closure,
    # so the compile would be answered by the sealed artifact and every
    # assertion below would read an empty closure and pass vacuously.
    if native_artifact_for("jaclang.jac0core.unitree") is not None {
        testskip(
            "unitree is served from this runtime's native seal, so the "
            "type-system closure cannot be measured from source here"
        );
    }
    key = str(src);
    if key in _COVERAGE_MEMO {
        return _COVERAGE_MEMO[key];
    }
    prog = JacProgram();
    na_coverage_begin();
    try {
        ir = prog.compile(
            file_path=key,
            options=CompileOptions(
                aot_mode=True,
                type_check=False,
                force_codespace='native',
                force_target_program=True,
                na_gc_mode='cycles',
                no_ir_cache=True
            )
        );
    } finally {
        coverage = na_coverage_end();
    }
    fatal = [
        str(err)
        for err in prog.errors_had
        if err.code is not None and str(err.code.code).startswith("E50")
    ];
    result = (coverage, ir is not None and ir.gen.llvm_ir is not None, fatal, );
    _COVERAGE_MEMO[key] = result;
    return result;
}

"""Coverage seams as `<module>::<Type>.<method>` -> reason, for the named files."""
def _seams_of(coverage: dict, files: tuple) -> dict[(str, str)] {
    found: dict[(str, str)] = {};
    for (path, rec) in sorted(coverage.items()) {
        where = os.path.basename(path);
        if where not in files {
            continue;
        }
        for seam in (rec["seams"] or []) {
            (name, sep, why) = str(seam).partition(": ");
            found[f"{where}::{name if sep else str(seam)}"] = why if sep else "";
        }
        if rec["outcome"] == "demoted" {
            found[f"{where}::<module>"] = f"[{rec['code']}] {rec['detail']}";
        }
    }
    return found;
}

"""Ownerless refusals as `<file>::<message>`, with the moving location dropped."""
def _fatal_keys(fatal: list) -> set[str] {
    keys: set[str] = set();
    for line in fatal {
        (head, sep, msg) = str(line).partition(": ");
        if not sep {
            keys.add(str(line));
            continue;
        }
        keys.add(f"{os.path.basename(head.split(', line ')[0])}::{msg}");
    }
    return keys;
}

"""A seam's reason with the location and the boilerplate stripped off.

The location moves with every edit above it and the two `E5092` preambles say
nothing a table needs, so what is left is the cause alone -- which is exactly
what the cause-keyed tables above are keyed on.
"""
def _seam_cause(why: str) -> str {
    txt = str(why).split("\n")[0];
    at = txt.find(", col ");
    if at >= 0 {
        sep = txt.find(": ", at);
        if sep >= 0 {
            txt = txt[sep + 2:];
        }
    }
    txt = txt.replace("Native lowering failed for ", "");
    return txt.replace("Native pathway does not yet support ", "unsupported ");
}

"""Assert a cause-keyed seam table against a coverage report, three ways.

Un-waived seams fail, waived members that stopped demoting fail, and -- the
one a flat table cannot check -- a member that still demotes but for a
different cause than the one it is filed under fails too. Without the third a
table of a hundred entries decays into a membership list.
"""
def _assert_grouped_match(found: dict, waived: dict, where: str, label: str) {
    expected: dict[(str, str)] = {};
    for (cause, members) in waived.items() {
        for member in members {
            expected[f"{where}::{member}"] = cause;
        }
    }
    unexpected = sorted(
        k
        for k in found
        if k not in expected
    );
    assert not unexpected , (
        f"{len(unexpected)} un-waived seam(s) in {label}:\n"
        + "\n".join(f"  {k}: {_seam_cause(found[k])}" for k in unexpected)
    );
    stale = sorted(
        k
        for k in expected
        if k not in found
    );
    assert not stale , (
        f"waived seams in {label} that no longer demote -- drop them:\n"
        + "\n".join(f"  {k}: {expected[k]}" for k in stale)
    );
    moved = sorted(
        k
        for k in found
        if expected[k] not in _seam_cause(found[k])
    );
    assert not moved , (
        f"{len(moved)} seam(s) in {label} demote for a cause other than the "
        "one they are filed under; refile them so the table keeps naming real "
        "blockers:\n"
        + "\n".join(
            f"  {k}\n    filed:  {expected[k]}\n    actual: {_seam_cause(found[k])}"
            for k in moved
        )
    );
}

def _assert_waivers_match(found: dict, waived: dict, label: str) {
    unexpected = sorted(
        k
        for k in found
        if k not in waived
    );
    assert not unexpected , (
        f"{len(unexpected)} un-waived seam(s) in {label}:\n"
        + "\n".join(f"  {k}: {found[k]}" for k in unexpected)
    );
    stale = sorted(
        k
        for k in waived
        if k not in found
    );
    assert not stale , (
        f"waived seams in {label} that no longer demote -- drop them:\n"
        + "\n".join(f"  {k}: {waived[k]}" for k in stale)
    );
}


test "types.jac lowers to native IR" {
    (_coverage, has_ir, fatal) = _coverage_of(TS_PATH / "types.jac");
    assert has_ir , (
        "no LLVM IR for types.jac -- the keystone refused codegen, so every "
        "seam count taken against it means 'not reached', not 'clean', and no "
        "type_system module can link it:\n"
        + "\n".join(f"  {f}" for f in fatal)
    );
}


test "types.jac's native closure is exactly the measured set" {
    (coverage, _has_ir, _fatal) = _coverage_of(TS_PATH / "types.jac");
    seen = tuple(sorted({os.path.basename(p) for p in coverage}));
    assert seen == TYPES_CLOSURE , (
        f"types.jac's native closure changed: {seen} != {TYPES_CLOSURE}. "
        "A new member has to reach zero seams too before the stage can seal."
    );
}


test "every types.jac seam is waived, and every waiver is live" {
    (coverage, _has_ir, _fatal) = _coverage_of(TS_PATH / "types.jac");
    _assert_waivers_match(
        _seams_of(coverage, STAGE_FILES), TYPES_SEAM_WAIVERS, "types.jac"
    );
}


test "properties.jac lowers whole" {
    (coverage, has_ir, fatal) = _coverage_of(TS_PATH / "properties.jac");
    assert has_ir , (
        "no LLVM IR for properties.jac -- it links the keystone, so a refusal "
        "here means the keystone stopped being linkable:\n"
        + "\n".join(f"  {f}" for f in fatal)
    );
    seen = tuple(sorted({os.path.basename(p) for p in coverage}));
    assert seen == PROPERTIES_CLOSURE , (
        f"properties.jac's native closure changed: {seen} != " f"{PROPERTIES_CLOSURE}."
    );
    own_seams = _seams_of(coverage, ("properties.jac", ));
    assert not own_seams , (
        f"{len(own_seams)} seam(s) in properties.jac, which lowered whole when "
        "the keystone became linkable:\n"
        + "\n".join(f"  {k}: {own_seams[k]}" for k in sorted(own_seams))
    );
}


test "ts_decl_parser stays clean" {
    (coverage, has_ir, fatal) = _coverage_of(TS_PATH / "ts_decl_parser.jac");
    assert has_ir , (
        "no LLVM IR for ts_decl_parser.jac:\n" + "\n".join(f"  {f}" for f in fatal)
    );
    seen = tuple(sorted({os.path.basename(p) for p in coverage}));
    assert seen == DECL_PARSER_CLOSURE , (
        f"ts_decl_parser.jac's native closure changed: {seen} != "
        f"{DECL_PARSER_CLOSURE}."
    );
    _assert_waivers_match(
        _seams_of(coverage, STAGE_FILES), DECL_PARSER_SEAM_WAIVERS, "ts_decl_parser.jac"
    );
}


test "the evaluator reaches per-method demotion" {
    (coverage, _has_ir, _fatal) = _coverage_of(TS_PATH / "type_evaluator.jac");
    evaluator = [
        rec
        for (path, rec) in coverage.items()
        if os.path.basename(path) == "type_evaluator.jac"
    ];
    assert evaluator , "the coverage recorded nothing for type_evaluator.jac";
    assert evaluator[0]["seams"] , (
        "type_evaluator.jac recorded no seams at all. That is not a clean "
        "module -- it is a module the backend refused before it could isolate "
        "a single one of its 200 abilities, so nothing about it is measured."
    );
}


test "the evaluator lowers to native IR, with no refusal left ownerless" {
    (_coverage, has_ir, fatal) = _coverage_of(TS_PATH / "type_evaluator.jac");
    found = _fatal_keys(fatal);
    assert not found , (
        f"{len(found)} module-scoped native refusal(s) in the evaluator. Each "
        "one costs the whole module its IR, and the partition doctrine has no "
        "construct left that a callable or a field cannot own, so a refusal "
        "here is a hole in that doctrine rather than a waiver candidate:\n"
        + "\n".join(f"  {k}" for k in sorted(found))
    );
    assert has_ir , (
        "no LLVM IR for type_evaluator.jac. Its seam map is then 'not "
        "reached' rather than 'measured', and the stage's upper half is "
        "un-measurable again."
    );
}


test "the evaluator's native closure is exactly the measured set" {
    (coverage, _has_ir, _fatal) = _coverage_of(TS_PATH / "type_evaluator.jac");
    seen = tuple(sorted({os.path.basename(p) for p in coverage}));
    assert seen == EVALUATOR_CLOSURE , (
        f"type_evaluator.jac's native closure changed: {seen} != "
        f"{EVALUATOR_CLOSURE}. A new member has to reach zero seams too before "
        "the stage can seal, and `program.jac` appearing here would mean the "
        "compiler driver had been pulled into the type system's unit."
    );
}


test "every evaluator seam is enumerated, and filed under the cause it has" {
    (coverage, _has_ir, _fatal) = _coverage_of(TS_PATH / "type_evaluator.jac");
    _assert_grouped_match(
        _seams_of(coverage, ("type_evaluator.jac", )),
        EVALUATOR_SEAM_WAIVERS,
        "type_evaluator.jac",
        "type_evaluator.jac"
    );
}


test "an un-lowerable declaration is a seam on its field, not on its module" {
    (coverage, has_ir, _fatal) = _coverage_of(TS_PATH / "type_evaluator.jac");
    found = _seams_of(coverage, ("type_evaluator.jac", ));
    decls = sorted(
        k
        for k in found
        if _seam_cause(found[k]).startswith("type '")
    );
    assert decls == ["type_evaluator.jac::TypeEvaluator.program"] , (
        "the declaration seams are not the one field this file names. A "
        "declaration refusal has to key on the field that carries it, because "
        "keying it anywhere else is what used to cost the module its IR, and "
        "the only field left that the backend cannot lay out is the one typed "
        "`JacProgram`:\n"
        + "\n".join(f"  {k}: {_seam_cause(found[k])}" for k in decls)
    );
    assert has_ir , (
        "the declarations own their refusals but the module still lost its IR"
    );
    erased = sorted(
        k
        for k in found
        if "erased field" in _seam_cause(found[k])
    );
    assert erased , (
        "no method reports reading an erased slot. An erased field is storage "
        "the native side never writes, so a read of one has to refuse inside "
        "the callable that performs it -- silence here means the opaque slot "
        "is being answered with its own uninitialised bits."
    );
}


test "the checker lowers, and does not reach the evaluator" {
    (coverage, has_ir, fatal) = _coverage_of(CHECKER_SRC);
    assert has_ir , (
        "no LLVM IR for type_checker_pass.jac:\n" + "\n".join(f"  {f}" for f in fatal)
    );
    seen = tuple(sorted({os.path.basename(p) for p in coverage}));
    assert seen == CHECKER_CLOSURE , (
        f"type_checker_pass.jac's native closure changed: {seen} != "
        f"{CHECKER_CLOSURE}."
    );
    assert "type_evaluator.jac" not in seen , (
        "the evaluator is in the checker's unit now. That is the one-closure "
        "handshake landing, so `self.evaluator` should be a declared field "
        "with a real slot -- update the waivers to the cascades that replace "
        "the boundary refusals rather than keeping this assertion."
    );
}


test "every checker seam is enumerated, and filed under the cause it has" {
    (coverage, _has_ir, _fatal) = _coverage_of(CHECKER_SRC);
    _assert_grouped_match(
        _seams_of(coverage, ("type_checker_pass.jac", )),
        CHECKER_SEAM_WAIVERS,
        "type_checker_pass.jac",
        "type_checker_pass.jac"
    );
}


test "the checker's cost of not declaring its evaluator is one number" {
    (coverage, _has_ir, _fatal) = _coverage_of(CHECKER_SRC);
    found = _seams_of(coverage, ("type_checker_pass.jac", ));
    boundary = sorted(
        k
        for k in found
        if "inherited field read 'evaluator'" in _seam_cause(found[k])
    );
    assert len(boundary) == 36 , (
        f"{len(boundary)} methods refuse on the un-declared `self.evaluator`, "
        "not 36. This number is the handshake's price tag: it is what one "
        "missing `has` on a pass costs, and the seal of the pair is not "
        "closer until it moves. It went up by one when the explicit-self "
        "variadic bug cleared, because `_check_explicit_any` was failing "
        "earlier for that reason and now reaches its evaluator read -- a "
        "rise here can mean a gap elsewhere closed. It went up by one again "
        "with #8326's `_diag_erased_membership`, and that is the other way it "
        "rises: every new checker visitor that asks the evaluator a question "
        "costs one more, which is the tax the declaration retires."
    );
    assert len(boundary) * 100 // max(len(found), 1) >= 70 , (
        "the boundary read has stopped being the checker's dominant cause; "
        "the one-closure argument in this file's tables was decided on it "
        "being so, and should be re-decided if it no longer is."
    );
}


test "a signature type demotes its callable, not its module" {
    for (mod, waived) in sorted(SIGNATURE_SEAM_WAIVERS.items()) {
        (coverage, has_ir, fatal) = _coverage_of(TS_PATH / mod);
        assert has_ir , (
            f"no LLVM IR for {mod} -- a signature the backend cannot resolve "
            f"has to demote the ability that carries it, so nothing here is "
            f"module-fatal any more:\n"
            + "\n".join(f"  {f}" for f in fatal)
        );
        found = _seams_of(coverage, (mod, ));
        _assert_waivers_match(found, waived, mod);
        for (key, tname) in sorted(waived.items()) {
            assert "signature type" in found[key] and tname in found[key] , (
                f"{key} demotes for a different reason now; a signature "
                f"refusal has to name the annotation it could not resolve: "
                f"{found[key]}"
            );
        }
        seen = tuple(sorted({os.path.basename(p) for p in coverage}));
        want = tuple(sorted(SIGNATURE_SEAM_CLOSURE + (mod, )));
        assert seen == want , (
            f"{mod}'s closure is {seen}, not {want}. The demotions cost each "
            "callable its native body, not the unit around them, so a change "
            "here is a change in what the module links."
        );
    }
}
