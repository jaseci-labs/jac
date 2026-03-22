"""
Cold-start MongoDB benchmark.

Simulates production: build graph, then do cold traversals where L1 is
empty (fresh request). This is where N+1 vs batch_get matters.

Uses jaclang's actual Anchor/Memory classes through jac-scale's MongoBackend.
"""

import os
import sys
import time
from dataclasses import dataclass
from uuid import UUID, uuid4

MONGO_URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017")

print(f"Python: {sys.version}")
print(f"MongoDB: {MONGO_URI}")

from jaclang.jac0core.archetype import (
    EdgeAnchor, EdgeArchetype, NodeAnchor, NodeArchetype, Root,
)

# Check if batch_get is available (v2)
HAS_BATCH = False

print("Imports OK")


@dataclass
class PersonNode(NodeArchetype):
    name: str = ""

@dataclass
class TaskNode(NodeArchetype):
    title: str = ""

@dataclass
class KnowsEdge(EdgeArchetype):
    weight: float = 1.0

@dataclass
class WorksOnEdge(EdgeArchetype):
    role: str = ""


def make_node(arch):
    na = NodeAnchor(archetype=arch, edges=[])
    na.persistent = True
    arch.__jac__ = na
    return na

def make_edge(src, tgt, arch):
    ea = EdgeAnchor(archetype=arch, source=src, target=tgt, is_undirected=False)
    ea.persistent = True
    arch.__jac__ = ea
    src.edges.append(ea)
    return ea


