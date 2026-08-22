"""Construction-time schedule validation against declared pass dependencies.

Every pass schedule is validated (or derived) from the passes' declared
REQUIRES/PROVIDES at construction time (#7871 workstream H): a schedule that
omits a declared dependency fails fast with the pass and the missing analysis
named, never mid-compile on user code. `resolve_schedule` derives providers
from declarations, and `get_type_check_sched` drops analyses whose declared
inputs have no available provider in the current environment instead of
scheduling a pass that cannot run.
"""

import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.compiler {
    get_inference_sched,
    get_type_check_sched,
    providers_for,
    resolve_schedule,
    validate_schedule
}
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.main.cfg_build_pass { CFGBuildPass }
import from jaclang.compiler.passes.main.ownership_check_pass { OwnershipCheckPass }
import from jaclang.compiler.passes.main.static_analysis_pass { StaticAnalysisPass }
import from jaclang.compiler.passes.main.type_checker_pass { TypeInferencePass }


test "schedule omitting a declared dependency fails fast at construction" {
    err = '';
    try {
        validate_schedule([OwnershipCheckPass], origin='test schedule');
    } except RuntimeError as e {
        err = str(e);
    }
    assert 'OwnershipCheckPass' in err;
    assert "'cfg'" in err;
    assert 'scheduling error' in err;
}

test "validation names the first missing analysis with cfg preprovided" {
    err = '';
    try {
        validate_schedule(
            [OwnershipCheckPass], preprovided={'cfg'}, origin='test schedule'
        );
    } except RuntimeError as e {
        err = str(e);
    }
    assert 'OwnershipCheckPass' in err;
    assert "'inference'" in err;
}

test "validation accepts a schedule whose dependencies are preprovided" {
    sched = validate_schedule(
        [OwnershipCheckPass], preprovided={'cfg', 'inference'}, origin='test schedule'
    );
    assert sched == [OwnershipCheckPass];
}

test "validation accepts a schedule whose dependencies run earlier in it" {
    sched = validate_schedule(
        [CFGBuildPass, TypeInferencePass, OwnershipCheckPass], origin='test schedule'
    );
    assert len(sched) == 3;
}

test "resolve_schedule inserts declared providers before the dependent pass" {
    sched = resolve_schedule(
        [OwnershipCheckPass],
        providers=providers_for([CFGBuildPass, TypeInferencePass]),
        origin='test schedule'
    );
    assert OwnershipCheckPass in sched;
    assert sched.index(CFGBuildPass) < sched.index(OwnershipCheckPass);
    assert sched.index(TypeInferencePass) < sched.index(OwnershipCheckPass);
}

test "resolve_schedule drops passes whose dependencies have no provider" {
    sched = resolve_schedule(
        [StaticAnalysisPass, OwnershipCheckPass],
        providers={},
        drop_unsatisfiable=True,
        origin='test schedule'
    );
    assert sched == [StaticAnalysisPass];
}

test "resolve_schedule raises when a dependency has no provider" {
    err = '';
    try {
        resolve_schedule([OwnershipCheckPass], providers={}, origin='test schedule');
    } except RuntimeError as e {
        err = str(e);
    }
    assert 'OwnershipCheckPass' in err;
    assert "'cfg'" in err;
}

test "type-check schedule construction satisfies ownership dependencies" {
    sched = get_type_check_sched();
    assert StaticAnalysisPass in sched;
    if OwnershipCheckPass in sched {
        assert get_inference_sched() != [];
        assert CFGBuildPass in sched;
        assert TypeInferencePass in sched;
        assert sched.index(CFGBuildPass) < sched.index(OwnershipCheckPass);
        assert sched.index(TypeInferencePass) < sched.index(OwnershipCheckPass);
    }
    validate_schedule(sched, origin='type-check schedule');
}

test "type-check schedule trusts analyses the module already ran" {
    sched = get_type_check_sched(provided={'cfg', 'inference'});
    assert OwnershipCheckPass in sched;
    assert CFGBuildPass not in sched;
    assert TypeInferencePass not in sched;
}

test "run_schedule rejects an incoherent schedule before running any pass" {
    prog = JacProgram();
    stub = uni.Module.make_stub(inject_name='sched_stub');
    err = '';
    try {
        prog.run_schedule(stub, [OwnershipCheckPass]);
    } except RuntimeError as e {
        err = str(e);
    }
    assert 'OwnershipCheckPass' in err;
    assert "'cfg'" in err;
    assert 'scheduling error' in err;
}
