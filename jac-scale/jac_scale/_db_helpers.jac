"""Shared read-only-collection guards used by MongoDb and RedisDb impls."""

def _is_read_only_collection(col_name: str) -> bool {
    return col_name == '_anchors';
}

def _validate_not_read_only(col_name: str) {
    if _is_read_only_collection(col_name) {
        raise PermissionError(
            f"Collection '{col_name}' is read-only and cannot be modified. "
            "This is a system collection managed internally."
        );
    }
}
