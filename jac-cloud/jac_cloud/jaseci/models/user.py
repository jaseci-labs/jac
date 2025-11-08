"""Jaseci Models."""

from dataclasses import MISSING, asdict, dataclass, field, fields
from typing import Any, Mapping, Type, cast, get_type_hints

from bson import ObjectId

from fastapi_sso import OpenID

from passlib.hash import pbkdf2_sha512

from pydantic import BaseModel, EmailStr, create_model

from ..datasources.collection import Collection as BaseCollection

NO_PASSWORD = bytes(True)


class UserRegistration(BaseModel):
    """User Common Functionalities."""

    email: EmailStr
    password: str

    def obfuscate(self) -> dict:
        """Return BaseModel.model_dump where the password is hashed."""
        data = self.model_dump(exclude={"password"})
        data["password"] = pbkdf2_sha512.hash(self.password).encode()
        return data

    def printable(self) -> dict:
        """Return BaseModel.model_dump where the password is hashed."""
        data = self.model_dump(exclude={"password"})
        data["password"] = "****"
        return data


@dataclass(kw_only=True)
class User:
    """User Base Model."""

    id: ObjectId
    email: EmailStr
    password: bytes
    root_id: ObjectId
    is_activated: bool = False
    is_admin: bool = False
    sso: dict[str, dict[str, str]] = field(default_factory=dict)

    class Collection(BaseCollection["User"]):
        """
        User collection interface.

        This interface is for User's Management.
        You may override this if you wish to implement different structure
        """

        __collection__ = "user"
        __excluded__ = ["password"]
        __indexes__ = [{"keys": ["email"], "unique": True}]

        @classmethod
        def __document__(cls, doc: Mapping[str, Any]) -> "User":
            """
            Return parsed User from document.

            This the default User parser after getting a single document.
            You may override this to specify how/which class it will be casted/based.
            """
            doc = cast(dict, doc)
            return User.model()(
                id=doc.pop("_id"),
                password=doc.pop("password", None) or NO_PASSWORD,
                root_id=doc.pop("root_id"),
                **doc,
            )

        @classmethod
        def find_by_email(cls, email: str) -> "User | None":
            """Retrieve user via email."""
            return cls.find_one(filter={"email": email}, projection={})

    def serialize(self) -> dict:
        """Return BaseModel.model_dump excluding the password field."""
        data = asdict(self)
        data["id"] = str(self.id)
        data["root_id"] = str(self.root_id)
        data.pop("sso", None)
        data.pop("password", None)
        return data

    @staticmethod
    def model() -> Type["User"]:
        """Retrieve the preferred User Model from subclasses else this class."""
        if subs := User.__subclasses__():
            return dataclass(kw_only=True)(subs[-1])
        return User

    @staticmethod
    def register_type() -> Type[UserRegistration]:
        """Generate User Registration Model based on preferred User Model for FastAPI endpoint validation."""
        target_user_model = User.model()
        target_user_hintings = get_type_hints(target_user_model)
        user_model: dict[str, Any] = {}

        for f in fields(target_user_model):
            if callable(f.default_factory):
                user_model[f.name] = (
                    target_user_hintings[f.name],
                    f.default_factory(),
                )
            else:
                user_model[f.name] = (
                    target_user_hintings[f.name],
                    ... if f.default is MISSING else f.default,
                )

        user_model["password"] = (str, ...)
        user_model.pop("id", None)
        user_model.pop("root_id", None)
        user_model.pop("is_activated", None)
        user_model.pop("is_admin", None)
        user_model.pop("sso", None)

        return create_model("UserRegister", __base__=UserRegistration, **user_model)

    @staticmethod
    def send_verification_code(code: str, email: str) -> None:
        """Send verification code."""
        pass

    @staticmethod
    def send_reset_code(code: str, email: str) -> None:
        """Send verification code."""
        pass

    @staticmethod
    def sso_mapper(open_id: OpenID) -> dict[str, object]:
        """Send verification code."""
        return {}

    @staticmethod
    def system_admin_default() -> dict[str, object]:
        """System Admin default data."""
        return {}
