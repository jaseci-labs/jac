"""Db annex.

The Db abilities in db.jac are abstract (`abs`); concrete behaviour lives in the
backend subclasses MongoDb (mongo_db.jac) and RedisDb (redis_db.jac), which
override the operations their backend supports. Jac does not enforce abstract
overrides at compile time, so an unsupported call (e.g. a Redis-only method on a
MongoDb handle) returns None rather than raising. This module only holds the
get_db convenience constructor.
"""

def get_db -> Db {
    # Local imports avoid a circular dependency: db.impl -> mongo_db -> db.
    import from jac_scale.db { get_mongo_client }
    import from jac_scale.mongo_db { MongoDb }
    return MongoDb(client=get_mongo_client(), db_name='jac_db');
}
