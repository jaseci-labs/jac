"""Db annex.

The Db abilities in db.jac are abstract (`abs`); concrete behaviour lives in the
backend subclasses MongoDb (mongo_db.jac), RedisDb (redis_db.jac), and
FirestoreDb (firestore_db.jac), which override the operations their backend
supports. Jac does not enforce abstract overrides at compile time, so an
unsupported call returns None rather than raising. This module only holds the
get_db and get_firestore_db convenience constructors.
"""

def get_db -> Db {
    import from jac_scale.db { get_mongo_client }
    import from jac_scale.mongo_db { MongoDb }
    return MongoDb(client=get_mongo_client(), db_name='jac_db');
}

impl get_firestore_db(db_name: str = 'jac_db', project_id: (str | None) = None) -> Db {
    import from jac_scale.db { get_firestore_client }
    import from jac_scale.firestore_db { FirestoreDb }
    import from jac_scale.factories.database_factory { DatabaseType }
    return FirestoreDb(
        client=get_firestore_client(project_id=project_id),
        db_name=db_name,
        db_type=DatabaseType.FIRESTORE
    );
}
