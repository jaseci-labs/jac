with entry {
    try {
        import from pymongo { AsyncMongoClient, MongoClient, UpdateOne }
        import from pymongo.collection { Collection }
        import from pymongo.cursor { Cursor }
        import from pymongo.errors {
            ConnectionFailure,
            DuplicateKeyError,
            PyMongoError
        }
        import from pymongo.results {
            InsertOneResult as PyMongoInsertOneResult,
            InsertManyResult as PyMongoInsertManyResult,
            UpdateResult as PyMongoUpdateResult,
            DeleteResult as PyMongoDeleteResult
        }
        HAS_PYMONGO = True;
    } except ImportError {
        MongoClient = None;
        AsyncMongoClient = None;
        UpdateOne = None;
        PyMongoInsertOneResult = None;
        PyMongoInsertManyResult = None;
        PyMongoUpdateResult = None;
        PyMongoDeleteResult = None;
        Cursor = None;
        Collection = None;
        ConnectionFailure = Exception;
        DuplicateKeyError = Exception;
        class _PyMongoUnavailableError(Exception) {}
        PyMongoError = _PyMongoUnavailableError;
        HAS_PYMONGO = False;
    }

    try {
        import from bson { ObjectId }
    } except ImportError {
        ObjectId = None;
    }
}
