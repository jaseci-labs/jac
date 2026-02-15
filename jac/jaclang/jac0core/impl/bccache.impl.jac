"""Implementation for bccache constructs."""

"""Create a cache key for the current Python version."""
@ classmethod
impl CacheKey.for_source(cls: Any, source_path: str) -> CacheKey {
    return cls(
        source_path=source_path,
        python_version=(sys.version_info.major, sys.version_info.minor)
    );
}
