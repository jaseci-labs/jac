test "Gate 1 detached lifecycle passes" {
    assert run_gate1_detached_lifecycle() == True;
}


test "Gate 3 layout and damage harness passes" {
    assert run_gate3_layout_damage() == True;
}


test "Gate 4 invalidation bench reports required counters" {
    metrics: Gate4Report = run_gate4_invalidation_bench();
    assert metrics.nodes_queried >= 0;
    assert metrics.cells_written >= 0;
    assert metrics.latency_ms >= 0.0;
    if metrics.full_frame_cells > 0 {
        assert metrics.retained_cells <= metrics.full_frame_cells;
    }
}


test "Gate 5 external ProgressBar package works without framework edits" {
    assert run_gate5_external_widget() == True;
}


test "Gate 6 authoring scale lowers large markup without manual ranks" {
    assert run_gate6_authoring_scale() == True;
}
