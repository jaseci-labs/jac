"""Root consumer in the A->B->C transitive import chain.

sv-imports from level_b only. level_b transitively sv-imports level_c.
The eager-spawn BFS on level_a's JacAPIServer startup should walk the
chain and ensure all three services are registered before serving.
"""

sv import from level_b { level_b_forward }

def:pub level_a_start(msg: str) -> str {
    return f"level_a -> {level_b_forward(msg)}";
}
