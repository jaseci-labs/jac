import asyncio;
import hashlib;
import hmac;
import secrets;
import time;
import from base64 { urlsafe_b64decode, urlsafe_b64encode }
import from datetime { UTC, datetime }

glob SEAL_PREFIX: str = 'v1.',
     SEAL_NONCE_BYTES: int = 16,
     SEAL_TAG_BYTES: int = 32,
     REFRESH_SKEW_SECONDS: int = 60,
     REFRESH_LEASE_SECONDS: int = 45,
     REFRESH_POLL_SECONDS: float = 0.1,
     _active: dict[str, any] = {};


obj ConnectedAccount {
    has platform: str = '',
        external_id: str = '',
        scopes: list[str] = [],
        connected_at: str = '',
        refreshable: bool = False;
}


def _seal_keys(key_material: str) -> tuple[bytes, bytes];


def _keystream(key: bytes, nonce: bytes, length: int) -> bytes;


def _seal_tag(mac_key: bytes, context: str, nonce: bytes, body: bytes) -> bytes;


def seal_secret(plain: str, key_material: str = '', context: str = '') -> str;


def unseal_secret(sealed: str, key_material: str = '', context: str = '') -> str;


def _grant_context(user_id: str, platform: str) -> str;


def _grant_secret(user_id: str, grant: dict[str, any], field: str) -> str;


def grant_from_tokens(
    user_id: str,
    platform: str,
    external_id: str,
    payload: dict[str, any],
    requested: list[str],
    previous: (dict[str, any] | None) = None,
    now: float = 0.0
) -> dict[str, any];


def connected_account(grant: dict[str, any]) -> ConnectedAccount;


def register_sso(auth: SSOAuth) -> None;


async def _refresh_claimed(
    auth: any,
    user_id: str,
    platform: str,
    grant: dict[str, any],
    refresh: str,
    version: int
) -> str;


async def access_token_for(user_id: str, platform: str) -> str;


def connections_for(user_id: str) -> list[ConnectedAccount];


async def disconnect_for(user_id: str, platform: str) -> bool;


async def sso_access_token(platform: str) -> str;


def sso_connections -> list[ConnectedAccount];


async def sso_disconnect(platform: str) -> bool;
