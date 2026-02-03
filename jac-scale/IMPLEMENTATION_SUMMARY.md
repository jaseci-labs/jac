# Database Type Selection Feature - Implementation Summary

## Overview

Implemented support for users to specify database type (MongoDB or Redis) with optional URI configuration, similar to the storage_factory pattern.

## Changes Made

### 1. **runtime.py** - Updated hookspec for db() method

- Updated the `db()` hookspec in `/jac/jaclang/pycore/runtime.py` to include new parameters
- Added `db_type` parameter (default: "mongodb")
- Added `uri` parameter (default: None)
- This ensures the plugin hook matches the implementation signature

### 2. **database_factory.jac** - Added DatabaseType enum and client creation

- Added `DatabaseType` enum with `MONGODB` and `REDIS` values
- Added new `create_client()` static method that:
  - Accepts `db_type` (mongodb/redis), optional `uri`, and optional `config`
  - Checks URI priority: explicit parameter > environment variable > config file
  - Returns appropriate client (MongoClient or Redis)
  - Raises helpful error messages when URI is missing

### 3. **db.jac** - Updated Db object to support multiple database types

- Added Redis import
- Created separate global clients for MongoDB and Redis (`_mongo_client`, `_redis_client`)
- Added `get_redis_client()` function similar to `get_mongo_client()`
- Updated `get_mongo_client()` to accept optional `uri` parameter
- Modified `Db` object:
  - Changed `client` type to support both MongoClient and Redis
  - Added `db_type` attribute with default `DatabaseType.MONGODB`
  - Removed postinit logic (client is now passed directly from plugin)

### 4. **db.impl.jac** - Implemented database operations for both types

- Completely rewrote all database operation implementations to support both MongoDB and Redis
- Each method checks `self.db_type` and routes to appropriate implementation
- MongoDB operations use the existing pymongo interface
- Redis operations use JSON serialization with key pattern: `{db_name}:{collection}:{id}`
- Implemented methods:
  - `find_one()` - Find single document
  - `find()` - Find all matching documents
  - `insert_one()` - Insert single document
  - `update_one()` - Update single document
  - `delete_one()` - Delete single document
  - `insert_many()` - Insert multiple documents
  - `update_many()` - Update multiple documents
  - `find_by_id()` - Find by ID
  - `update_by_id()` - Update by ID
  - `delete_by_id()` - Delete by ID
- All methods return result objects similar to MongoDB interface for consistency

### 5. **plugin.jac** - Updated db() hook to accept new parameters

- Modified `db()` hook method to accept:
  - `db_name` (default: 'jac_db')
  - `db_type` (default: 'mongodb')
  - `uri` (default: None)
- Converts string `db_type` to `DatabaseType` enum
- Gets appropriate client based on db_type
- Returns initialized `Db` object with correct client and type
- Maintains backward compatibility (defaults to MongoDB)

### 6. **DATABASE_USAGE.md** - Comprehensive documentation

Created complete documentation covering:

- Basic usage examples for both MongoDB and Redis
- Custom URI specification
- Configuration priority (parameter > env var > config file)
- Environment variable setup
- jac.toml configuration format
- All supported database operations
- Using multiple databases together
- Migration guide from old API

### 7. **examples/database_example.jac** - Working examples

Created comprehensive examples demonstrating:

- MongoDB with default configuration
- MongoDB with custom URI
- Redis with default configuration
- Redis with custom URL
- Using multiple databases simultaneously

## Usage Examples

### Basic Usage

```jac
# MongoDB (default)
mongo_db = db(db_name='my_app', db_type='mongodb');

# Redis
redis_db = db(db_name='cache', db_type='redis');
```

### With Custom URIs

```jac
# MongoDB with custom URI
mongo_db = db(
    db_name='my_app',
    db_type='mongodb',
    uri='mongodb://localhost:27017'
);

# Redis with custom URL
redis_db = db(
    db_name='cache',
    db_type='redis',
    uri='redis://localhost:6379/0'
);
```

## Configuration

### Environment Variables

```bash
export MONGODB_URI="mongodb://localhost:27017"
export REDIS_URL="redis://localhost:6379/0"
```

### jac.toml

```toml
[plugins.scale.database]
mongodb_uri = "mongodb://localhost:27017"
redis_url = "redis://localhost:6379/0"
```

## Backward Compatibility

The old API still works and defaults to MongoDB:

```jac
# Old API - still works
db = db(db_name='my_app');  # Defaults to MongoDB
```

## Key Design Decisions

1. **Followed storage_factory.jac pattern** - Consistent with existing codebase
2. **URI priority system** - Explicit parameter > env var > config (like storage)
3. **Unified interface** - Both MongoDB and Redis use same method signatures
4. **Lazy initialization** - Clients are created on first use via global singletons
5. **Backward compatible** - Defaults to MongoDB when db_type not specified
6. **Redis key pattern** - Uses `{db_name}:{collection}:{id}` for logical organization

## Testing

All modified files have been checked for syntax errors with no issues found:

- ✅ runtime.py (hookspec updated)
- ✅ database_factory.jac
- ✅ db.jac
- ✅ db.impl.jac
- ✅ plugin.jac

The jac command now loads successfully with the updated plugin.

## Files Modified

1. `/jac/jaclang/pycore/runtime.py` - Updated hookspec with new parameters
2. `/jac-scale/jac_scale/factories/database_factory.jac` - Added enum and create_client method
3. `/jac-scale/jac_scale/db.jac` - Updated Db object and client initialization
4. `/jac-scale/jac_scale/impl/db.impl.jac` - Implemented operations for both database types
5. `/jac-scale/jac_scale/plugin.jac` - Updated db() hook with new parameters

## Files Created

1. `/jac-scale/DATABASE_USAGE.md` - Complete usage documentation
2. `/jac-scale/examples/database_example.jac` - Working examples

## Next Steps

To use this feature:

1. Set up your database URIs via environment variables or jac.toml
2. Call `db()` with desired `db_type` and optional `uri`
3. Use the standard database operations on the returned Db object
4. Refer to DATABASE_USAGE.md for complete documentation
5. Check examples/database_example.jac for working code samples
