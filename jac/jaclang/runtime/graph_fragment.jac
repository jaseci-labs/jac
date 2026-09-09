obj:pub GraphFragment[T: Node] {
    has roots: list[T],
        tips: list[Node],
        nodes: list[Node],
        edges: list[Edge];

    has `root: T { getter; }
}

impl GraphFragment.`root.getter -> T {
    if len(self.roots) != 1 {
        raise ValueError("fragment.root requires exactly one root");
    }
    return self.roots[0];
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
    ) -> GraphPorts[T] {
        if isinstance(value, list) {
            return self.parallel([self.add(item) for item in value]);
        }
        if isinstance(value, GraphFragment) {
            if self.capture {
                for item in value.nodes {
                    self._add_node(item);
                }
                for item in value.edges {
                    self.record_edge(item);
                }
            }
            return GraphPorts(roots=list(value.roots), tips=list(value.tips));
        }
        self._add_node(value);
        return GraphPorts(roots=[value], tips=[value]);
    }

    def _add_node(value: Node) -> None {
        if not self.capture {
            return;
        }
        key = id(value);
        if key not in self._node_ids {
            self._node_ids.add(key);
            self._nodes.append(value);
        }
    }

    def record_edges(values: list[Edge]) {
        for value in values {
            self.record_edge(value);
        }
    }

    def record_edge(value: Edge) -> None {
        if not self.capture {
            return;
        }
        key = id(value);
        if key not in self._edge_ids {
            self._edge_ids.add(key);
            self._edges.append(value);
        }
    }

    def parallel[T: Node](parts: list[GraphPorts[T]]) -> GraphPorts[T] {
        roots: list[T] = [];
        tips: list[Node] = [];
        root_ids: set[int] = set();
        tip_ids: set[int] = set();
        for part in parts {
            for item in part.roots {
                key = id(item);
                if key not in root_ids {
                    root_ids.add(key);
                    roots.append(item);
                }
            }
            for item in part.tips {
                key = id(item);
                if key not in tip_ids {
                    tip_ids.add(key);
                    tips.append(item);
                }
            }
        }
        return GraphPorts(roots=roots, tips=tips);
    }

    def finish[T: Node](ports: GraphPorts[T]) -> GraphFragment[T] {
        return GraphFragment(
            roots=list(ports.roots),
            tips=list(ports.tips),
            nodes=list(self._nodes),
            edges=list(self._edges)
        );
    }
}
