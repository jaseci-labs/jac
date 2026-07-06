import from jaclang.scale.persistence.db {
    Db,
    InsertResult,
    InsertManyResult,
    UpdateResult,
    DeleteResult
}
import from jaclang.scale._optdeps.firestore { FirestoreClient }
import from jaclang.scale.deploy.database.factory { DatabaseType }

obj FirestoreDb(Db) {
    has client: FirestoreClient,
        db_type: DatabaseType = DatabaseType.FIRESTORE;

    def _get_firestore_collection(col_name: str) -> any;
    def get(key: str, col_name: str = 'default') -> dict | None;
    def set(key: str, value: dict, col_name: str = 'default') -> str;
    def delete(key: str, col_name: str = 'default') -> int;
    def exists(key: str, col_name: str = 'default') -> bool;
    def find_one(
        col_name: str, filter: dict, projection: dict | None = None
    ) -> dict | None;

    def find(
        col_name: str,
        filter: dict,
        projection: dict | None = None,
        limit: int | None = None
    ) -> list;

    def count_documents(col_name: str, filter: dict) -> int;
    def create_index(
        col_name: str, keys: dict, unique: bool = False, name: str | None = None
    ) -> str;

    def insert_one(col_name: str, document: dict) -> InsertResult;
    def update_one(
        col_name: str, filter: dict, update_data: dict, upsert_mode: bool = False
    ) -> UpdateResult;

    def delete_one(col_name: str, filter: dict) -> DeleteResult;
    def insert_many(col_name: str, documents: list) -> InsertManyResult;
    def update_many(
        col_name: str, filter: dict, update_data: dict, upsert_mode: bool = False
    ) -> UpdateResult;

    def delete_many(col_name: str, filter: dict) -> DeleteResult;
    def find_by_id(col_name: str, id: str) -> dict | None;
    def update_by_id(
        col_name: str, id: str, update_data: dict, upsert_mode: bool = False
    ) -> UpdateResult;

    def delete_by_id(col_name: str, id: str) -> DeleteResult;
}
