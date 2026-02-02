"""Direct Database Access Module."""
import from pymongo { MongoClient }
import from typing { Any }
import from jac_scale.config_loader { get_scale_config }
import from bson { ObjectId }

glob _client: (MongoClient | None) = None;

def get_mongo_client -> MongoClient {
    global _client;
    if _client is None {
        config = get_scale_config();
        db_config = config.get_database_config();
        mongo_url = db_config['mongodb_uri'];
        _client = MongoClient(mongo_url);
    }

    return _client;
}

obj Db {
    has client: MongoClient = get_mongo_client(),
        db_name: str = 'jac_db';

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
