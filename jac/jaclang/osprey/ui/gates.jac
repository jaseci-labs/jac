import from time { perf_counter }


obj Gate4Report {
    has nodes_queried: int = 0,
        cells_written: int = 0,
        latency_ms: float = 0.0,
        full_frame_cells: int = 0,
        retained_cells: int = 0;
}


def run_gate1_detached_lifecycle -> bool;


def run_gate3_layout_damage -> bool;


def run_gate4_invalidation_bench -> Gate4Report;


def run_gate5_external_widget -> bool;


def run_gate6_authoring_scale -> bool;
