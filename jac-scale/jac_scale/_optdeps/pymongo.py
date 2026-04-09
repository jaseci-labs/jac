"""Guarded re-exports for pymongo and bson (install group: [data])."""

try:
    from pymongo import MongoClient, UpdateOne
    from pymongo.collection import Collection
    from pymongo.cursor import Cursor
    from pymongo.errors import ConnectionFailure
    from pymongo.results import (
        DeleteResult as PyMongoDeleteResult,
    )
    from pymongo.results import (
        InsertManyResult as PyMongoInsertManyResult,
    )
    from pymongo.results import (
        InsertOneResult as PyMongoInsertOneResult,
    )
    from pymongo.results import (
        UpdateResult as PyMongoUpdateResult,
    )

    HAS_PYMONGO = True
except ImportError:
    MongoClient = None
    UpdateOne = None
    PyMongoInsertOneResult = None
    PyMongoInsertManyResult = None
    PyMongoUpdateResult = None
    PyMongoDeleteResult = None
    Cursor = None
    Collection = None
    ConnectionFailure = Exception

    HAS_PYMONGO = False

try:
    from bson import ObjectId
except ImportError:
    ObjectId = None
