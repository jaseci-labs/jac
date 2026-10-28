import hashlib;
import hmac;
import logging;
import secrets;
import time;
import from base64 { urlsafe_b64decode, urlsafe_b64encode }
import from json { dumps, loads }


glob SCRYPT_N: int = 16384,
     SCRYPT_MAX_N: int = 32768,
     SCRYPT_R: int = 8,
     SCRYPT_P: int = 1,
     SCRYPT_DKLEN: int = 64,
     SCRYPT_SALT_BYTES: int = 16,
     SCRYPT_MAXMEM: int = 48 * 1024 * 1024,
     _BCRYPT_PREFIXES: tuple[str, ...] = ('$2a$', '$2b$', '$2y$'),
     _SHA256_HEX_LEN: int = 64,
     _HEX_DIGITS: str = '0123456789abcdef',
     PLACEHOLDER_JWT_SECRET: str = 'supersecretkey_for_testing_only!',
     DEV_SECRET_FILENAME: str = 'jwt_secret',
     DEV_SECRET_BYTES: int = 48,
     _legacy_warned: set[str] = set(),
     logger = logging.getLogger(__name__);


def is_prescrypt_hash(stored: str) -> bool;


def is_legacy_sha256_hash(stored: str) -> bool;


def needs_rehash(stored: str) -> bool;


def project_data_dir(base_path: str) -> str;


def project_signing_secret(base_path: str) -> str;


def _unpersistable_secret(path: str, reason: str) -> str;


def _persist_secret(data_dir: str, path: str, minted: str);


def _read_secret(path: str) -> str;


def _warn_once(key_material: str, message: str) -> None;


obj JWTError(Exception) {
    has reason: str = 'invalid token';

    def __str__ -> str;
}

obj JWTExpiredError(JWTError) {}

def _ac_json_default(o: any) -> str;

def _b64url_encode(data: bytes) -> str;

def _b64url_decode(text: str) -> bytes;

def _normalize_claims(payload: dict[str, any]) -> dict[str, any];

def jwt_encode(payload: dict[str, any], secret: str, algorithm: str = 'HS256') -> str;

def jwt_decode(
    token: str,
    secret: str,
    algorithms: (list[str] | None) = None,
    verify_exp: bool = True
) -> dict[str, any];

def hash_password(password: str, n: int = SCRYPT_N) -> str;

def verify_password(password: str, stored: str) -> bool;
