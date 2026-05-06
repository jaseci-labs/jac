"""Middle service in the A->B->C transitive import chain.

sv-imports from level_c, so its import-time stubs register level_c
as a provider of level_b in sv_client._consumer_providers. The root
consumer (level_a) doesn't directly import level_c; it should pick
it up via the BFS in JacAPIServer._ensure_sv_siblings.
"""

sv import from level_c { level_c_ping }

def:pub level_b_forward(msg: str) -> str {
    return f"level_b -> {level_c_ping(msg)}";
}
