"""Heap-element containers must compile under every gc mode (issue #7466
bug 3). Emitting the container's element-release helper re-entered
_emit_rc_helpers under --memory rc / plain --memory nogc because the re-entry guard
checked a cycles-only global, so the RC debug globals were defined twice
(DuplicatedNameError: __rc_debug)."""

def count_strs -> int {
    xs: list[str] = [];
    xs.append("alpha");
    xs.append("beta");
    return len(xs);
}
