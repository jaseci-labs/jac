"""Jaseci Securities."""

from os import getenv
from typing import Any

from asyncer import syncify

from bson import ObjectId

from fastapi import Depends, Request, WebSocket
from fastapi.exceptions import HTTPException
from fastapi.security import APIKeyHeader, APIKeyQuery, HTTPBearer

from jwt import decode, encode

from ..datasources.redis import CodeRedis, TokenRedis, WebhookRedis
from ..models import User as BaseUser, Webhook
from ..utils import logger, random_string, utc_timestamp
from ...core.archetype import NodeAnchor


TOKEN_SECRET = getenv("TOKEN_SECRET", random_string(50))
TOKEN_ALGORITHM = getenv("TOKEN_ALGORITHM", "HS256")
VERIFICATION_CODE_TIMEOUT = int(getenv("VERIFICATION_CODE_TIMEOUT") or "24")
RESET_CODE_TIMEOUT = int(getenv("RESET_CODE_TIMEOUT") or "24")
TOKEN_TIMEOUT = int(getenv("TOKEN_TIMEOUT") or "12")
User: type[BaseUser] = BaseUser.model()


def encrypt(data: dict) -> str:
    """Encrypt data."""
    return encode(data, key=TOKEN_SECRET, algorithm=TOKEN_ALGORITHM)


def decrypt(token: str) -> dict | None:
    """Decrypt data."""
    try:
        return decode(token, key=TOKEN_SECRET, algorithms=[TOKEN_ALGORITHM])
    except Exception:
        logger.exception("Token is invalid!")
        return None


def create_code(user_id: ObjectId, reset: bool = False) -> str:
    """Generate Verification Code."""
    verification = encrypt(
        {
            "user_id": str(user_id),
            "reset": reset,
            "expiration": utc_timestamp(
                hours=RESET_CODE_TIMEOUT if reset else VERIFICATION_CODE_TIMEOUT
            ),
        }
    )
    if CodeRedis.hset(key=verification, data=True):
        return verification
    raise HTTPException(500, "Verification Creation Failed!")


def verify_code(code: str, reset: bool = False) -> ObjectId | None:
    """Verify Code."""
    decrypted = decrypt(code)
    if (
        decrypted
        and decrypted["reset"] == reset
        and decrypted["expiration"] > utc_timestamp()
        and CodeRedis.hget(key=code)
    ):
        CodeRedis.hdelete(code)
        return ObjectId(decrypted["user_id"])
    return None


def create_token(user: dict[str, Any]) -> str:
    """Generate token for current user."""
    user["expiration"] = utc_timestamp(hours=TOKEN_TIMEOUT)
    user["state"] = random_string(8)
    token = encrypt(user)
    if TokenRedis.hset(f"{user['id']}:{token}", True):
        return token
    raise HTTPException(500, "Token Creation Failed!")


def invalidate_token(user_id: ObjectId) -> None:
    """Invalidate token of current user."""
    TokenRedis.hdelete_rgx(f"{user_id}:*")


def validate_request(request: Request, walker: str, node: str) -> None:
    """Trigger initial validation for request."""
    if ((walkers := getattr(request, "_walkers", None)) and walker not in walkers) or (
        (nodes := getattr(request, "_nodes", None)) and node not in nodes
    ):
        raise HTTPException(status_code=403)


def authenticate(request: Request) -> tuple[User, NodeAnchor]:  # type: ignore
    """Authenticate current request and attach authenticated user and their root."""
    authorization = request.headers.get("Authorization")
    if authorization and authorization.lower().startswith("bearer"):
        token = authorization[7:]
        if (
            (decrypted := decrypt(token))
            and decrypted["expiration"] > utc_timestamp()
            and TokenRedis.hget(f"{decrypted['id']}:{token}")
            and (user := User.Collection.find_by_id(decrypted["id"]))
            and (root := NodeAnchor.Collection.find_by_id(user.root_id))
        ):
            request._user = user  # type: ignore[attr-defined]
            request._root = root  # type: ignore[attr-defined]
            return user, root

    raise HTTPException(status_code=401)


def generate_webhook_auth(webhook: dict) -> list:
    """Authenticate current request and attach authenticated user and their root."""
    authenticators = []
    name = webhook.get("name", "X-API-KEY")
    match webhook.get("type", "header").lower():
        case "query":
            authenticators.append(Depends(APIKeyQuery(name=name)))

            def getter(request: Request) -> str | None:
                return request.query_params.get(name)

        case "path":

            def getter(request: Request) -> str | None:
                return request.path_params.get(name)

        case "body":

            def getter(request: Request) -> str | None:
                return syncify(request.json)().get(name)

        case _:

            authenticators.append(Depends(APIKeyHeader(name=name)))

            def getter(request: Request) -> str | None:
                return request.headers.get(name)

    def authenticate_webhook(request: Request) -> None:
        try:
            if (
                (key := getter(request))
                and (decrypted := key.split(":"))
                and (root := NodeAnchor.Collection.find_by_id(ObjectId(decrypted[0])))
            ):
                request._root = root  # type: ignore[attr-defined]
                if (cache := WebhookRedis.hget(key)) and cache[
                    "expiration"
                ] > utc_timestamp():
                    request._walkers = cache["walkers"]  # type: ignore[attr-defined]
                    request._nodes = cache["nodes"]  # type: ignore[attr-defined]
                    return
                elif (
                    webhook := Webhook.Collection.find_by_key(key)
                ) and WebhookRedis.hset(
                    key,
                    {
                        "walkers": webhook.walkers,
                        "nodes": webhook.nodes,
                        "expiration": webhook.expiration.timestamp(),
                    },
                ):
                    request._walkers = webhook.walkers  # type: ignore[attr-defined]
                    request._nodes = webhook.nodes  # type: ignore[attr-defined]
                    return
        except Exception as e:
            logger.exception(e)

        raise HTTPException(status_code=401)

    authenticators.append(Depends(authenticate_webhook))

    return authenticators


def authenticate_websocket(
    websocket: WebSocket, authorization: str | None = None
) -> bool:
    """Authenticate websocket connection."""
    if (
        authorization
        or ((authorization := websocket.headers.get("Authorization")))
        and authorization.lower().startswith("bearer")
    ):
        token = authorization.split(" ", 1)[-1]
        decrypted = decrypt(token)
        if (
            decrypted
            and decrypted["expiration"] > utc_timestamp()
            and TokenRedis.hget(f"{decrypted['id']}:{token}")
            and (user := User.Collection.find_by_id(decrypted["id"]))
            and (root := NodeAnchor.Collection.find_by_id(user.root_id))
        ):
            websocket._user = user  # type: ignore[attr-defined]
            websocket._root = root  # type: ignore[attr-defined]
            return True
    return False


BEARER = [Depends(HTTPBearer())]
authenticator = [*BEARER, Depends(authenticate)]
