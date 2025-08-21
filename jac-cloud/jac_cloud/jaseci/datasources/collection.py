"""Collection Abstract."""

from os import getenv
from tempfile import gettempdir
from typing import (
    Any,
    AsyncGenerator,
    Generator,
    Generic,
    Iterable,
    Mapping,
    Type,
    TypeVar,
    cast,
)


from bson import ObjectId

from motor.motor_asyncio import (
    AsyncIOMotorClient,
    AsyncIOMotorClientSession,
    AsyncIOMotorCollection,
    AsyncIOMotorCursor,
    AsyncIOMotorDatabase,
    AsyncIOMotorLatentCommandCursor,
)

from pymongo import (
    DeleteMany,
    DeleteOne,
    IndexModel,
    InsertOne,
    MongoClient,
    UpdateMany,
    UpdateOne,
)
from pymongo.client_session import ClientSession
from pymongo.collection import Collection as PyMongoCollection
from pymongo.command_cursor import CommandCursor
from pymongo.cursor import Cursor
from pymongo.database import Database
from pymongo.results import (
    BulkWriteResult,
    DeleteResult,
    InsertManyResult,
    InsertOneResult,
    UpdateResult,
)
from pymongo.server_api import ServerApi

from .localdb import MontyClient, set_storage
from ..utils import logger

T = TypeVar("T")

# TODO:need this function in future for partial indexing
# from pymongo.operations import _IndexKeyHint
# def apply_prefix(prefix: str, keys: _IndexKeyHint) -> _IndexKeyHint:
#     """Apply prefix for every key."""
#     match keys:
#         case str():
#             return f"{prefix}{keys}"
#         case list() | set() | tuple():
#             return [
#                 (
#                     f"{prefix}{key}"
#                     if isinstance(key, str)
#                     else (f"{prefix}{key[0]}", key[1])
#                 )
#                 for key in keys
#             ]
#         case dict():
#             return {f"{prefix}{key}": value for key, value in keys.items()}
#         case _:
#             return keys


