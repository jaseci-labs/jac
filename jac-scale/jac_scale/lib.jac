import from jac_scale.db { get_mongo_client, get_redis_client }
import from jac_scale.mongo_db { MongoDb }
import from jac_scale.redis_db { RedisDb }
import from jac_scale.factories.database_factory { DatabaseType }

def kvstore(
    db_name: str = 'jac_db', db_type: str = 'mongodb', uri: (str | None) = None
) -> MongoDb | RedisDb {
    db_type_enum = DatabaseType(db_type);

    if db_type_enum == DatabaseType.MONGODB {
        return MongoDb(client=get_mongo_client(uri=uri), db_name=db_name);
    } elif db_type_enum == DatabaseType.REDIS {
        return RedisDb(client=get_redis_client(uri=uri), db_name=db_name);
    } else {
        raise ValueError(f'Unsupported database type: {db_type}');
    }
}