def run_benchmark(label, num_nodes, edges_per_node):
    from pymongo import MongoClient

    print(f"\n{'='*60}")
    print(f"  {label}: {num_nodes} nodes, {num_nodes * edges_per_node} edges")
    print(f"{'='*60}")

    # Clean slate
    client = MongoClient(MONGO_URI)
    client.drop_database("bench_cold")

    # Import and create ScaleTieredMemory
    from jac_scale.memory_hierarchy import ScaleTieredMemory, MongoBackend

    # Create MongoBackend directly
    backend = MongoBackend(
        mongo_url=MONGO_URI,
        db_name="bench_cold",
        collection_name="_anchors",
    )

    # Build graph and persist to MongoDB
    print(f"\n--- Building graph ---")
    nodes = []
    edges = []
    root_node = make_node(Root())

    for i in range(num_nodes):
        if i % 2 == 0:
            n = make_node(PersonNode(name=f"P{i}"))
        else:
            n = make_node(TaskNode(title=f"T{i}"))
        nodes.append(n)
        # Connect to root
        e = make_edge(root_node, n, KnowsEdge(weight=float(i)/10) if i % 2 == 0 else WorksOnEdge(role="dev"))
        edges.append(e)

    # Cross-connect nodes
    for i in range(len(nodes)):
        for j in range(edges_per_node - 1):  # -1 because root edge already counted
            tgt_idx = (i + j + 1) % len(nodes)
            e = make_edge(nodes[i], nodes[tgt_idx], KnowsEdge(weight=0.5))
            edges.append(e)

    start = time.perf_counter()
    backend.put(root_node)
    for n in nodes:
        backend.put(n)
    for e in edges:
        backend.put(e)
    build_ms = (time.perf_counter() - start) * 1000
    total = 1 + num_nodes + len(edges)
    print(f"  Persisted {total} anchors in {build_ms:.0f} ms")

    root_id = root_node.id
    root_edge_count = len(root_node.edges)
    root_edge_ids = [e.id for e in root_node.edges]
    root_target_ids = [e.target.id for e in root_node.edges]

    # Check if batch_get exists
    has_batch = hasattr(backend, 'batch_get')
    version = "v2 (batch_get)" if has_batch else "v1 (N+1)"
    print(f"  Version: {version}")
    print(f"  Root has {root_edge_count} edges")

    # === COLD TRAVERSAL: N+1 pattern (always works) ===
    print(f"\n--- Cold Traversal: N+1 (individual find_one per edge) ---")
    iterations = 5
    col = client["bench_cold"]["_anchors"]
    times = []
    for _ in range(iterations):
        start = time.perf_counter()
        # Load root
        col.find_one({"_id": str(root_id)})
        # Load each edge individually
        for eid in root_edge_ids:
            col.find_one({"_id": str(eid)})
        # Load each target individually
        for tid in root_target_ids:
            col.find_one({"_id": str(tid)})
        elapsed = (time.perf_counter() - start) * 1000
        times.append(elapsed)
    queries = 1 + len(root_edge_ids) + len(root_target_ids)
    avg = sum(times) / len(times)
    print(f"  Queries: {queries} (1 root + {len(root_edge_ids)} edges + {len(root_target_ids)} targets)")
    print(f"  Avg: {avg:.1f} ms")

    # === COLD TRAVERSAL: batch_get pattern (v2 only) ===
    if has_batch:
        print(f"\n--- Cold Traversal: batch_get ($in query) ---")
        times = []
        for _ in range(iterations):
            start = time.perf_counter()
            # Load root
            col.find_one({"_id": str(root_id)})
            # Batch load all edges in one query
            edge_docs = list(col.find({"_id": {"$in": [str(eid) for eid in root_edge_ids]}}))
            # Batch load all targets in one query
            target_docs = list(col.find({"_id": {"$in": [str(tid) for tid in root_target_ids]}}))
            elapsed = (time.perf_counter() - start) * 1000
            times.append(elapsed)
        avg_batch = sum(times) / len(times)
        print(f"  Queries: 3 (1 root + 1 batch edges + 1 batch targets)")
        print(f"  Avg: {avg_batch:.1f} ms")
        print(f"  Speedup: {avg/avg_batch:.1f}x vs N+1")
    else:
        print(f"\n--- Cold Traversal: batch_get not available (v1) ---")
        # Simulate what batch_get WOULD do
        print(f"\n--- Simulated batch_get ($in query) for comparison ---")
        times = []
        for _ in range(iterations):
            start = time.perf_counter()
            col.find_one({"_id": str(root_id)})
            edge_docs = list(col.find({"_id": {"$in": [str(eid) for eid in root_edge_ids]}}))
            target_docs = list(col.find({"_id": {"$in": [str(tid) for tid in root_target_ids]}}))
            elapsed = (time.perf_counter() - start) * 1000
            times.append(elapsed)
        avg_batch = sum(times) / len(times)
        print(f"  Queries: 3 (1 root + 1 batch edges + 1 batch targets)")
        print(f"  Avg: {avg_batch:.1f} ms")
        print(f"  Speedup: {avg/avg_batch:.1f}x vs N+1")

    # === COLD TRAVERSAL via batch_get API (v2 only) ===
    if has_batch:
        print(f"\n--- Cold Traversal: via MongoBackend.batch_get() API ---")
        times = []
        for _ in range(iterations):
            start = time.perf_counter()
            backend.get(root_id)
            edge_anchors = backend.batch_get(root_edge_ids)
            target_anchors = backend.batch_get(root_target_ids)
            elapsed = (time.perf_counter() - start) * 1000
            times.append(elapsed)
        avg_api = sum(times) / len(times)
        print(f"  Queries: 3 via batch_get API")
        print(f"  Avg: {avg_api:.1f} ms")
        print(f"  Loaded: {len(edge_anchors)} edges, {len(target_anchors)} targets")
        print(f"  Speedup: {avg/avg_api:.1f}x vs N+1")

    backend.close()
    client.close()


if __name__ == "__main__":
    from pymongo import MongoClient
    try:
        c = MongoClient(MONGO_URI, serverSelectionTimeoutMS=3000)
        c.admin.command("ping")
        c.close()
        print("MongoDB: OK\n")
    except Exception as e:
        print(f"MongoDB FAILED: {e}")
        sys.exit(1)

    print("Cold-Start MongoDB Benchmark")
    print("Simulates production: empty L1, all reads from MongoDB\n")

    run_benchmark("Small", 100, 10)
    run_benchmark("Medium", 500, 20)
