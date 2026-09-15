"""The same construction algebra and connect results on all three backends."""

node FragmentItem {
    has value: int;
}

edge FragmentLink {
    has weight: int = 0;
}

def fragment_py -> dict[str, any] {
    a = FragmentItem(1);
    b = FragmentItem(2);
    c = FragmentItem(3);
    d = FragmentItem(4);
    f = graph { a ++> [b, c] +>:FragmentLink(weight=9):+> d; };
    nested = graph {
        FragmentItem(5) ++> [graph { FragmentItem(6) ++> FragmentItem(7); }];
    };
    computed = graph {
        FragmentItem(8) ++> [FragmentItem(i) ++> FragmentItem(i + 10) for i in [9, 10]];
    };
    branch = graph {
        FragmentItem(11) ++> (
            FragmentItem(12) ++> FragmentItem(13) if a.value == 1 else FragmentItem(14)
        );
    };
    projected = (graph { FragmentItem(99) ++> FragmentItem(100); }).root;
    total_weight = 0;
    for captured in f.edges {
        if isinstance(captured, FragmentLink) {
            total_weight += captured.weight;
        }
    }
    captured_edge = f.edges[0];
    del captured_edge;
    return {
        "root": f.root.value,
        "nodes": len(f.nodes),
        "edges": len(f.edges),
        "weight": total_weight,
        "tips": len(f.tips),
        "a_degree": len([a-->]),
        "b_degree": len([b->:FragmentLink:->]),
        "c_degree": len([c->:FragmentLink:->]),
        "nested_nodes": len(nested.nodes),
        "nested_edges": len(nested.edges),
        "computed_nodes": len(computed.nodes),
        "computed_edges": len(computed.edges),
        "branch_nodes": len(branch.nodes),
        "branch_edges": len(branch.edges),
        "projected_value": projected.value,
        "projected_degree": len([projected-->])
    };
}

def fragment_cl -> dict[str, any] {
    a = FragmentItem(1);
    b = FragmentItem(2);
    c = FragmentItem(3);
    d = FragmentItem(4);
    f = graph { a ++> [b, c] +>:FragmentLink(weight=9):+> d; };
    nested = graph {
        FragmentItem(5) ++> [graph { FragmentItem(6) ++> FragmentItem(7); }];
    };
    computed = graph {
        FragmentItem(8) ++> [FragmentItem(i) ++> FragmentItem(i + 10) for i in [9, 10]];
    };
    branch = graph {
        FragmentItem(11) ++> (
            FragmentItem(12) ++> FragmentItem(13) if a.value == 1 else FragmentItem(14)
        );
    };
    projected = (graph { FragmentItem(99) ++> FragmentItem(100); }).root;
    total_weight = 0;
    for captured in f.edges {
        if isinstance(captured, FragmentLink) {
            total_weight += captured.weight;
        }
    }
    captured_edge = f.edges[0];
    del captured_edge;
    return {
        "root": f.root.value,
        "nodes": len(f.nodes),
        "edges": len(f.edges),
        "weight": total_weight,
        "tips": len(f.tips),
        "a_degree": len([a-->]),
        "b_degree": len([b->:FragmentLink:->]),
        "c_degree": len([c->:FragmentLink:->]),
        "nested_nodes": len(nested.nodes),
        "nested_edges": len(nested.edges),
        "computed_nodes": len(computed.nodes),
        "computed_edges": len(computed.edges),
        "branch_nodes": len(branch.nodes),
        "branch_edges": len(branch.edges),
        "projected_value": projected.value,
        "projected_degree": len([projected-->])
    };
}

def fragment_na -> dict[str, any] {
    a = FragmentItem(1);
    b = FragmentItem(2);
    c = FragmentItem(3);
    d = FragmentItem(4);
    f = graph { a ++> [b, c] +>:FragmentLink(weight=9):+> d; };
    nested = graph {
        FragmentItem(5) ++> [graph { FragmentItem(6) ++> FragmentItem(7); }];
    };
    computed = graph {
        FragmentItem(8) ++> [FragmentItem(i) ++> FragmentItem(i + 10) for i in [9, 10]];
    };
    branch = graph {
        FragmentItem(11) ++> (
            FragmentItem(12) ++> FragmentItem(13) if a.value == 1 else FragmentItem(14)
        );
    };
    projected = (graph { FragmentItem(99) ++> FragmentItem(100); }).root;
    total_weight = 0;
    for captured in f.edges {
        if isinstance(captured, FragmentLink) {
            total_weight += captured.weight;
        }
    }
    captured_edge = f.edges[0];
    del captured_edge;
    return {
        "root": f.root.value,
        "nodes": len(f.nodes),
        "edges": len(f.edges),
        "weight": total_weight,
        "tips": len(f.tips),
        "a_degree": len([a-->]),
        "b_degree": len([b->:FragmentLink:->]),
        "c_degree": len([c->:FragmentLink:->]),
        "nested_nodes": len(nested.nodes),
        "nested_edges": len(nested.edges),
        "computed_nodes": len(computed.nodes),
        "computed_edges": len(computed.edges),
        "branch_nodes": len(branch.nodes),
        "branch_edges": len(branch.edges),
        "projected_value": projected.value,
        "projected_degree": len([projected-->])
    };
}
