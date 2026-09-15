import from unittest.mock { patch }
import jaclang.compiler.driver.progstate as state;

test "exclusive timings subtract nested work across compiler programs" {
    parent = state.AnalysisCaches();
    dependency = state.AnalysisCaches();
    with patch.object(state.time, "perf_counter", side_effect=[0.0, 2.0, 5.0, 10.0]) {
        with parent.measure("root.jac", "phase:analysis") {
            with dependency.measure("shared.jac", "pass:TypeCheckPass") {}
        }
    }
    outer = parent.timings["root.jac"]["phase:analysis"];
    inner = dependency.timings["shared.jac"]["pass:TypeCheckPass"];
    assert outer.wall_seconds == 10.0;
    assert outer.exclusive_seconds == 7.0;
    assert inner.exclusive_seconds == 3.0;
    assert outer.runs == 1;
    snapshot = parent.measurements();
    parent.reset_measurements();
    assert not parent.timings;
    assert snapshot["timings"]["root.jac"]["phase:analysis"]["runs"] == 1;
}
