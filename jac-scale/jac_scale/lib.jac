"""Public API for jac-scale library functions.

This module provides user-facing APIs for direct database access and other utilities.
"""
import from jac_scale.db { Db, get_mongo_client, get_redis_client }
import from jac_scale.factories.database_factory { DatabaseType }

def kvstore(
    db_name: str = 'jac_db', db_type: str = 'mongodb', uri: (str | None) = None
) -> Db {
    # Convert string to DatabaseType enum
    db_type_enum = DatabaseType(db_type);

    # Get appropriate client based on database type
    if db_type_enum == DatabaseType.MONGODB {
        client = get_mongo_client(uri=uri);
    } elif db_type_enum == DatabaseType.REDIS {
        client = get_redis_client(uri=uri);
    } else {
        raise ValueError(f'Unsupported database type: {db_type}') ;
    }

    return Db(client=client, db_name=db_name, db_type=db_type_enum);
}
