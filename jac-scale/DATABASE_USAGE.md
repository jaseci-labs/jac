# Database Configuration Guide

The Jac Scale plugin now supports multiple database backends: **MongoDB** and **Redis**. You can easily switch between them and specify custom URIs.

## Basic Usage

### Using MongoDB (Default)

```jac
# Use MongoDB with default configuration
mongo_db = db(db_name='my_app', db_type='mongodb');

# Insert a document
result = mongo_db.insert_one('users', {
    'name': 'John Doe',
    'email': 'john@example.com'
});
```

### Using Redis

```jac
# Use Redis for caching or sessions
redis_db = db(db_name='cache', db_type='redis');

# Insert a cache entry
result = redis_db.insert_one('sessions', {
    'session_id': 'abc123',
    'user_id': '12345'
});
```

## Specifying Custom URIs

You can provide a custom database URI directly:

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

## Configuration Priority

The database URI is determined in the following order:

1. **Explicit URI parameter** (highest priority)
2. **Environment variable** (`MONGODB_URI` or `REDIS_URL`)
3. **Configuration file** (`jac.toml`)

### Environment Variables

Set these environment variables to configure your database connections:

```bash
# For MongoDB
export MONGODB_URI="mongodb://localhost:27017"

# For Redis
export REDIS_URL="redis://localhost:6379/0"
```

### Configuration File (jac.toml)

Add database configuration to your `jac.toml` file:

```toml
[plugins.scale]

[plugins.scale.database]
mongodb_uri = "mongodb://localhost:27017"
redis_url = "redis://localhost:6379/0"
```

## Database Operations

Both MongoDB and Redis support the same interface:

### Basic Operations

```jac
# Insert one document
result = db.insert_one('collection_name', {'key': 'value'});

# Find one document
doc = db.find_one('collection_name', {'key': 'value'});

# Find all matching documents
docs = db.find('collection_name', {'status': 'active'});

# Update one document
db.update_one('collection_name', {'_id': 'id'}, {'$set': {'key': 'new_value'}});

# Delete one document
db.delete_one('collection_name', {'_id': 'id'});
```

### ID-Based Operations

```jac
# Find by ID
doc = db.find_by_id('collection_name', 'document_id');

# Update by ID
db.update_by_id('collection_name', 'document_id', {'$set': {'key': 'value'}});

# Delete by ID
db.delete_by_id('collection_name', 'document_id');
```

### Bulk Operations

```jac
# Insert many documents
results = db.insert_many('collection_name', [
    {'name': 'Alice'},
    {'name': 'Bob'}
]);

# Update many documents
db.update_many('collection_name', {'status': 'pending'}, {'$set': {'status': 'active'}});
```

## Using Multiple Databases

You can use both MongoDB and Redis in the same application:

```jac
walker multi_db_example {
    can run with `root entry {
        # Use MongoDB for persistent data
        mongo_db = db(db_name='persistent_data', db_type='mongodb');

        # Use Redis for caching
        redis_db = db(db_name='cache', db_type='redis');

        # Store user in MongoDB
        user = mongo_db.insert_one('users', {'name': 'Alice'});

        # Cache session in Redis
        redis_db.insert_one('sessions', {'user_id': str(user.inserted_id)});
    }
}
```

## Implementation Details

### MongoDB

- Uses `pymongo.MongoClient` for connections
- Supports all standard MongoDB operations
- Collections are created automatically on first use
- Uses BSON ObjectId for `_id` fields

### Redis

- Uses `redis.Redis` for connections
- Data is stored as JSON strings with key pattern: `{db_name}:{collection}:{id}`
- Automatically generates UUIDs for documents without `_id`
- Supports basic filtering operations

## Examples

See [`examples/database_example.jac`](examples/database_example.jac) for complete working examples demonstrating:

- MongoDB with default config
- MongoDB with custom URI
- Redis with default config
- Redis with custom URL
- Using multiple databases together

## Migration from Old API

If you were using the old database API:

```jac
# Old API (still works for backward compatibility)
db = db(db_name='my_app');  # Defaults to MongoDB
```

New recommended usage:

```jac
# New API (explicit database type)
db = db(db_name='my_app', db_type='mongodb');
```

The old API still works and defaults to MongoDB for backward compatibility.
