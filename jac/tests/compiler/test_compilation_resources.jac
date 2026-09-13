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
