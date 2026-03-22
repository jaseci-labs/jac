"""Jac benchmark: graph construction + traversal."""

import time;

node PersonNode {
    has name: str = "",
        age: int = 0;
}

node TaskNode {
    has title: str = "",
        priority: int = 0;
}

edge KnowsEdge {
    has weight: float = 1.0;
}

edge WorksOnEdge {
    has role: str = "";
}

walker BenchAll {
    can go with Root entry {
        start = time.perf_counter();
        neighbors = [-->];
        ms = (time.perf_counter() - start) * 1000;
        print(f"  -->              : {len(neighbors)} results, {round(ms, 3)} ms");
    }
}

walker BenchNodeFilter {
    can go with Root entry {
        start = time.perf_counter();
        persons = [-->](?:PersonNode);
        ms = (time.perf_counter() - start) * 1000;
        print(f"  -->(?:PersonNode): {len(persons)} results, {round(ms, 3)} ms");
    }
}

walker BenchEdgeFilter {
    can go with Root entry {
        visit [-->](?:PersonNode);
    }
    can bench with PersonNode entry {
        start = time.perf_counter();
        via_knows = [->:KnowsEdge:->];
        ms = (time.perf_counter() - start) * 1000;
        print(f"  ->:KnowsEdge:->  : {len(via_knows)} results, {round(ms, 3)} ms");
        disengage;
    }
}

walker BenchFullFilter {
    can go with Root entry {
        visit [-->](?:PersonNode);
    }
    can bench with PersonNode entry {
        start = time.perf_counter();
        result = [->:KnowsEdge:->](?:PersonNode);
        ms = (time.perf_counter() - start) * 1000;
        print(f"  ->:Knows->(?:Per): {len(result)} results, {round(ms, 3)} ms");
        disengage;
    }
}

with entry {
    import os;
    print("Jac Graph Benchmark — actual .jac traversal operators");
    print(f"Backend: {os.getenv('BENCH_BACKEND', 'sqlite')}");

    for (label, num_nodes, epn) in [("Small", 100, 10), ("Medium", 500, 10)] {
        print(f"\n{'='*60}");
        print(f"  {label}: {num_nodes} nodes, {num_nodes * epn} edges");
        print(f"{'='*60}");

        nodes: list = [];
        start = time.perf_counter();
        for i in range(num_nodes) {
            if i % 2 == 0 {
                n = root ++> PersonNode(name=f"P{i}", age=20+i%50);
            } else {
                n = root ++> TaskNode(title=f"T{i}", priority=i%5);
            }
            nodes.append(n[0]);
        }
        create_ms = (time.perf_counter() - start) * 1000;

        start = time.perf_counter();
        ec = 0;
        for i in range(len(nodes)) {
            for j in range(epn) {
                ti = (i + j + 1) % len(nodes);
                if i % 2 == 0 {
                    nodes[i] +>:KnowsEdge(weight=float(j)/10):+> nodes[ti];
                } else {
                    nodes[i] +>:WorksOnEdge(role="dev"):+> nodes[ti];
                }
                ec += 1;
            }
        }
        connect_ms = (time.perf_counter() - start) * 1000;
        print(f"  Build: {round(create_ms+connect_ms, 1)} ms ({num_nodes} nodes, {ec} edges)");

        print(f"\n  Traversals (5 runs each):");
        for i in range(5) {
            root spawn BenchAll();
        }
        for i in range(5) {
            root spawn BenchNodeFilter();
        }
        for i in range(5) {
            root spawn BenchEdgeFilter();
        }
        for i in range(5) {
            root spawn BenchFullFilter();
        }
    }
}
