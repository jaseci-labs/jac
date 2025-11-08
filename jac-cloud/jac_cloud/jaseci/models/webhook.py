"""Jaseci Models."""

from dataclasses import asdict, dataclass, field
from datetime import datetime
from typing import Any, Generator, Mapping, cast

from bson import ObjectId

from ..datasources.collection import Collection as BaseCollection


@dataclass(kw_only=True)
class Webhook:
    """Webhook Base Model."""

    id: ObjectId = field(default_factory=ObjectId)
    name: str
    root_id: ObjectId
    walkers: list[str]
    nodes: list[str]
    expiration: datetime
    key: str

    class Collection(BaseCollection["Webhook"]):
        """
        Webhook collection interface.

        This interface is for Webhook Credentials Management.
        You may override this if you wish to implement different structure
        """

        __collection__ = "webhook"
        __indexes__ = [
            {"keys": ["name"], "unique": True},
            {"keys": ["key"], "unique": True},
        ]

        @classmethod
        def __document__(cls, doc: Mapping[str, Any]) -> "Webhook":
            """
            Return parsed Webhook from document.

            This the default Webhook parser after getting a single document.
            You may override this to specify how/which class it will be casted/based.
            """
            doc = cast(dict, doc)
            return Webhook(id=doc.pop("_id"), **doc)

        @classmethod
        def find_by_root_id(cls, root_id: ObjectId) -> Generator["Webhook", None, None]:
            """Retrieve webhook via root_id."""
            return cls.find({"root_id": root_id})

        @classmethod
        def find_by_key(cls, key: str) -> "Webhook | None":
            """Retrieve webhook via root_id."""
            return cls.find_one({"key": key})

    def __serialize__(self) -> dict:
        """Return serializable."""
        data = asdict(self)
        data["_id"] = data.pop("id")
        return data
