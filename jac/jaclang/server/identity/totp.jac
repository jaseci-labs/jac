import base64;
import hashlib;
import hmac;
import secrets;
import struct;
import time;
import from urllib.parse { quote }

glob TOTP_DIGITS: int = 6,
     TOTP_PERIOD_SECONDS: int = 30,
     TOTP_SKEW_STEPS: int = 1,
     TOTP_SECRET_BYTES: int = 20;


def new_totp_secret -> str;


def totp_key(secret: str) -> bytes;


def totp_code(secret: str, step: int) -> str;


def totp_step(at: (float | None) = None) -> int;


def normalized_code(code: any) -> str;


def matching_step(secret: str, code: any, at: (float | None) = None) -> (int | None);


def provisioning_uri(secret: str, account: str, issuer: str) -> str;
