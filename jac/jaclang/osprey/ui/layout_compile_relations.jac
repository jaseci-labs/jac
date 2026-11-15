def _emit_relation(
    result: CompileResult,
    rid: int,
    rel: LayoutRelation,
    edges_by_id: dict[str, NodeEdges],
    phase: str = "full",
) -> bool;
