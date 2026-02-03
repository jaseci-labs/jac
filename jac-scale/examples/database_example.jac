"""Example demonstrating database usage with MongoDB and Redis.

SETUP REQUIRED:
Before running this example, you need to configure database URIs:

Option 1 - Environment Variables:
    export MONGODB_URI="mongodb://localhost:27017"
    export REDIS_URL="redis://localhost:6379/0"

Option 2 - Pass URI directly (see examples below)

Option 3 - Configure in jac.toml:
    [plugins.scale.database]
    mongodb_uri = "mongodb://localhost:27017"
    redis_url = "redis://localhost:6379/0"

This example shows how to:
1. Use MongoDB as the database backend
2. Use Redis as the database backend
3. Specify custom URIs for database connections
"""

# Example 1: Using MongoDB (default)
walker test_mongodb {
    can run with `root entry {
        try {
            # Default MongoDB connection (uses config or environment variables)
            mongo_db = db(db_name='my_app', db_type='mongodb');

            # Insert a document
            result = mongo_db.insert_one(
                'users', {'name': 'John Doe', 'email': 'john@example.com', 'age': 30}
            );
            print(f"✓ Inserted document with ID: {result.inserted_id}");

            # Find the document
            user = mongo_db.find_one('users', {'name': 'John Doe'});
            print(f"✓ Found user: {user}");

            # Update the document
            mongo_db.update_one('users', {'name': 'John Doe'}, {'$set': {'age': 31}});

            # Find by ID
            user = mongo_db.find_by_id('users', str(result.inserted_id));
            print(f"✓ Updated user: {user}");

            # Delete the document
            mongo_db.delete_one('users', {'name': 'John Doe'});
            print("✓ User deleted");
        } except Exception as e {
            print(f"✗ MongoDB test failed: {e}");
            print("  Tip: Set MONGODB_URI environment variable or pass uri parameter");
        }
    }
}

# Example 2: Using MongoDB with custom URI
walker test_mongodb_custom_uri {
    can run with `root entry {
        try {
            # Custom MongoDB URI - replace with your actual MongoDB connection string
            custom_mongo_db = db(
                db_name='my_custom_app',
                db_type='mongodb',
                uri='mongodb://localhost:27017'
            );

            # Insert a document
            result = custom_mongo_db.insert_one(
                'products', {'name': 'Laptop', 'price': 999.99, 'in_stock': True}
            );
            print(f"✓ Inserted product with ID: {result.inserted_id}");

            # Cleanup
            custom_mongo_db.delete_by_id('products', str(result.inserted_id));
            print("✓ Product deleted");
        } except Exception as e {
            print(f"✗ MongoDB custom URI test failed: {e}");
            print("  Tip: Ensure MongoDB is running on localhost:27017");
        }
    }
}

# Example 3: Using Redis
walker test_redis {
    can run with `root entry {
        try {
            # Redis connection (uses config or environment variables)
            redis_db = db(db_name='my_app', db_type='redis');

            # Insert a document
            result = redis_db.insert_one(
                'sessions',
                {
                    'session_id': 'abc123',
                    'user_id': '12345',
                    'expires_at': '2024-12-31'
                }
            );
            print(f"✓ Inserted session with ID: {result.inserted_id}");

            # Find the document
            session = redis_db.find_one('sessions', {'_id': result.inserted_id});
            print(f"✓ Found session: {session}");

            # Update the document
            redis_db.update_by_id(
                'sessions', result.inserted_id, {'$set': {'expires_at': '2025-01-31'}}
            );

            # Find updated session
            session = redis_db.find_by_id('sessions', result.inserted_id);
            print(f"✓ Updated session: {session}");

            # Delete the document
            redis_db.delete_by_id('sessions', result.inserted_id);
            print("✓ Session deleted");
        } except Exception as e {
            print(f"✗ Redis test failed: {e}");
            print("  Tip: Set REDIS_URL environment variable or pass uri parameter");
        }
    }
}

# Example 4: Using Redis with custom URL
walker test_redis_custom_url {
    can run with `root entry {
        try {
            # Custom Redis URL - replace with your actual Redis connection string
            custom_redis_db = db(
                db_name='cache', db_type='redis', uri='redis://localhost:6379/0'
            );

            # Insert a cache entry
            result = custom_redis_db.insert_one(
                'cache_entries',
                {
                    'key': 'user:12345',
                    'value': '{"name": "Jane", "email": "jane@example.com"}',
                    'ttl': 3600
                }
            );
            print(f"✓ Cached entry with ID: {result.inserted_id}");

            # Cleanup
            custom_redis_db.delete_by_id('cache_entries', result.inserted_id);
            print("✓ Cache entry deleted");
        } except Exception as e {
            print(f"✗ Redis custom URL test failed: {e}");
            print("  Tip: Ensure Redis is running on localhost:6379");
        }
    }
}

# Example 5: Working with multiple database types
walker test_multiple_databases {
    can run with `root entry {
        try {
            # Use MongoDB for persistent data
            mongo_db = db(db_name='persistent_data', db_type='mongodb');

            # Use Redis for caching/sessions
            redis_db = db(db_name='cache', db_type='redis');

            # Store user data in MongoDB
            user_result = mongo_db.insert_one(
                'users', {'name': 'Alice', 'email': 'alice@example.com'}
            );
            print(f"✓ User stored in MongoDB with ID: {user_result.inserted_id}");

            # Cache user session in Redis
            session_result = redis_db.insert_one(
                'sessions',
                {
                    'user_id': str(user_result.inserted_id),
                    'token': 'xyz789',
                    'created_at': '2024-01-15'
                }
            );
            print(f"✓ Session cached in Redis with ID: {session_result.inserted_id}");

            # Cleanup
            mongo_db.delete_by_id('users', str(user_result.inserted_id));
            redis_db.delete_by_id('sessions', session_result.inserted_id);

            # Both databases can be used independently
            print("✓ Successfully used both MongoDB and Redis!");
        } except Exception as e {
            print(f"✗ Multiple databases test failed: {e}");
            print("  Tip: Ensure both MongoDB and Redis are configured");
        }
    }
}

# Entry point
with entry {
    print("=== Database Examples ===");
    print("\nNOTE: These examples require MongoDB and/or Redis to be running.");
    print("Configure via environment variables, jac.toml, or pass URIs directly.\n");

    print("\nTest 1: MongoDB with default config");
    root spawn test_mongodb();

    print("\nTest 2: MongoDB with custom URI");
    root spawn test_mongodb_custom_uri();

    print("\nTest 3: Redis with default config");
    root spawn test_redis();

    print("\nTest 4: Redis with custom URL");
    root spawn test_redis_custom_url();

    print("\nTest 5: Multiple databases");
    root spawn test_multiple_databases();

    print("\n=== All tests completed ===");
}
