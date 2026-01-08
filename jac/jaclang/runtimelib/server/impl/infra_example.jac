"""Example usage of the Infrastructure module for data storage.

This demonstrates how to use the Infra module to get cache and persistent
storage instances, and how to use them with UserManager.
"""

import from jaclang.runtimelib.server.infra { Infra, DataStore }
import from jaclang.runtimelib.server.user_manager { UserManager }

"""Example: Using default file-based storage."""
def example_file_storage() -> None {
    # Get persistent memory (defaults to file store)
    persistent_store = Infra.get_persistent_memory({
        'type': 'file',
        'path': '/tmp/users.json'
    });
    
    # Use with UserManager
    user_manager = UserManager();
    user_manager.init(session_path='/tmp/session', data_store=persistent_store);
    
    # UserManager now uses the DataStore for all persistence
    user_manager.create_user('alice', 'password123');
}

"""Example: Using Redis for cache and MongoDB for persistence."""
def example_redis_mongodb() -> None {
    # Get cache memory (Redis)
    cache_store = Infra.get_cache_memory({
        'type': 'redis',
        'host': 'localhost',
        'port': 6379,
        'db': 0
    });
    
    # Get persistent memory (MongoDB)
    persistent_store = Infra.get_persistent_memory({
        'type': 'mongodb',
        'connection_string': 'mongodb://localhost:27017/',
        'db_name': 'jac',
        'collection_name': 'users'
    });
    
    # Use with UserManager
    user_manager = UserManager();
    user_manager.init(session_path='/tmp/session', data_store=persistent_store);
    
    # All user data is now stored in MongoDB
    user_manager.create_user('bob', 'password456');
}

"""Example: Custom storage configuration from config file."""
def example_from_config() -> None {
    import from jaclang.project.config { get_config }
    
    config = get_config();
    if config and hasattr(config, 'environments') {
        db_config = config.environments.get('database', {});
        
        # Get stores based on config
        cache_store = Infra.get_cache_memory(db_config.get('cache', {}));
        persistent_store = Infra.get_persistent_memory(db_config.get('persistent', {}));
        
        # Use with UserManager
        user_manager = UserManager();
        user_manager.init(session_path='/tmp/session', data_store=persistent_store);
    }
}

"""Example: Direct DataStore usage."""
def example_direct_datastore() -> None {
    # Get a store instance
    store = Infra.get_persistent_memory({
        'type': 'file',
        'path': '/tmp/mydata.json'
    });
    
    if store {
        # Use the store directly
        store.set('key1', {'value': 'data'});
        data = store.get('key1');
        exists = store.exists('key1');
        store.delete('key1');
        store.close();
    }
}