class Collection(Generic[T]):
    """
    Base collection interface.

    This interface use for connecting to mongodb.
    """

    ##########################################
    # ---------- Child Properties ---------- #
    ##########################################

    # Collection Name
    __collection__: str | None = None
    # Singleton Collection Instance
    __collection_obj__: PyMongoCollection | None = None

    # Custom Index Declaration
    __indexes__: list[dict] = []
    __default_indexes__: list[dict] = []

    # Transient Field List
    __excluded__: list = []
    # Converted Mapping of Transient Fields
    __excluded_obj__: Mapping[str, Any] | None = None

    ##########################################
    # ---------- Parent Properties --------- #
    ##########################################

    # Singleton client instance
    __client__: MongoClient | None = None
    # Singleton database instance
    __database__: Database | None = None

    @staticmethod
    def apply_indexes() -> None:
        """Apply Indexes."""
        queue: list[type[Collection]] = Collection.__subclasses__()
        while queue:
            cls = queue.pop(-1)

            if scls := cls.__subclasses__():
                queue.extend(scls)

            if cls.__collection__ is None:
                continue

            if cls.__excluded__:
                excl_obj = {}
                for excl in cls.__excluded__:
                    excl_obj[excl] = False
                cls.__excluded_obj__ = excl_obj

            idxs = []
            if cls.__default_indexes__:
                for idx in cls.__default_indexes__:
                    idxs.append(IndexModel(**idx))

            if cls.__indexes__:
                for idx in cls.__indexes__:
                    idxs.append(IndexModel(**idx))

            if idxs:
                cls.collection().create_indexes(idxs)

    @classmethod
    def apply_partial_indexes(cls, type: Type) -> None:
        """Apply Partial Indexes."""
        constraints = getattr(type, "__constraints__", None)
        if constraints:
            unique_fields_list = constraints.unique
            if len(unique_fields_list) != 0:
                partial_indexes = []
                for unique_field in unique_fields_list:
                    indexed_fields = []
                    for field_name in unique_field:
                        indexed_fields.append((field_name, 1))
                    partial_index = IndexModel(indexed_fields, unique=True)
                    partial_indexes.append(partial_index)
                cls.collection().create_indexes(partial_indexes)
        # original implementation
        # indexes: list[Index] = getattr(type, "__jac_indexes__", [])
        # if indexes:
        #     idxs = [
        #         IndexModel(
        #             apply_prefix("architype.", index["key"]),
        #             **{
        #                 **(constraints := index.get("constraints", {})),
        #                 "unique": True,  # TODO: need more fixes for this
        #                 "partialFilterExpression": {
        #                     **constraints.get("partialFilterExpression", {}),
        #                     "name": type.__name__,
        #                 },
        #             },
        #         )
        #         for index in indexes
        #     ]
        #     cls.collection().create_indexes(idxs)

    @classmethod
    def __document__(cls, doc: Mapping[str, Any]) -> T:
        """
        Return parsed version of document.

        This the default parser after getting a single document.
        You may override this to specify how/which class it will be casted/based.
        """
        return cast(T, doc)

    @classmethod
    def __documents__(cls, docs: Cursor) -> Generator[T, None, None]:
        """
        Return parsed version of multiple documents.

        This the default parser after getting a list of documents.
        You may override this to specify how/which class it will be casted/based.
        """
        return (cls.__document__(doc) for doc in docs)

    @staticmethod
    def get_client() -> MongoClient:
        """Return pymongo.database.Database for mongodb connection."""
        if (client := Collection.__client__) is None:
            if host := getenv("DATABASE_HOST"):
                client = Collection.__client__ = MongoClient(
                    host,
                    server_api=ServerApi("1"),
                )
            else:
                logger.info("DATABASE_HOST is not available! Using LocalDB...")
                path = getenv("DATABASE_PATH") or f"{gettempdir()}/mydatabase"
                set_storage(
                    repository=path,
                    storage="sqlite",
                    mongo_version="4.4",
                    use_bson=True,
                )
                client = Collection.__client__ = MontyClient(path)

        return client

    @staticmethod
    def get_session() -> ClientSession:
        """Return pymongo.client_session.ClientSession used for mongodb transactional operations."""
        return Collection.get_client().start_session()

    @staticmethod
    def get_database() -> Database:
        """Return pymongo.database.Database for database connection based from current client connection."""
        if not isinstance(Collection.__database__, Database):
            Collection.__database__ = Collection.get_client().get_database(
                getenv("DATABASE_NAME", "jaseci")
            )

        return Collection.__database__

    @staticmethod
    def get_collection(collection: str) -> PyMongoCollection:
        """Return pymongo.collection.Collection for collection connection based from current database connection."""
        return Collection.get_database().get_collection(collection)

    @classmethod
    def collection(cls) -> PyMongoCollection:
        """Return pymongo.collection.Collection for collection connection based from attribute of it's child class."""
        if not isinstance(cls.__collection_obj__, PyMongoCollection):
            cls.__collection_obj__ = cls.get_collection(
                getattr(cls, "__collection__", None) or cls.__name__.lower()
            )

        return cls.__collection_obj__

    @classmethod
    def insert_one(
        cls,
        doc: dict,
        session: ClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> InsertOneResult:
        """Insert single document and return the inserted id."""
        return cls.collection().insert_one(doc, session=session, **kwargs)

    @classmethod
    def insert_many(
        cls,
        docs: list[dict],
        session: ClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> InsertManyResult:
        """Insert multiple documents and return the inserted ids."""
        return cls.collection().insert_many(docs, session=session, **kwargs)

    @classmethod
    def update_one(
        cls,
        filter: dict,
        update: dict,
        session: ClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> UpdateResult:
        """Update single document and return if it's modified or not."""
        return cls.collection().update_one(filter, update, session=session, **kwargs)

    @classmethod
    def update_many(
        cls,
        filter: dict,
        update: dict,
        session: ClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> UpdateResult:
        """Update multiple documents and return how many docs are modified."""
        return cls.collection().update_many(filter, update, session=session, **kwargs)

    @classmethod
    def update_by_id(
        cls,
        id: str | ObjectId,
        update: dict,
        session: ClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> UpdateResult:
        """Update single document via ID and return if it's modified or not."""
        return cls.update_one({"_id": ObjectId(id)}, update, session, **kwargs)

    @classmethod
    def find(
        cls,
        filter: Mapping[str, Any] | None = None,
        projection: Mapping[str, Any] | Iterable[str] | None = None,
        session: ClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> Generator[T, None, None]:
        """Retrieve multiple documents."""
        if projection is None:
            projection = cls.__excluded_obj__

        docs = cls.collection().find(filter, projection, session=session, **kwargs)
        return cls.__documents__(docs)

    @classmethod
    def find_one(
        cls,
        filter: Mapping[str, Any] | None = None,
        projection: Mapping[str, Any] | Iterable[str] | None = None,
        session: ClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> T | None:
        """Retrieve single document from db."""
        if projection is None:
            projection = cls.__excluded_obj__

        if ops := cls.collection().find_one(
            filter, projection, session=session, **kwargs
        ):
            return cls.__document__(ops)
        return None

    @classmethod
    def find_one_and_update(
        cls,
        filter: Mapping[str, Any],
        update: dict,
        projection: Mapping[str, Any] | Iterable[str] | None = None,
        session: ClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> T | None:
        """Retrieve single document from db."""
        if projection is None:
            projection = cls.__excluded_obj__

        if ops := cls.collection().find_one_and_update(
            filter, update, projection, session=session, **kwargs
        ):
            return cls.__document__(ops)
        return None

    @classmethod
    def find_by_id(
        cls,
        id: str | ObjectId,
        projection: Mapping[str, Any] | Iterable[str] | None = None,
        session: ClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> T | None:
        """Retrieve single document via ID."""
        return cls.find_one(
            {"_id": ObjectId(id)}, projection, session=session, **kwargs
        )

    @classmethod
    def delete(
        cls,
        filter: dict,
        session: ClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> DeleteResult:
        """Delete document/s via filter and return how many documents are deleted."""
        return cls.collection().delete_many(filter, session=session, **kwargs)

    @classmethod
    def delete_one(
        cls,
        filter: dict,
        session: ClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> DeleteResult:
        """Delete single document via filter and return if it's deleted or not."""
        return cls.collection().delete_one(filter, session=session, **kwargs)

    @classmethod
    def delete_by_id(
        cls,
        id: str | ObjectId,
        session: ClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> DeleteResult:
        """Delete single document via ID and return if it's deleted or not."""
        return cls.delete_one({"_id": ObjectId(id)}, session, **kwargs)

    @classmethod
    def bulk_write(
        cls,
        ops: list[InsertOne | DeleteMany | DeleteOne | UpdateMany | UpdateOne],
        ordered: bool = True,
        session: ClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> BulkWriteResult:
        """Bulk write operations."""
        return cls.collection().bulk_write(
            ops, ordered=ordered, session=session, **kwargs
        )

    @classmethod
    def count(
        cls,
        filter: dict,
        session: ClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> int:
        """Bulk write operations."""
        return cls.collection().count_documents(filter, session, **kwargs)

    @classmethod
    def aggregate(
        cls,
        pipeline: list[dict],
        session: ClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> CommandCursor:
        """Bulk write operations."""
        return cls.collection().aggregate(pipeline, session, **kwargs)


class AsyncCollection(Generic[T]):
    """
    Base collection interface.

    This interface use for connecting to mongodb.
    """

    ##########################################
    # ---------- Child Properties ---------- #
    ##########################################

    # Collection Name
    __collection__: str | None = None
    # Singleton Collection Instance
    __collection_obj__: AsyncIOMotorCollection | None = None

    # Custom Index Declaration
    __indexes__: list[dict] = []
    __default_indexes__: list[dict] = []

    # Transient Field List
    __excluded__: list = []
    # Converted Mapping of Transient Fields
    __excluded_obj__: Mapping[str, Any] | None = None

    ##########################################
    # ---------- Parent Properties --------- #
    ##########################################

    # Singleton client instance
    __client__: AsyncIOMotorClient | None = None
    # Singleton database instance
    __database__: AsyncIOMotorDatabase | None = None

    @staticmethod
    async def apply_indexes() -> None:
        """Apply Indexes."""
        queue: list[type[AsyncCollection]] = AsyncCollection.__subclasses__()
        while queue:
            cls = queue.pop(-1)

            if scls := cls.__subclasses__():
                queue.extend(scls)

            if cls.__collection__ is None:
                continue

            if cls.__excluded__:
                excl_obj = {}
                for excl in cls.__excluded__:
                    excl_obj[excl] = False
                cls.__excluded_obj__ = excl_obj

            idxs = []
            if cls.__default_indexes__:
                for idx in cls.__default_indexes__:
                    idxs.append(IndexModel(**idx))

            if cls.__indexes__:
                for idx in cls.__indexes__:
                    idxs.append(IndexModel(**idx))

            if idxs:
                await cls.collection().create_indexes(idxs)

    @classmethod
    def __document__(cls, doc: Mapping[str, Any]) -> T:
        """
        Return parsed version of document.

        This the default parser after getting a single document.
        You may override this to specify how/which class it will be casted/based.
        """
        return cast(T, doc)

    @classmethod
    async def __documents__(cls, docs: AsyncIOMotorCursor) -> AsyncGenerator[T, None]:
        """
        Return parsed version of multiple documents.

        This the default parser after getting a list of documents.
        You may override this to specify how/which class it will be casted/based.
        """
        return (cls.__document__(doc) async for doc in docs)

    @staticmethod
    def get_client() -> AsyncIOMotorClient:
        """Return pymongo.database.Database for mongodb connection."""
        if not isinstance(AsyncCollection.__client__, AsyncIOMotorClient):
            AsyncCollection.__client__ = AsyncIOMotorClient(
                getenv(
                    "DATABASE_HOST",
                    "mongodb://localhost/?retryWrites=true&w=majority",
                ),
                server_api=ServerApi("1"),
            )

        return AsyncCollection.__client__

    @staticmethod
    async def get_session() -> AsyncIOMotorClientSession:
        """Return pymongo.client_session.ClientSession used for mongodb transactional operations."""
        return await AsyncCollection.get_client().start_session()

    @staticmethod
    def get_database() -> AsyncIOMotorDatabase:
        """Return pymongo.database.Database for database connection based from current client connection."""
        if not isinstance(AsyncCollection.__database__, AsyncIOMotorDatabase):
            AsyncCollection.__database__ = AsyncCollection.get_client().get_database(
                getenv("DATABASE_NAME", "jaseci")
            )

        return AsyncCollection.__database__

    @staticmethod
    def get_collection(collection: str) -> AsyncIOMotorCollection:
        """Return pymongo.collection.Collection for collection connection based from current database connection."""
        return AsyncCollection.get_database().get_collection(collection)

    @classmethod
    def collection(cls) -> AsyncIOMotorCollection:
        """Return pymongo.collection.Collection for collection connection based from attribute of it's child class."""
        if not isinstance(cls.__collection_obj__, AsyncIOMotorCollection):
            cls.__collection_obj__ = cls.get_collection(
                getattr(cls, "__collection__", None) or cls.__name__.lower()
            )

        return cls.__collection_obj__

    @classmethod
    async def insert_one(
        cls,
        doc: dict,
        session: AsyncIOMotorClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> InsertOneResult:
        """Insert single document and return the inserted id."""
        return await cls.collection().insert_one(doc, session=session, **kwargs)

    @classmethod
    async def insert_many(
        cls,
        docs: list[dict],
        session: AsyncIOMotorClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> InsertManyResult:
        """Insert multiple documents and return the inserted ids."""
        return await cls.collection().insert_many(docs, session=session, **kwargs)

    @classmethod
    async def update_one(
        cls,
        filter: dict,
        update: dict,
        session: AsyncIOMotorClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> UpdateResult:
        """Update single document and return if it's modified or not."""
        return await cls.collection().update_one(
            filter, update, session=session, **kwargs
        )

    @classmethod
    async def update_many(
        cls,
        filter: dict,
        update: dict,
        session: AsyncIOMotorClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> UpdateResult:
        """Update multiple documents and return how many docs are modified."""
        return await cls.collection().update_many(
            filter, update, session=session, **kwargs
        )

    @classmethod
    async def update_by_id(
        cls,
        id: str | ObjectId,
        update: dict,
        session: AsyncIOMotorClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> UpdateResult:
        """Update single document via ID and return if it's modified or not."""
        return await cls.update_one({"_id": ObjectId(id)}, update, session, **kwargs)

    @classmethod
    async def find(
        cls,
        filter: Mapping[str, Any] | None = None,
        projection: Mapping[str, Any] | Iterable[str] | None = None,
        session: AsyncIOMotorClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> AsyncGenerator[T, None]:
        """Retrieve multiple documents."""
        if projection is None:
            projection = cls.__excluded_obj__

        docs = cls.collection().find(filter, projection, session=session, **kwargs)
        return await cls.__documents__(docs)

    @classmethod
    async def find_one(
        cls,
        filter: Mapping[str, Any] | None = None,
        projection: Mapping[str, Any] | Iterable[str] | None = None,
        session: AsyncIOMotorClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> T | None:
        """Retrieve single document from db."""
        if projection is None:
            projection = cls.__excluded_obj__

        if ops := await cls.collection().find_one(
            filter, projection, session=session, **kwargs
        ):
            return cls.__document__(ops)
        return None

    @classmethod
    async def find_by_id(
        cls,
        id: str | ObjectId,
        projection: Mapping[str, Any] | Iterable[str] | None = None,
        session: AsyncIOMotorClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> T | None:
        """Retrieve single document via ID."""
        return await cls.find_one(
            {"_id": ObjectId(id)}, projection, session=session, **kwargs
        )

    @classmethod
    async def delete(
        cls,
        filter: dict,
        session: AsyncIOMotorClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> DeleteResult:
        """Delete document/s via filter and return how many documents are deleted."""
        return await cls.collection().delete_many(filter, session=session, **kwargs)

    @classmethod
    async def delete_one(
        cls,
        filter: dict,
        session: AsyncIOMotorClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> DeleteResult:
        """Delete single document via filter and return if it's deleted or not."""
        return await cls.collection().delete_one(filter, session=session, **kwargs)

    @classmethod
    async def delete_by_id(
        cls,
        id: str | ObjectId,
        session: AsyncIOMotorClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> DeleteResult:
        """Delete single document via ID and return if it's deleted or not."""
        return await cls.delete_one({"_id": ObjectId(id)}, session, **kwargs)

    @classmethod
    async def bulk_write(
        cls,
        ops: list[InsertOne | DeleteMany | DeleteOne | UpdateMany | UpdateOne],
        ordered: bool = True,
        session: AsyncIOMotorClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> BulkWriteResult:
        """Bulk write operations."""
        return await cls.collection().bulk_write(
            ops, ordered=ordered, session=session, **kwargs
        )

    @classmethod
    async def count(
        cls,
        filter: dict,
        session: AsyncIOMotorClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> int:
        """Bulk write operations."""
        return await cls.collection().count_documents(filter, session, **kwargs)

    @classmethod
    async def aggregate(
        cls,
        pipeline: list[dict],
        session: AsyncIOMotorClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> AsyncIOMotorLatentCommandCursor:
        """Bulk write operations."""
        return cls.collection().aggregate(pipeline, session, **kwargs)
