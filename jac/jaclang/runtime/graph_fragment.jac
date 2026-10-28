obj:pub GraphFragment[T: Node] {
    has roots: list[T],
        tips: list[Node],
        nodes: list[Node],
        edges: list[Edge];

    has `root: T { getter; }
}

obj:pub GraphPorts[T: Node] {
    has roots: list[T] = [],
        tips: list[Node] = [];
}

obj:pub GraphBuilder {
    has capture: bool = True,
        _nodes: list[Node] = [],
        _edges: list[Edge] = [],
        _node_ids: set[int] = set(),
        _edge_ids: set[int] = set();

    def add[T: Node](
        value: T | GraphFragment[T] | list[T | GraphFragment[T]]
    ) -> GraphPorts[T];

    def _add_node(value: Node) -> None;
    def record_edges(values: list[Edge]);
    def record_edge(value: Edge) -> None;
    def parallel[T: Node](parts: list[GraphPorts[T]]) -> GraphPorts[T];
    def finish[T: Node](ports: GraphPorts[T]) -> GraphFragment[T];
}
