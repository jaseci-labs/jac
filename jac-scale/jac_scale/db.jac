"""Direct Database Access Module."""
import from pymongo { MongoClient }
import from redis { Redis }
import from typing { Any }
import from jac_scale.factories.database_factory {
    DatabaseProviderFactory,
    DatabaseType
}
import from bson { ObjectId }

glob _mongo_client: (MongoClient | None) = None,
     _redis_client: (Redis | None) = None;

def get_mongo_client(uri: (str | None) = None) -> MongoClient {
    global _mongo_client;
    if _mongo_client is None {
        _mongo_client = DatabaseProviderFactory.create_client(
            DatabaseType.MONGODB, uri=uri
        );
    }
    return _mongo_client;
}

def get_redis_client(uri: (str | None) = None) -> Redis {
    global _redis_client;
    if _redis_client is None {
        _redis_client = DatabaseProviderFactory.create_client(
            DatabaseType.REDIS, uri=uri
        );
    }
    return _redis_client;
}

obj Db {
    has client: (MongoClient | Redis),
        db_name: str = 'jac_db',
        db_type: DatabaseType = DatabaseType.MONGODB;

    def find_one(col_name: str, filter: dict) -> dict | None;
    def find(col_name: str, filter: dict) -> Any;
    def insert_one(col_name: str, document: dict) -> Any;
    def update_one(
        col_name: str, filter: dict, update_data: dict, upsert_mode: bool = False
    ) -> Any;

    def delete_one(col_name: str, filter: dict) -> Any;
    # Bulk operations
    def insert_many(col_name: str, documents: list) -> Any;
    def update_many(
        col_name: str, filter: dict, update_data: dict, upsert_mode: bool = False
    ) -> Any;

    # ID-based convenience methods
    def find_by_id(col_name: str, id: str) -> dict | None;
    def update_by_id(
        col_name: str, id: str, update_data: dict, upsert_mode: bool = False
    ) -> Any;

    def delete_by_id(col_name: str, id: str) -> Any;
}
