# Infrastructure and Memory Hierarchy Integration

## Overview

This document describes the integration of the Infrastructure abstraction layer (`Infra`) with the memory hierarchy system. The integration enables seamless scaling from local file-based storage to distributed databases (MongoDB) and caches (Redis) without code changes in the memory layer.

**Key Achievement**: The memory hierarchy now uses `DataStore` from the `Infra` module for all persistent storage operations, enabling plug-and-play infrastructure components.

## Architecture

The memory hierarchy consists of three tiers:

- **L1 (VolatileMemory)**: In-memory storage, no persistence
- **L2 (LocalCacheMemory)**: In-process cache (can be replaced with Redis via `Infra.get_cache_memory()`)
- **L3 (ShelfMemory)**: Persistent storage using `DataStore` from `Infra.get_persistent_memory()`

### Integration Flow

```
TieredMemory
    ├── L1: VolatileMemory (in-memory, no Infra)
    ├── L2: LocalCacheMemory or Infra.get_cache_memory() → RedisStore (at scale)
    └── L3: ShelfMemory
            └── Infra.get_persistent_memory() → DataStore
                ├── FileStore (local dev)
                └── MongoStore (production scale, via jac-scale)
```

## Implementation Details

### DataStore Interface

The `DataStore` interface is defined in [`jac/jaclang/runtimelib/server/infra.jac`](../../jac/jaclang/runtimelib/server/infra.jac):

```jac
obj DataStore {
    def init(config: dict[str, Any]) -> None abs;
    def get(key: str) -> (Any | None) abs;
    def set(key: str, value: Any) -> None abs;
    def delete(key: str) -> None abs;
    def exists(key: str) -> bool abs;
    def keys(pattern: (str | None) = None) -> list[str] abs;
    def flush -> None abs;
    def close -> None abs;
}
```

### ShelfMemory Integration

`ShelfMemory` (the L3 persistent tier) was refactored to use `DataStore` from Infra instead of Python's `shelve` module.

#### Before (using shelve)

```jac
obj ShelfMemory(PersistentMemory) {
    has __shelf__: (shelve.Shelf | None) = None;

    def init(path: str) -> None {
        self.__shelf__ = shelve.open(path);
    }
}
```

#### After (using DataStore from Infra)

```jac
obj ShelfMemory(PersistentMemory) {
    has __store__: (DataStore | None) = None;

    def init(path: str) -> None {
        import from jaclang.runtimelib.server.infra { Infra }
        config = {'file_path': path};
        self.__store__ = Infra.get_persistent_memory(config=config);
    }
}
```

### Operation Mapping

All shelve operations were replaced with `DataStore` operations:

| Old (shelve) | New (DataStore) |
|--------------|----------------|
| `shelve.open(path)` | `Infra.get_persistent_memory(config={'file_path': path})` |
| `self.__shelf__.get(str(id))` | `self.__store__.get(str(id))` |
| `self.__shelf__[key] = value` | `self.__store__.set(key, value)` |
| `self.__shelf__.pop(key, None)` | `self.__store__.delete(key)` |
| `key in self.__shelf__` | `self.__store__.exists(key)` |
| `self.__shelf__.keys()` | `self.__store__.keys()` |
| `self.__shelf__.close()` | `self.__store__.close()` |

### Graph Data Storage

Graph anchors (nodes and edges) are stored as key-value pairs where:

- **Key**: UUID string (e.g., `"550e8400-e29b-41d4-a716-446655440000"`)
- **Value**: Anchor object (serialized via pickle for FileStore, or native format for MongoDB)

The `sync()` method in `ShelfMemory` handles access control and edge updates before persisting to `DataStore`:

```jac
impl ShelfMemory.sync -> None {
    import from jaclang { JacRuntimeInterface as Jac }
    if not self.__store__ {
        return;
    }
    # Handle garbage collected anchors (deletions)
    for anchor in self.__gc__ {
        self.__store__.delete(str(anchor.id));
    }
    self.__gc__.clear();
    # Sync memory to DataStore with access control
    for (id, anchor) in list(self.__mem__.items()) {
        if not anchor.persistent {
            continue;
        }
        key = str(id);
        stored = self.__store__.get(key);
        # ... access control checks and updates ...
        self.__store__.set(key, stored);
    }
}
```

