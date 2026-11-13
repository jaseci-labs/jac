def _flow_weight(size: AxisSize) -> float;


def _flow_hard_claim(size: AxisSize) -> float;


def _flow_soft_claim(size: AxisSize, natural: float | None) -> float;


def _allocate_span(children: list[_FlowChild], span: float) -> _Allocation;


def _emit_partition(
    result: CompileResult,
    owner: _Entry,
    entries_by_id: dict[str, _Entry],
    natural_sizes: dict[str, Size],
    span_w: float,
    span_h: float,
    phase: str,
) -> bool;


def _ordered_flow_children(
    owner: _Entry, entries_by_id: dict[str, _Entry],
) -> list[_Entry];
