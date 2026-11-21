"""Root consumer in the A->B->C transitive import chain.

sv-imports from level_b only. level_b transitively sv-imports level_c.
The eager-spawn BFS on level_a's JacAPIServer startup should walk the
chain and ensure all three services are registered before serving.
"""

import from level_b { level_b_forward }

async def:pub level_a_start(msg: str) -> str {
    forwarded = await level_b_forward(msg);
    return f"level_a -> {forwarded}";
}
