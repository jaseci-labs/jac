import contextlib;
import hmac;
import json;
import os;
import secrets;
import time;
import from urllib.parse { parse_qs, quote, urlparse }

glob LOOPBACK_HOSTS: frozenset = frozenset({"127.0.0.1", "localhost", "::1"});

glob SAME_SITE_VALUES: frozenset = frozenset({"same-origin", "none"});

glob DEFAULT_PREFIX: str = "/__jac",
     ALLOWED_PLATFORMS: tuple[str, ...] = ("google", "github", "apple"),
     ALLOWED_OPERATIONS: tuple[str, ...] = ("login", "register"),
     CLOSE_PAGE: str = "<!doctype html><meta charset=utf-8><title>{heading}</title>"
         + "<body style='font-family:system-ui,sans-serif;text-align:center;margin-top:4rem'>"
         + "<h2>{heading}</h2><p>{body}</p>"
         + "<p style='color:#888'>You can close this window and return to the app.</p>";


class SessionStore {
    def init(self: SessionStore, path: str);
    def read(self: SessionStore) -> str;
    def write(self: SessionStore, token: str);
    def clear(self: SessionStore);
}


class PendingAuth {
    with entry {
        states: dict[str, float];
    }

    def init(self: PendingAuth, ttl_seconds: float = 600.0, max_entries: int = 16);
    def _prune(self: PendingAuth);
    def issue(self: PendingAuth) -> str;
    def consume(self: PendingAuth, nonce: str) -> bool;
}


def build_sso_login_url(
    api_base: str, platform: str, client_callback: str, operation: str = "login"
) -> str;
