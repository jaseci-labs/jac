"""Tests for compiler pass schedule invariants."""

import from jaclang.jac0core.compiler {
    get_ir_gen_sched,
    get_type_check_sched,
    get_native_inference_sched
}
import from jaclang.compiler.passes.main.type_checker_pass { TypeCheckPass }
import from jaclang.compiler.passes.main.unitree_enrich_pass { UniTreeEnrichPass }


test "type check schedule does not rerun unitree enrich" {
    ir_sched = get_ir_gen_sched();
    type_check_sched = get_type_check_sched();
    native_inference_sched = get_native_inference_sched();

    assert UniTreeEnrichPass in ir_sched , (
        "IR generation should be the single producer of UniTreeEnrichPass state"
    );
    assert TypeCheckPass in type_check_sched , (
        "explicit type checking should still run TypeCheckPass"
    );
    assert UniTreeEnrichPass not in type_check_sched , (
        "explicit type checking must not rerun UniTreeEnrichPass"
    );
    assert native_inference_sched == [TypeCheckPass] , (
        "implicit native inference should remain TypeCheckPass-only"
    );
}
