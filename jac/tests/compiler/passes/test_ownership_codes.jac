"""Every ownership diagnostic that is a fixture plus an expected code list.

`compile_fixture(F)` then `expect_ownership_codes(prog, [codes])` was the
entire body of 114 tests spread across seventeen files in this directory --
four of which (`test_flow_lending`, `test_ownership_paths`,
`test_ownership_sendability`, `test_seal_connect`) contained no test shape the
others did not. The varying data was always a fixture name and a list of E13xx
codes, so it is a table here and the topic each filename used to carry is the
first column.

Rows run through `parametrize`, which registers each one as its own named
test, so a failure still names the case it came from. The ten tests in those
files that were NOT this shape -- ones that assert on drop counts, help text,
cross-mode output or the absence of non-ownership errors -- stayed in place.
"""

import from jaclang.testing.test { parametrize }
import from tests.ownership_helpers { compile_fixture, expect_ownership_codes }

# (group, case name, fixture, expected E13xx codes, [enforce nogc])
glob OWNERSHIP_CASES: list[tuple] = [
         # -- views -----------------------------------------------------------
         (
             "views",
             "E1306 + E1315: a view built over a local escapes through a return, and is bound own",
             "view_ctor_escape.jac",
             ["E1306", "E1315"]
         ),
         (
             "views",
             "a view over a borrowed parameter used locally is clean",
             "arch_view_local_ok.jac",
             []
         ),
         (
             "views",
             "E1306 + E1315: a view stored into a field, and the holder bound own",
             "view_stored_in_field.jac",
             ["E1306", "E1315"]
         ),
         (
             "views",
             "E1303: mutating the owner while a view of it is live",
             "view_mutate_owner_while_live.jac",
             ["E1303"]
         ),
         (
             "views",
             "E1308: a view cannot cross a flow boundary",
             "view_flow_send.jac",
             ["E1308"]
         ),
         (
             "views",
             "a list of borrows built from a borrowed parameter is clean",
             "view_list_of_borrows_ok.jac",
             []
         ),
         (
             "views",
             "E1315: a list of borrows over a local escapes through a return",
             "view_list_of_borrows_escape.jac",
             ["E1315"],
             True
         ),
         (
             "views",
             "a view returned over the function's borrowed parameter is clean",
             "view_return_from_borrow_param_ok.jac",
             []
         ),
         # -- receiver_modes ---------------------------------------------------
         (
             "receiver_modes",
             "E1303: a mutating method call while a shared borrow is live",
             "method_mut_while_borrowed.jac",
             ["E1303"]
         ),
         (
             "receiver_modes",
             "reading methods through a live shared borrow are clean",
             "method_read_while_borrowed_ok.jac",
             []
         ),
         (
             "receiver_modes",
             "E1303: mutation reached through a self-method chain is still a write",
             "method_mut_via_helper_chain.jac",
             ["E1303"]
         ),
         (
             "receiver_modes",
             "E1318: a mutating method through a shared borrow parameter",
             "method_mut_through_shared_borrow.jac",
             ["E1318"]
         ),
         (
             "receiver_modes",
             "a mutating method through a &mut parameter is clean",
             "method_mut_through_mut_borrow_ok.jac",
             []
         ),
         (
             "receiver_modes",
             "E1309: a mutating method on an imm binding",
             "method_mut_on_imm.jac",
             ["E1309"]
         ),
         (
             "receiver_modes",
             "E1301: reading a binding after a `self: own` method consumed it",
             "method_consumes_self.jac",
             ["E1301"]
         ),
         (
             "receiver_modes",
             "a `self: own` method as the last use is clean",
             "method_consumes_self_ok.jac",
             []
         ),
         # -- affine_walkers --------------------------------------------------
         (
             "affine_walkers",
             "second spawn of an own walker is E1301",
             "walker_double_spawn.jac",
             ["E1301"]
         ),
         (
             "affine_walkers",
             "single spawn of an own walker is clean",
             "walker_single_spawn_ok.jac",
             []
         ),
         (
             "affine_walkers",
             "unannotated walker reuse is untouched",
             "walker_unannotated_spawns.jac",
             []
         ),
         # -- callable_ownership ----------------------------------------------
         (
             "callable_ownership",
             "callable-position own states parse and consumption composes (E1301)",
             "callable_own_states.jac",
             ["E1301"]
         ),
         # -- flow_for --------------------------------------------------------
         (
             "flow_for",
             "break out of the body is E1313, inner-loop break is fine",
             "flow_for_break.jac",
             ["E1313"]
         ),
         (
             "flow_for",
             "lent collections with element writes and scalar captures are clean",
             "flow_for_ok.jac",
             []
         ),
         ("flow_for", "nested flow for is E1313", "flow_for_nested.jac", ["E1313"]),
         ("flow_for", "non-lent collection is E1313", "flow_for_plain.jac", ["E1313"]),
         (
             "flow_for",
             "reduction idiom: += and min/max folds on outer ints are clean",
             "flow_for_reduce.jac",
             []
         ),
         ("flow_for", "return in the body is E1313", "flow_for_return.jac", ["E1313"]),
         (
             "flow_for",
             "shared-mutation captures are E1308",
             "flow_for_capture.jac",
             ["E1308", "E1308"]
         ),
         (
             "flow_for",
             "unlicensed accumulator shapes remain E1308",
             "flow_for_reduce_bad.jac",
             ["E1308", "E1308", "E1308", "E1308"]
         ),
         # -- flow_lending ----------------------------------------------------
         (
             "flow_lending",
             "borrow into flow with a same-block wait before reuse is clean",
             "flow_lend_ok.jac",
             []
         ),
         (
             "flow_lending",
             "borrow into flow with no join stays E1308",
             "flow_lend_no_wait.jac",
             ["E1308"]
         ),
         (
             "flow_lending",
             "owner touched between flow and wait stays E1308",
             "flow_lend_use_before_wait.jac",
             ["E1308"]
         ),
         (
             "flow_lending",
             "side exit between spawn and wait stays E1308",
             "flow_lend_early_exit.jac",
             ["E1308"]
         ),
         # -- frozen_regions --------------------------------------------------
         (
             "frozen_regions",
             "frozen handle crosses flow freely",
             "frozen_region_ok.jac",
             []
         ),
         (
             "frozen_regions",
             "opening a frozen region is E1309",
             "frozen_region_open.jac",
             ["E1309"]
         ),
         (
             "frozen_regions",
             "reopening the consumed source handle is E1301",
             "frozen_region_stale_handle.jac",
             ["E1301"]
         ),
         # -- nogc_own_fields -------------------------------------------------
         (
             "nogc_own_fields",
             "own-field store still consumes the source binding (E1301)",
             "own_field_store_consumes.jac",
             ["E1301"]
         ),
         # -- own_globals -----------------------------------------------------
         ("own_globals", "own globals are clean in the checker", "own_glob_ok.jac", []),
         # -- ownership_check_pass --------------------------------------------
         (
             "ownership_check_pass",
             "E1301: a conditional move reaching a later use is flagged",
             "branch_use_after_move.jac",
             ["E1301"]
         ),
         (
             "ownership_check_pass",
             "E1301: an own value moved then read within one statement",
             "intra_stmt_move_then_read.jac",
             ["E1301"]
         ),
         (
             "ownership_check_pass",
             "E1301: an own value passed twice to one call is moved twice",
             "intra_stmt_double_move_call.jac",
             ["E1301"]
         ),
         (
             "ownership_check_pass",
             "E1301: moving a pre-loop own binding inside a loop body is rejected",
             "move_in_loop.jac",
             ["E1301"]
         ),
         (
             "ownership_check_pass",
             "E1301: reading an owned value after it is sealed into managed storage",
             "membrane_use_after_seal.jac",
             ["E1301"]
         ),
         (
             "ownership_check_pass",
             "E1301: use of an own binding after it is moved",
             "use_after_move.jac",
             ["E1301"]
         ),
         (
             "ownership_check_pass",
             "E1302: two live mutable borrows conflict",
             "two_mut_aliases.jac",
             ["E1302"]
         ),
         (
             "ownership_check_pass",
             "E1303: mutating an owner while a shared borrow is live",
             "mutate_while_shared.jac",
             ["E1303"]
         ),
         (
             "ownership_check_pass",
             "E1304: destroying an owner while borrowed",
             "destroy_while_borrowed.jac",
             ["E1304"]
         ),
         (
             "ownership_check_pass",
             "E1304: moving an owner out while a borrow of it is still live",
             "move_while_borrowed.jac",
             ["E1304"]
         ),
         (
             "ownership_check_pass",
             "E1306: a borrow assigned into an outer scope outlives its owner",
             "escaping_borrow_outlives_owner.jac",
             ["E1306"]
         ),
         (
             "ownership_check_pass",
             "E1306: returning a borrow escapes its scope",
             "escaping_borrow_return.jac",
             ["E1306"]
         ),
         (
             "ownership_check_pass",
             "E1306: storing a borrow into a field escapes its scope",
             "escaping_borrow_field.jac",
             ["E1306"]
         ),
         (
             "ownership_check_pass",
             "E1306: storing a borrow into a subscript slot escapes",
             "escaping_borrow_subscript.jac",
             ["E1306"]
         ),
         (
             "ownership_check_pass",
             "E1308: a borrow handed to a `flow` boundary is not sendable",
             "escaping_borrow_flow.jac",
             ["E1308"]
         ),
         (
             "ownership_check_pass",
             "a binding that is moved but never read again is clean",
             "move_only_ok.jac",
             []
         ),
         (
             "ownership_check_pass",
             "a conditionally-moved binding that is not used afterwards is clean",
             "branch_no_use_ok.jac",
             []
         ),
         (
             "ownership_check_pass",
             "a consumed, unborrowed own binding raises no ownership diagnostics",
             "proven_unique_ok.jac",
             []
         ),
         (
             "ownership_check_pass",
             "a method receiver read alongside a moved argument is clean (one move)",
             "method_recv_and_arg_ok.jac",
             []
         ),
         (
             "ownership_check_pass",
             "a pre-loop own binding only read (not moved) in a loop is clean",
             "read_in_loop_ok.jac",
             []
         ),
         (
             "ownership_check_pass",
             "affine: an own parameter dropped at function end is not a leak",
             "own_param_leak.jac",
             []
         ),
         (
             "ownership_check_pass",
             "affine: an own value dropped at scope end is not a leak",
             "owned_leak.jac",
             []
         ),
         (
             "ownership_check_pass",
             "an own parameter consumed by return is clean (no E1301 re-use)",
             "own_param_consumed_ok.jac",
             []
         ),
         (
             "ownership_check_pass",
             "an own resource handed off before scope end is clean",
             "owned_consumed_ok.jac",
             []
         ),
         (
             "ownership_check_pass",
             "moving an owner after its borrow is dead (NLL) is clean",
             "move_after_borrow_dead_ok.jac",
             []
         ),
         (
             "ownership_check_pass",
             "moving the owned value out by return is clean",
             "return_move_ok.jac",
             []
         ),
         (
             "ownership_check_pass",
             "mutually-exclusive branches each moving the binding is clean",
             "branch_exclusive_ok.jac",
             []
         ),
         (
             "ownership_check_pass",
             "reassigning a moved-from own binding revives it (no diagnostics)",
             "reassign_revives.jac",
             []
         ),
         (
             "ownership_check_pass",
             "returning a borrow parameter (single passthrough) is clean",
             "param_borrow_passthrough_ok.jac",
             []
         ),
         (
             "ownership_check_pass",
             "sealing an owned value into a managed field is clean",
             "membrane_seal_in_ok.jac",
             []
         ),
         (
             "ownership_check_pass",
             "self-reassignment through a consuming call in a loop revives (no E1301)",
             "reassign_through_call_loop_ok.jac",
             []
         ),
         (
             "ownership_check_pass",
             "un-annotated bindings are never move-checked",
             "unannotated_untouched.jac",
             []
         ),
         # -- ownership_freeze ------------------------------------------------
         (
             "ownership_freeze",
             "freeze consumes its argument (E1301 on later reads)",
             "freeze_use_after.jac",
             ["E1301"]
         ),
         (
             "ownership_freeze",
             "freeze of a possibly-aliased managed binding is E1311",
             "freeze_aliased_fenced.jac",
             ["E1311"]
         ),
         (
             "ownership_freeze",
             "writes through a frozen binding are E1309",
             "freeze_imm_write.jac",
             ["E1309"]
         ),
         # -- ownership_markers -----------------------------------------------
         (
             "ownership_markers",
             "E1309: reassigning an `imm` binding is a mutation",
             "marker_imm_reassign.jac",
             ["E1309"]
         ),
         (
             "ownership_markers",
             "E1309: taking a `&mut` through an `imm` binding is a mutation",
             "marker_imm_mut_borrow.jac",
             ["E1309"]
         ),
         (
             "ownership_markers",
             "E1309: writing a field of an `imm` binding is a mutation",
             "marker_imm_field_write.jac",
             ["E1309"]
         ),
         (
             "ownership_markers",
             "reading an `imm` binding (field read, passthrough) is clean",
             "marker_imm_read_ok.jac",
             []
         ),
         # -- ownership_paths -------------------------------------------------
         (
             "ownership_paths",
             "deep paths collapse to the whole object (conservative E1303)",
             "split_fields_deep_path_conservative.jac",
             ["E1303"]
         ),
         (
             "ownership_paths",
             "disjoint fields: shared borrow of one field, write to another is clean",
             "split_fields_disjoint_ok.jac",
             []
         ),
         (
             "ownership_paths",
             "disjoint fields: two mutable borrows of different fields is clean",
             "split_fields_two_mut_ok.jac",
             []
         ),
         (
             "ownership_paths",
             "same field twice: overlapping mutable borrows stay E1302",
             "split_fields_mut_overlap_conflict.jac",
             ["E1302"]
         ),
         (
             "ownership_paths",
             "same field: write under a live shared borrow of that field is E1303",
             "split_fields_same_conflict.jac",
             ["E1303"]
         ),
         (
             "ownership_paths",
             "whole-object borrow still conflicts with any field write (E1303)",
             "split_fields_whole_conflict.jac",
             ["E1303"]
         ),
         # -- ownership_region ------------------------------------------------
         (
             "ownership_region",
             "E1307: a region-local appended to an outer container escapes",
             "region_escape_append_outer.jac",
             ["E1307"]
         ),
         (
             "ownership_region",
             "E1307: a region-local assigned to an enclosing-scope binding escapes",
             "region_escape_outer.jac",
             ["E1307"]
         ),
         (
             "ownership_region",
             "E1307: a heap-typed call result under an open handed to an opaque callee escapes",
             "region_call_result_escape.jac",
             ["E1307"]
         ),
         (
             "ownership_region",
             "E1307: a region-local handed to a `flow` boundary escapes the arena",
             "region_escape_flow.jac",
             ["E1307"]
         ),
         (
             "ownership_region",
             "E1307: a region-local handed to an opaque call statement escapes",
             "region_escape_call_stmt.jac",
             ["E1307"]
         ),
         (
             "ownership_region",
             "E1307: a region-local laundered through an aug-assign escapes",
             "region_escape_aug_store.jac",
             ["E1307"]
         ),
         (
             "ownership_region",
             "E1307: a region-local passed through a call in a return escapes",
             "region_escape_through_call.jac",
             ["E1307"]
         ),
         (
             "ownership_region",
             "E1307: a region-local returned from its function escapes the arena",
             "region_escape_return.jac",
             ["E1307"]
         ),
         (
             "ownership_region",
             "E1307: a region-local returned inside a list literal escapes the arena",
             "region_escape_list.jac",
             ["E1307"]
         ),
         (
             "ownership_region",
             "E1307: a region-local stored into an outer object escapes the arena",
             "region_escape_store.jac",
             ["E1307"]
         ),
         (
             "ownership_region",
             "E1307: a region-local stored via a tuple into an outer binding escapes",
             "region_escape_tuple_store.jac",
             ["E1307"]
         ),
         (
             "ownership_region",
             "R2: E1307 a fresh heap value returned from inside an open",
             "region_escape_fresh_return.jac",
             ["E1307"]
         ),
         (
             "ownership_region",
             "R2: E1307 a region borrow handed to an opaque callee outside the open",
             "region_borrow_launder_reject.jac",
             ["E1307"]
         ),
         (
             "ownership_region",
             "R2: E1307 returning region values rooted in a local handle",
             "region_local_handle_return_reject.jac",
             ["E1307"]
         ),
         (
             "ownership_region",
             "R2: E1307 with two &Region params a region-rooted return is ambiguous",
             "region_two_region_reject.jac",
             ["E1307"]
         ),
         (
             "ownership_region",
             "R2: a call receiving the handle may also take region borrows",
             "region_helper_call_ok.jac",
             []
         ),
         (
             "ownership_region",
             "R2: outward flow to a binding within the handle's extent is clean",
             "region_extent_ok.jac",
             []
         ),
         (
             "ownership_region",
             "R2: single-region elision lets a &Region helper return region values",
             "region_elision_ok.jac",
             []
         ),
         (
             "ownership_region",
             "R2: the result of a &Region call is a usable borrow of the handle",
             "region_call_result_ok.jac",
             []
         ),
         (
             "ownership_region",
             "R3: E1307 sending a handle while borrows of it exist",
             "region_send_borrow_reject.jac",
             ["E1307"]
         ),
         (
             "ownership_region",
             "R3: E1307 wiring a region node to managed topology",
             "region_connect_membrane_reject.jac",
             ["E1307"]
         ),
         (
             "ownership_region",
             "R3: an own handle with no borrows moves across a flow boundary",
             "region_send_ok.jac",
             []
         ),
         (
             "ownership_region",
             "R3: region-internal topology wires freely",
             "region_connect_internal_ok.jac",
             []
         ),
         (
             "ownership_region",
             "R4: an own rebox of a region string field is clean",
             "region_own_rebox_ok.jac",
             []
         ),
         (
             "ownership_region",
             "a container of a region-local kept inside the region is clean",
             "region_container_local_ok.jac",
             []
         ),
         (
             "ownership_region",
             "a region-local stored into a region-allocated object is clean",
             "region_internal_ctor_ok.jac",
             []
         ),
         (
             "ownership_region",
             "a region-local used only inside its region is clean",
             "region_ok.jac",
             []
         ),
         (
             "ownership_region",
             "a scalar field read assigned out of a region is clean",
             "region_scalar_out_ok.jac",
             []
         ),
         # -- ownership_sendability -------------------------------------------
         (
             "ownership_sendability",
             "E1308: a `&` borrow handed to a `flow` boundary is not sendable",
             "send_borrow_flow.jac",
             ["E1308"]
         ),
         (
             "ownership_sendability",
             "E1308: a `&mut` borrow handed to a `flow` boundary is not sendable",
             "send_mut_borrow.jac",
             ["E1308"]
         ),
         (
             "ownership_sendability",
             "E1308: a plain mutable (unannotated) value passed to `flow` is not sendable",
             "send_plain_mutable.jac",
             ["E1308"]
         ),
         (
             "ownership_sendability",
             "a deep-immutable `imm` value is sendable across a `flow` boundary",
             "send_imm_ok.jac",
             []
         ),
         (
             "ownership_sendability",
             "a moved `own` value is sendable across a `flow` boundary",
             "send_own_moved_ok.jac",
             []
         ),
         # -- partition_n -----------------------------------------------------
         (
             "partition_n",
             "arity mismatch, dynamic count, unowned receiver are E1314; children stay affine",
             "partition_n_bad.jac",
             ["E1301", "E1301", "E1301", "E1314", "E1314", "E1314"]
         ),
         (
             "partition_n",
             "matching literal unpack of an owned region is clean",
             "partition_n_ok.jac",
             []
         ),
         # -- ref_loops -------------------------------------------------------
         (
             "ref_loops",
             "growing the container after the loop is clean",
             "ref_loop_grow_after_ok.jac",
             []
         ),
         (
             "ref_loops",
             "growing the iterated container inside the loop is E1303",
             "ref_loop_grow_conflict.jac",
             ["E1303"]
         ),
         (
             "ref_loops",
             "ref-loop reads and post-loop owner reuse are clean",
             "ref_loop_clean.jac",
             []
         ),
         (
             "ref_loops",
             "storing a ref-loop variable into a field is E1306",
             "ref_loop_owner_write.jac",
             ["E1306"]
         ),
         # -- seal_connect ----------------------------------------------------
         (
             "seal_connect",
             "graph operations after the seal are E1307",
             "seal_post_alloc.jac",
             ["E1307", "E1307"]
         ),
         (
             "seal_connect",
             "managed-into-region connect seals cleanly",
             "seal_connect_ok.jac",
             []
         ),
         (
             "seal_connect",
             "non-seal directions stay E1307",
             "seal_wrong_direction.jac",
             ["E1307", "E1307"]
         ),
         (
             "seal_connect",
             "reusing the sealed handle is E1301",
             "seal_handle_reuse.jac",
             ["E1301"]
         ),
         (
             "seal_connect",
             "seal through a borrowed handle stays E1307",
             "seal_borrowed_handle.jac",
             ["E1307"]
         ),
         # -- view_derivation -------------------------------------------------
         (
             "view_derivation",
             "bound, bare, or grown chunks are rejected",
             "chunk_bad.jac",
             ["E1313", "E1313"],
             True
         ),
         (
             "view_derivation",
             "chunked flow for licenses the lent shape only",
             "chunk_ok.jac",
             [],
             True
         ),
         (
             "view_derivation",
             "container, own-binding, and global smuggles are each rejected",
             "view_smuggle_bad.jac",
             ["E1315", "E1315", "E1315"],
             True
         ),
         (
             "view_derivation",
             "local views and single-borrow elision returns are clean",
             "view_local_ok.jac",
             [],
             True
         ),
         (
             "view_derivation",
             "stored views and outliving views are rejected; a two-candidate return ties to both",
             "view_escape_bad.jac",
             ["E1301", "E1315"],
             True
         )
     ];

def _case_id(row: tuple) -> str {
    return f"{row[0]}: {row[1]}";
}

def _ownership_case(row: tuple) {
    enforce = row[4] if len(row) > 4 else False;
    prog = compile_fixture(row[2], enforce=enforce);
    expect_ownership_codes(prog, row[3]);
}

with entry {
    parametrize("ownership", OWNERSHIP_CASES, _ownership_case, id_fn=_case_id);
}