## File Locations

### Core Files

- **Infra Module**: [`jac/jaclang/runtimelib/server/infra.jac`](../../jac/jaclang/runtimelib/server/infra.jac)
  - Defines `DataStore` interface
  - Defines `FileStore` implementation (local dev)
  - Defines `Infra` factory with `get_persistent_memory()` method

- **Infra Implementation**: [`jac/jaclang/runtimelib/server/impl/infra.impl.jac`](../../jac/jaclang/runtimelib/server/impl/infra.impl.jac)
  - Implements `FileStore` methods
  - Implements `Infra.get_persistent_memory()` factory method

- **Memory Hierarchy**: [`jac/jaclang/runtimelib/memory.jac`](../../jac/jaclang/runtimelib/memory.jac)
  - Defines `ShelfMemory` with `DataStore` type
  - Imports `DataStore` from `jaclang.runtimelib.server.infra`

- **Memory Implementation**: [`jac/jaclang/runtimelib/impl/memory.impl.jac`](../../jac/jaclang/runtimelib/impl/memory.impl.jac)
  - Implements `ShelfMemory.init()` to get `DataStore` from Infra
  - Implements all `ShelfMemory` methods using `DataStore` operations

## Design Decisions

### 1. Direct DataStore Usage

**Decision**: `ShelfMemory` uses `DataStore` directly instead of introducing wrapper abstractions.

**Rationale**: Graph persistence is just persistent memory. No need for separate `GraphDataStore` interface. The existing `DataStore` interface (key-value operations) is sufficient for storing anchors (UUID → Anchor).

### 2. Type Safety

**Decision**: Use proper type `DataStore` instead of `Any` or string forward references.

**Implementation**:

```jac
import from jaclang.runtimelib.server.infra { DataStore }

obj ShelfMemory(PersistentMemory) {
    has __store__: (DataStore | None) = None;
}
```

### 3. Composition Over Inheritance

**Decision**: Memory hierarchy composes with Infra components rather than inheriting from them.

**Rationale**: Each tier gets its relevant component from Infra:

- L1: No Infra (pure in-memory)
- L2: `Infra.get_cache_memory()` (optional, for Redis at scale)
- L3: `Infra.get_persistent_memory()` (required for persistence)

## Scaling Path

### Local Development

```jac
# TieredMemory.init(session="app.session")
#   → ShelfMemory.init(path="app.session")
#     → Infra.get_persistent_memory(config={'file_path': 'app.session'})
#       → FileStore (JSON file on disk)
```

### Production Scale (via jac-scale)

```jac
# TieredMemory.init(session="app.session")
#   → ShelfMemory.init(path="app.session")
#     → Infra.get_persistent_memory(config={'file_path': 'app.session'})
#       → MongoStore (MongoDB connection, provided by jac-scale)
```

The same `ShelfMemory` code works in both scenarios because it only depends on the `DataStore` interface.

## Benefits

1. **Separation of Concerns**: Infrastructure logic is isolated in the `Infra` module
2. **Testability**: Mock `DataStore` implementations can be injected for testing
3. **Scalability**: Seamless transition from file-based to distributed storage
4. **Vendor Independence**: Switch between storage backends via configuration
5. **Type Safety**: Proper types instead of `Any` enable better IDE support and error detection

## Future Work

- **L2 Cache Integration**: `TieredMemory` can be updated to use `Infra.get_cache_memory()` for L2, enabling Redis-based distributed caching
- **MongoDB Implementation**: `jac-scale` will provide `MongoStore` implementation of `DataStore`
- **Redis Implementation**: `jac-scale` will provide `RedisStore` implementation for caching

## Related Documentation

- [Memory Hierarchy](../jaclang/runtimelib/memory.jac) - Base memory interfaces and implementations
- [Infrastructure Module](../jaclang/runtimelib/server/infra.jac) - DataStore interface and factory methods
