import gc;
import from unittest.mock { patch }
import from jaclang.compiler.pipeline.executor { compilation_resources }
import from jaclang.compiler.session.compiler { COMPILE_GC_THRESHOLDS }


test "scheduled resources restore caller GC settings after nested failure" {
    previous = gc.get_threshold();
    try {
        gc.set_threshold(700, 10, 10);
        with patch.dict("os.environ", {"JAC_GC_NO_COMPILE_BOOST": ""}) {
            try {
                with compilation_resources() {
                    assert gc.get_threshold() == COMPILE_GC_THRESHOLDS;
                    with compilation_resources() {
                        assert gc.get_threshold() == COMPILE_GC_THRESHOLDS;
                    }
                    assert gc.get_threshold() == COMPILE_GC_THRESHOLDS;
                    raise ValueError("failed pass");
                }
            } except ValueError {}
        }
        assert gc.get_threshold() == (700, 10, 10);
    } finally {
        gc.set_threshold(*previous);
    }
}


test "scheduled resources respect disabled boosting and caller tuning" {
    previous = gc.get_threshold();
    try {
        gc.set_threshold(700, 10, 10);
        with patch.dict("os.environ", {"JAC_GC_NO_COMPILE_BOOST": "1"}) {
            with compilation_resources() {
                assert gc.get_threshold() == (700, 10, 10);
            }
        }
        tuned = (COMPILE_GC_THRESHOLDS[0] * 2, 60, 110);
        gc.set_threshold(*tuned);
        with patch.dict("os.environ", {"JAC_GC_NO_COMPILE_BOOST": ""}) {
            with compilation_resources() {
                assert gc.get_threshold() == tuned;
            }
        }
        assert gc.get_threshold() == tuned;
    } finally {
        gc.set_threshold(*previous);
    }
}

test "compilation applies resource policy before catalog preparation and restores on failure" {
    import from jaclang.compiler.session.compiler { JacCompiler }
    import from jaclang.compiler.session.session { JacProgram }
    import from jaclang.compiler.session.options { CompileOptions }
    compiler = JacCompiler();
    program = JacProgram();
    program._compiler = compiler;
    observed: list[tuple[int, int, int]] = [];
    def fail_catalog {
        observed.append(gc.get_threshold());
        raise RuntimeError("catalog preparation failed");
    }
    previous = gc.get_threshold();
    try {
        gc.set_threshold(700, 10, 10);
        with patch.dict("os.environ", {"JAC_GC_NO_COMPILE_BOOST": ""}), patch.object(
            compiler, "ensure_stub_catalog", side_effect=fail_catalog
        ) {
            try {
                compiler.compile(
                    "resource_failure.jac",
                    program,
                    use_str="def value -> int { return 1; }",
                    options=CompileOptions(force_target_program=True)
                );
            } except RuntimeError as error {
                assert str(error) == "catalog preparation failed";
            }
        }
        assert observed == [COMPILE_GC_THRESHOLDS];
        assert gc.get_threshold() == (700, 10, 10);
        assert compiler._reentrant_depth == 0;
    } finally {
        gc.set_threshold(*previous);
    }
}

test "application preparation retains resource policy between compiler calls" {
    import from pathlib { Path }
    import from tempfile { TemporaryDirectory }
    import from jaclang.compiler.session.session { JacProgram }
    import jaclang.build.preparation as preparation;
    observed: list[tuple[int, int, int]] = [];
    def fail_preparation(*args: any, **kwargs: any) {
        observed.append(gc.get_threshold());
        raise RuntimeError("artifact preparation failed");
    }
    previous = gc.get_threshold();
    try {
        with TemporaryDirectory() as directory {
            entry_path = Path(directory) / "main.jac";
            entry_path.write_text("with entry { print(1); }");
            gc.set_threshold(700, 10, 10);
            with patch.dict("os.environ", {"JAC_GC_NO_COMPILE_BOOST": ""}), patch.object(
                preparation, "_prepare", side_effect=fail_preparation
            ) {
                try {
                    preparation.prepare_application(str(entry_path), JacProgram());
                } except RuntimeError as error {
                    assert str(error) == "artifact preparation failed";
                }
            }
            assert observed == [COMPILE_GC_THRESHOLDS];
            assert gc.get_threshold() == (700, 10, 10);
        }
    } finally {
        gc.set_threshold(*previous);
    }
}
