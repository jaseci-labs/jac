"""Loopback OAuth + session broker for the Jac-native desktop shell.

The desktop app serves its UI from `http://127.0.0.1:<port>` (a loopback origin)
inside an OS webview. OAuth/SSO providers refuse to render their login pages in
an embedded webview and only redirect to a registered *server* URL, so the token
cannot be handed to the webview directly. This broker bridges that gap using the
one thing the webview and the system browser share: this loopback HTTP server.

Flow (RFC 8252, "OAuth 2.0 for Native Apps"):

1. The UI calls `GET /__jac/oauth/start?platform=<p>&api_base=<url>`. The broker
   opens the *system browser* at `<api_base>/sso/<p>/login`, passing this
   server's own `/__jac/oauth/callback` as the `client_callback`.
2. The provider authenticates the user and redirects to the app server, which
   mints a token and -- because `client_callback` is a validated loopback URL
   (see `is_safe_loopback_redirect` on the server) -- redirects the browser to
   `/__jac/oauth/callback?token=...` here.
3. The broker stores the token; the UI polls `GET /__jac/session` to pick it up
   and writes it into `localStorage` on its own origin.

The session store also persists the token to disk, so a logged-in session
survives an app restart even though the loopback port -- and therefore the
origin -- changes on every launch.

This module is transpiled to dependency-free Python (`jac jac2py`) at build time
and shipped beside the binary: the desktop host's embedded CPython has only the
stdlib (no jaclang), so the broker stays pure-stdlib. Tests import it directly.
"""

import contextlib;
import http.server;
import json;
import os;
import webbrowser;
import from collections.abc { Callable }
import from urllib.parse { parse_qs, quote, urlparse }

glob DEFAULT_PREFIX: str = "/__jac",
     # Providers the desktop shell knows how to start. Kept in lockstep with
     # jac_scale.enums.Platforms; an unknown value is rejected before we ever open a
     # browser so a crafted `platform` can't be reflected into the login URL.
     ALLOWED_PLATFORMS: tuple = ("google", "github", "apple"),
     _CLOSE_PAGE: str = "<!doctype html><meta charset=utf-8><title>{heading}</title>" + "<body style='font-family:system-ui,sans-serif;text-align:center;margin-top:4rem'>" + "<h2>{heading}</h2><p>{body}</p>" + "<p style='color:#888'>You can close this window and return to the app.</p>";


"""A tiny JSON-file token store (one token per app install).

Kept out of the served `dist/` directory so the token is never reachable over
HTTP as a static file.
"""
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
        os.replace(tmp, self.path);  # atomic on POSIX/NTFS
    }

    def clear(self: SessionStore) {
        with contextlib.suppress(OSError) {
            os.remove(self.path);
        }
    }
}


"""Build the app server's SSO-initiate URL carrying the loopback callback.

Raises `ValueError` on an unknown platform or empty `api_base` so the caller
fails before opening a browser.
"""
def build_sso_login_url(api_base: str, platform: str, client_callback: str) -> str {
    if platform not in ALLOWED_PLATFORMS {
        raise ValueError(f"unsupported platform: {platform}");
    }
    base = (api_base or "").rstrip("/");
    if not base {
        raise ValueError("api_base is required");
    }
    cb = quote(client_callback, safe="");
    return f"{base}/sso/{platform}/login?client_callback={cb}";
}


