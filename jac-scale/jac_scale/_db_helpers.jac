"""Shared read-only-collection guard used by MongoDb and RedisDb impls."""

def _validate_not_read_only(col_name: str) {
    if col_name == '_anchors' {
        raise PermissionError(
            f"Collection '{col_name}' is read-only and cannot be modified. "
            "This is a system collection managed internally."
        );
    }
}
