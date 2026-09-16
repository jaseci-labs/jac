"""Native comparison temporary cleanup, including chain ownership."""
import ctypes;
import os;
import from tests.support { TESTS_DIR, get_func }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }

def check_comparison_cleanup(profile: str) {
    program = JacProgram();
    module = program.compile(
        os.path.join(
            TESTS_DIR,
            "compiler",
            "backends",
            "native",
            "fixtures",
            "rc_compare_temporaries.jac"
        ),
        options=CompileOptions(
            force_codespace="native",
            force_target_program=True,
            memory_profile=profile,
            no_ir_cache=True
        )
    );
    assert not program.errors_had , [str(error) for error in program.errors_had];
    engine = module.gen.native_engine;
    assert engine is not None;
    drops = get_func(engine, "drop_count", ctypes.c_int64);
    for (name, expected, count) in [
        ("empty_is_none", True, 0),
        ("empty_is_not_none", False, 0),
        ("direct_item", True, 1),
        ("direct_list", True, 1),
        ("none_item", False, 1),
        ("reversed_item", True, 1),
        ("equal_item", False, 1),
        ("unequal_item", True, 1),
        ("named_item", True, 1),
        ("named_list", True, 1),
        ("boxed_none", True, 1),
        ("boxed_reversed", False, 1),
        ("boxed_identity", False, 2),
        ("boxed_nonidentity", True, 2),
        ("chain_true", True, 1),
        ("chain_false", False, 1),
        ("borrowed_item", True, 1)
    ] {
        call = get_func(engine, name, ctypes.c_bool);
        for _ in range(3) {
            before = drops();
            assert call() == expected , name;
            assert drops() - before == count , f"{profile}: {name}";
        }
    }
}

test "comparison operands are reclaimed under rc" {
    check_comparison_cleanup("rc");
}

test "comparison operands are reclaimed under managed" {
    check_comparison_cleanup("managed");
}
