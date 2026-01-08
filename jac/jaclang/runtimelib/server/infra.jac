"""Infrastructure module for data storage backends."""
import from typing { Any }

"""Base interface for data storage  instances."""
obj DataStore {
    """Initialize the data store."""
    def init(config: dict[str, Any]) -> None abs;

    """Get data by key."""
    def get(key: str) -> (Any | None) abs;

    """Set data by key."""
    def set(key: str, value: Any) -> None abs;

    """Delete data by key."""
    def delete(key: str) -> None abs;

    """Check if key exists."""
    def exists(key: str) -> bool abs;

    """Get all keys matching a pattern (optional)."""
    def keys(pattern: (str | None) = None) -> list[str] abs;

    """Flush all data."""
    def flush -> None abs;

    """Close the store and release resources."""
    def close -> None abs;
}

"""File-based storage using JSON.

This is used for persistent storage in local development.
In scale, this will be replaced by MongoDB instance for distributed persistent storage.
"""
obj FileStore(DataStore) {
    has _file_path: str = "",
        _data: dict[str, Any] = {};

    def init(config: dict[str, Any]) -> None;
    def get(key: str) -> (Any | None);
    def set(key: str, value: Any) -> None;
    def delete(key: str) -> None;
    def exists(key: str) -> bool;
    def keys(pattern: (str | None) = None) -> list[str];
    def flush -> None;
    def close -> None;
    def _load -> None;
    def _save -> None;
}

"""Redis-based storage (cache).

In scale, this will be used for distributed caching.
Implementation will be provided in jac-scale.
"""
obj RedisStore(DataStore) {
# Implementation will be provided in jac-scale
}

"""MongoDB-based storage (persistent).

In scale, this will replace FileStore for distributed persistent storage.
Implementation will be provided in jac-scale.
"""
obj MongoStore(DataStore) {
# Implementation will be provided in jac-scale
}

"""Infrastructure factory for getting storage instances."""
obj Infra {
    static def get_cache_memory(
        config: (dict[str, Any] | None) = None
    ) -> (DataStore | None);
    static def get_persistent_memory(
        config: (dict[str, Any] | None) = None
    ) -> (DataStore | None);
    static def _get_default_config -> dict[str, Any];
}