"""Build a request handler that serves `directory` plus the broker routes.

`opener(url)` opens the system browser (default `webbrowser.open`); tests pass a
recorder. `tok_store` is a SessionStore.
"""
def make_handler(
    directory: str,
    tok_store: SessionStore,
    opener: Callable = webbrowser.open,
    prefix: str = DEFAULT_PREFIX
) -> type {
    class _BrokerHandler(http.server.SimpleHTTPRequestHandler) {
        def init(self: _BrokerHandler, *args: object, **kwargs: object) {
            super.__init__(*args, directory=directory, **kwargs);
        }

        # The host owns user-facing logging; keep request logging quiet.
        def log_message(self: _BrokerHandler, *args: object) -> None {
            return;
        }

        # ---- small response helpers ----
        def _json(self: _BrokerHandler, body: object, status: int = 200) {
            payload = json.dumps(body).encode("utf-8");
            self.send_response(status);
            self.send_header("Content-Type", "application/json");
            self.send_header("Content-Length", str(len(payload)));
            self.end_headers();
            self.wfile.write(payload);
        }

        def _html(self: _BrokerHandler, html: str, status: int = 200) {
            payload = html.encode("utf-8");
            self.send_response(status);
            self.send_header("Content-Type", "text/html; charset=utf-8");
            self.send_header("Content-Length", str(len(payload)));
            self.end_headers();
            self.wfile.write(payload);
        }

        def _read_json_body(self: _BrokerHandler) -> dict {
            try {
                n = int(self.headers.get("Content-Length", 0) or 0);
            } except (TypeError, ValueError) {
                n = 0;
            }
            raw = self.rfile.read(n) if n > 0 else b"";
            try {
                data = json.loads(raw or b"{}");
            } except ValueError {
                return {};
            }
            return data if isinstance(data, dict) else {};
        }

        def _callback_url(self: _BrokerHandler) -> str {
            # Derive the callback from the request's Host so it always matches
            # the OS-assigned loopback port the UI reached us on.
            fallback = f"127.0.0.1:{self.server.server_address[1]}";
            host = self.headers.get("Host") or fallback;
            return f"http://{host}{prefix}/oauth/callback";
        }

        # ---- routing ----
        def do_GET(self: _BrokerHandler) -> None {
            route = urlparse(self.path).path;
            if route == prefix + "/health" {
                self._json({"ok": True});
                return;
            }
            if route == prefix + "/session" {
                self._json({"token": tok_store.read()});
                return;
            }
            if route == prefix + "/oauth/start" {
                self._oauth_start();
                return;
            }
            if route == prefix + "/oauth/callback" {
                self._oauth_callback();
                return;
            }
            super.do_GET();
        }

        def do_POST(self: _BrokerHandler) -> None {
            route = urlparse(self.path).path;
            if route == prefix + "/session" {
                token = str(self._read_json_body().get("token", "") or "");
                tok_store.write(token);
                self._json({"ok": True});
                return;
            }
            self.send_error(404);
        }

        def do_DELETE(self: _BrokerHandler) -> None {
            route = urlparse(self.path).path;
            if route == prefix + "/session" {
                tok_store.clear();
                self._json({"ok": True});
                return;
            }
            self.send_error(404);
        }

        # ---- broker actions ----
        def _oauth_start(self: _BrokerHandler) -> None {
            q = parse_qs(urlparse(self.path).query);
            platform = (q.get("platform", [""])[0] or "").strip();
            api_base = (q.get("api_base", [""])[0] or "").strip();
            try {
                url = build_sso_login_url(api_base, platform, self._callback_url());
            } except ValueError as e {
                self._json({"ok": False, "error": str(e)}, status=400);
                return;
            }
            try {
                opener(url);
            } except Exception as e {  # browser launch is best-effort
                self._json({"ok": False, "error": f"open_failed: {e}"}, status=500);
                return;
            }
            self._json({"ok": True, "login_url": url});
        }

        def _oauth_callback(self: _BrokerHandler) -> None {
            q = parse_qs(urlparse(self.path).query);
            token = (q.get("token", [""])[0] or "").strip();
            error = (q.get("error", [""])[0] or "").strip();
            if token {
                tok_store.write(token);
                self._html(
                    _CLOSE_PAGE.format(
                        heading="Signed in", body="Authentication complete."
                    )
                );
                return;
            }
            msg = error or "No token was returned.";
            self._html(
                _CLOSE_PAGE.format(heading="Sign-in failed", body=msg), status=400
            );
        }
    }
    return _BrokerHandler;
}
