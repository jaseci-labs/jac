"""Monty Implementations."""

from contextvars import ContextVar
from threading import current_thread
from typing import Any, Mapping, Sequence

from montydb import MontyClient as _MontyClient, set_storage  # type: ignore[import-untyped]
from montydb.collection import MontyCollection as _MontyCollection  # type: ignore[import-untyped]
from montydb.database import MontyDatabase as _MontyDatabase  # type: ignore[import-untyped]

from pymongo import DeleteMany, DeleteOne, InsertOne, UpdateMany, UpdateOne
from pymongo.cursor import Cursor
from pymongo.results import (
    BulkWriteResult,
    DeleteResult,
    InsertManyResult,
    InsertOneResult,
    UpdateResult,
)

MONTY_CLIENT = ContextVar[_MontyClient | None]("MONTY_CLIENT", default=None)


class MontyClientSession:
    """Monty Client Session."""

    def start_transaction(self) -> "MontyClientSession":
        """Start transaction."""
        return self

    def abort_transaction(self) -> None:
        """Abort transaction."""

    def commit_transaction(self) -> None:
        """Commit transaction."""

    def __enter__(self) -> "MontyClientSession":
        """Enter execution."""
        return self

    def __exit__(
        self, exc_type: Any, exc_val: Any, exc_tb: Any  # noqa: ANN401
    ) -> None:
        """Exit execution."""
        pass


class MontyCollection(_MontyCollection):
    """Monty Collection."""

    def __init__(self, col: _MontyCollection) -> None:
        """Override Init."""
        self.__dict__.update(col.__dict__)

    def create_indexes(self, *args, **kwargs: Any) -> None:  # noqa: ANN401, ANN002
        """Bypass Create Indexes."""
        pass

    def insert_one(
        self, document: dict, session: MontyClientSession | None = None
    ) -> InsertOneResult:
        """Override insert_one."""
        return super().insert_one(document)

    def insert_many(
        self,
        documents: list[dict],
        session: MontyClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> InsertManyResult:
        """Override insert_many."""
        return super().insert_many(documents, **kwargs)

    def update_one(
        self,
        filter: Mapping[str, Any],
        update: Mapping[str, Any] | Sequence[Any],
        session: MontyClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> UpdateResult:
        """Override update_one."""
        return super().update_one(filter, update, **kwargs)

    def update_many(
        self,
        filter: Mapping[str, Any],
        update: Mapping[str, Any] | Sequence[Any],
        session: MontyClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> UpdateResult:
        """Override update_many."""
        return super().update_many(filter, update, **kwargs)

    def find(
        self,
        filter: dict | None = None,
        projection: dict | None = None,
        session: MontyClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> Cursor:
        """Override find."""
        return super().find(filter, **kwargs)

    def find_one(
        self,
        filter: dict | None = None,
        projection: dict | None = None,
        session: MontyClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> Any | None:
        """Override find_one."""
        return super().find_one(filter, **kwargs)

    def delete_many(
        self,
        filter: Mapping[str, Any],
        session: MontyClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> DeleteResult:
        """Delete document/s via filter and return how many documents are deleted."""
        return super().delete_many(filter)

    def delete_one(
        self,
        filter: Mapping[str, Any],
        session: MontyClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> DeleteResult:
        """Delete single document via filter and return if it's deleted or not."""
        return super().delete_one(filter)

    def count_documents(
        self,
        filter: dict,
        session: MontyClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> int:
        """Override count_documents."""
        return super().count_documents(filter, **kwargs)

    def bulk_write(
        self,
        ops: list[InsertOne | DeleteMany | DeleteOne | UpdateMany | UpdateOne],
        ordered: bool = True,
        session: MontyClientSession | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> BulkWriteResult:
        """Bulk write operations."""
        deleted_count = 0
        inserted_count = 0
        modified_count = 0

        for op in ops:
            match op:
                case InsertOne():
                    if self.insert_one(op._doc).inserted_id:
                        inserted_count += 1
                case DeleteMany():
                    deleted_count += self.delete_many(op._filter).deleted_count
                case DeleteOne():
                    deleted_count += self.delete_one(op._filter).deleted_count
                case UpdateMany():
                    modified_count += self.update_many(
                        op._filter, op._doc
                    ).modified_count
                case UpdateOne():
                    modified_count += self.update_one(
                        op._filter, op._doc
                    ).modified_count
                case _:
                    pass

        return BulkWriteResult(
            {
                "bulk_api_result": {},
                "deleted_count": deleted_count,
                "inserted_count": inserted_count,
                "matched_count": deleted_count + modified_count,
                "modified_count": modified_count,
                "upserted_count": 0,
                "upserted_ids": {},
            },
            True,
        )


class MontyDatabase(_MontyDatabase):
    """Monty Database."""

    def __init__(self, db: _MontyDatabase) -> None:
        """Override Init."""
        self.__dict__.update(db.__dict__)

    def get_collection(self, name: str) -> MontyCollection:
        """Get Collection."""
        return MontyCollection(super().get_collection(name))  # noqa: B009


class MontyClient(_MontyClient):
    """Monty Client."""

    def __init__(
        self, repository: str, *args: Any, **kwargs: Any  # noqa: ANN401
    ) -> None:
        """Initialize MontyClient Mock."""
        self.repository = repository
        super().__init__(repository, *args, **kwargs)

    def get_database(self, name: str) -> MontyDatabase:
        """Get local database."""
        if not (client := MONTY_CLIENT.get()):
            client = _MontyClient(self.repository)
            if current_thread().name != "MainThread":
                MONTY_CLIENT.set(client)

        return MontyDatabase(client.get_database(name))

    def start_session(self) -> MontyClientSession:
        """Start session."""
        return MontyClientSession()


__all__ = ["MontyClient", "set_storage"]
