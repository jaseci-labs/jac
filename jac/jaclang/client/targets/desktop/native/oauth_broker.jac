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
     ALLOWED_PLATFORMS: tuple = ("google", "github", "apple"),
     ALLOWED_OPERATIONS: tuple = ("login", "register"),
     CLOSE_PAGE: str = "<!doctype html><meta charset=utf-8><title>{heading}</title>"
         + "<body style='font-family:system-ui,sans-serif;text-align:center;margin-top:4rem'>"
         + "<h2>{heading}</h2><p>{body}</p>"
         + "<p style='color:#888'>You can close this window and return to the app.</p>";


class SessionStore {
    def init(self: SessionStore, path: str) {
        self.path = path;
    }

    def read(self: SessionStore) -> str {
        try {
            with open(self.path, encoding="utf-8") as f {
                return str(json.load(f).get("token", "") or "");
            }
        } except (OSError, ValueError) {
            return "";
        }
    }

    def write(self: SessionStore, token: str) {
        token = token or "";
        os.makedirs(os.path.dirname(os.path.abspath(self.path)), exist_ok=True);
        tmp = self.path + ".tmp";
        with open(tmp, "w", encoding="utf-8") as f {
            json.dump({"token": token}, f);
        }
        os.replace(tmp, self.path);
    }

    def clear(self: SessionStore) {
        with contextlib.suppress(OSError) {
            os.remove(self.path);
        }
    }
}


class PendingAuth {
    with entry {
        states: dict[str, float];
    }

    def init(self: PendingAuth, ttl_seconds: float = 600.0, max_entries: int = 16) {
        self.ttl = ttl_seconds;
        self.max_entries = max_entries;

        self.states = {};
    }

    def _prune(self: PendingAuth) {
        now = time.monotonic();
        stale: list[str] = [];
        for (nonce, deadline) in self.states.items() {
            if deadline < now {
                stale.append(nonce);
            }
        }
        for nonce in stale {
            self.states.pop(nonce, None);
        }
    }

    def issue(self: PendingAuth) -> str {
        self._prune();

        while len(self.states) >= self.max_entries {
            oldest: (str | None) = None;
            oldest_deadline: (float | None) = None;
            for (nonce, deadline) in self.states.items() {
                if oldest_deadline is None or deadline < oldest_deadline {
                    oldest = nonce;
                    oldest_deadline = deadline;
                }
            }
            if oldest is None {
                break;
            }
            self.states.pop(oldest, None);
        }
        nonce = secrets.token_urlsafe(32);
        self.states[nonce] = time.monotonic() + self.ttl;
        return nonce;
    }

    def consume(self: PendingAuth, nonce: str) -> bool {
        if not nonce {
            return False;
        }
        self._prune();
        matched: (str | None) = None;
        for known in list(self.states.keys()) {
            if hmac.compare_digest(known.encode("utf-8"), nonce.encode("utf-8")) {
                matched = known;
                break;
            }
        }
        if matched is None {
            return False;
        }
        deadline = self.states.pop(matched, None);
        if deadline is None {
            return False;
        }
        return time.monotonic() <= deadline;
    }
}


def build_sso_login_url(
    api_base: str, platform: str, client_callback: str, operation: str = "login"
) -> str {
    if platform not in ALLOWED_PLATFORMS {
        raise ValueError(f"unsupported platform: {platform}");
    }
    if operation not in ALLOWED_OPERATIONS {
        raise ValueError(f"unsupported operation: {operation}");
    }
    base = (api_base or "").rstrip("/");
    if not base {
        raise ValueError("api_base is required");
    }
    cb = quote(client_callback, safe="");
    return f"{base}/sso/{platform}/{operation}?client_callback={cb}";
}
