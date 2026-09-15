"""Deepest service in the A->B->C transitive import chain.

Provides a single public function. Has no sv imports of its own.
Used by the eager-spawn BFS test to verify the root consumer picks up
transitive providers beyond its direct dependencies.
"""

def:pub level_c_ping(msg: str) -> str {
    return f"level_c received: {msg}";
}
