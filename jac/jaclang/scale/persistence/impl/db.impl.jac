def get_db -> Db {
    import from jaclang.scale.persistence.db { get_mongo_client }
    import from jaclang.scale.persistence.mongo_db { MongoDb }
    return MongoDb(client=get_mongo_client(), db_name='jac_db');
}

impl get_firestore_db(db_name: str = 'jac_db', project_id: (str | None) = None) -> Db {
    import from jaclang.scale.persistence.db { get_firestore_client }
    import from jaclang.scale.persistence.firestore_db { FirestoreDb }
    import from jaclang.scale.deploy.database.factory { DatabaseType }
    return FirestoreDb(
        client=get_firestore_client(project_id=project_id),
        db_name=db_name,
        db_type=DatabaseType.FIRESTORE
    );
}
