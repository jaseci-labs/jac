import contextlib;
import hmac;
import http.server;
import json;
import os;
import queue;
import secrets;
import time;
import webbrowser;
import from collections.abc { Callable }
import from urllib.parse { parse_qs, quote, urlparse }

glob _LOOPBACK_HOSTS: frozenset = frozenset({"127.0.0.1", "localhost", "::1"});

glob _SAME_SITE_VALUES: frozenset = frozenset({"same-origin", "none"});

glob DEFAULT_PREFIX: str = "/__jac",
     ALLOWED_PLATFORMS: tuple = ("google", "github", "apple"),
     ALLOWED_OPERATIONS: tuple = ("login", "register"),
     _CLOSE_PAGE: str = "<!doctype html><meta charset=utf-8><title>{heading}</title>" + "<body style='font-family:system-ui,sans-serif;text-align:center;margin-top:4rem'>" + "<h2>{heading}</h2><p>{body}</p>" + "<p style='color:#888'>You can close this window and return to the app.</p>";


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


class _PendingAuth {
    def init(self: _PendingAuth, ttl_seconds: float = 600.0, max_entries: int = 16) {
        self.ttl = ttl_seconds;
        self.max_entries = max_entries;

        self.states = {};
    }

    def _prune(self: _PendingAuth) {
        now = time.monotonic();
        stale = [];
        for (nonce, deadline) in self.states.items() {
            if deadline < now {
                stale.append(nonce);
            }
        }
        for nonce in stale {
            self.states.pop(nonce, None);
        }
    }

    def issue(self: _PendingAuth) -> str {
        self._prune();

        while len(self.states) >= self.max_entries {
            oldest = None;
            oldest_deadline = None;
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

    def consume(self: _PendingAuth, nonce: str) -> bool {
        if not nonce {
            return False;
        }
        self._prune();
        matched = None;
        for known in list(self.states.keys()) {
            if hmac.compare_digest(known, nonce) {
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


def make_handler(
    directory: str,
    tok_store: SessionStore,
    opener: Callable = webbrowser.open,
    prefix: str = DEFAULT_PREFIX,
    dispatch: Callable | None = None,
    events: object | None = None,
    sv_bridge: Callable | None = None
) -> type {
    pending = _PendingAuth();

    class _BrokerHandler(http.server.SimpleHTTPRequestHandler) {
        def init(self: _BrokerHandler, *args: object, **kwargs: object) {
            super.__init__(*args, directory=directory, **kwargs);
        }

        def log_message(self: _BrokerHandler, *args: object) -> None {
            return;
        }

        def _json(self: _BrokerHandler, body: object, status: int = 200) {
            payload = json.dumps(body).encode("utf-8");
            self.send_response(status);
            self.send_header("Content-Type", "application/json");
            self.send_header("Content-Length", str(len(payload)));
            self.end_headers();
            self.wfile.write(payload);
        }

        def _raw_json(self: _BrokerHandler, raw: str, status: int = 200) {
            payload = raw.encode("utf-8");
            self.send_response(status);
            self.send_header("Content-Type", "application/json");
            self.send_header("Content-Length", str(len(payload)));
            self.end_headers();
            self.wfile.write(payload);
        }

        def _raw_response(
            self: _BrokerHandler,
            body: str,
            status: int = 200,
            content_type: str = "application/json"
        ) {
            payload = body.encode("utf-8");
            self.send_response(status);
            self.send_header("Content-Type", content_type);
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

        def _read_json_body(self: _BrokerHandler) -> dict | None {
            try {
                n = int(self.headers.get("Content-Length", 0) or 0);
            } except (TypeError, ValueError) {
                n = 0;
            }

            if n > 1048576 {
                self.send_error(413);
                return None;
            }
            raw = self.rfile.read(n) if n > 0 else b"";
            try {
                data = json.loads(raw or b"{}");
            } except ValueError {
                return {};
            }
            return data if isinstance(data, dict) else {};
        }

        def _host_allowed(self: _BrokerHandler) -> bool {
            raw = self.headers.get("Host");
            if not raw {
                return True;
            }
            try {
                host = urlparse("//" + raw).hostname;
            } except Exception {
                return False;
            }
            return host in _LOOPBACK_HOSTS;
        }

        def _reject_foreign_host(self: _BrokerHandler) -> bool {
            if self._host_allowed() {
                return False;
            }
            self.send_error(403, "forbidden host");
            return True;
        }

        def _origin_allowed(self: _BrokerHandler) -> bool {
            origin = self.headers.get("Origin");
            if origin {
                try {
                    host = urlparse(origin).hostname;
                } except Exception {
                    return False;
                }

                if host not in _LOOPBACK_HOSTS {
                    return False;
                }
            }
            site = self.headers.get("Sec-Fetch-Site");
            if site and site not in _SAME_SITE_VALUES {
                return False;
            }
            return True;
        }

        def _reject_cross_site(self: _BrokerHandler) -> bool {
            if self._origin_allowed() {
                return False;
            }
            self.send_error(403, "cross-site request blocked");
            return True;
        }

        def _callback_url(self: _BrokerHandler, state: str) -> str {
            fallback = f"127.0.0.1:{self.server.server_address[1]}";
            host = self.headers.get("Host") or fallback;
            return f"http://{host}{prefix}/oauth/callback/{state}";
        }

        def do_GET(self: _BrokerHandler) -> None {
            if self._reject_foreign_host() {
                return;
            }
            route = urlparse(self.path).path;
            cb_route = prefix + "/oauth/callback";
            is_callback = route == cb_route or route.startswith(cb_route + "/");

            if route.startswith(prefix)
            and not is_callback
            and self._reject_cross_site() {
                return;
            }
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
            if is_callback {
                state = route[len(cb_route) + 1:]
                    if route.startswith(cb_route + "/")
                    else "";
                self._oauth_callback(state);
                return;
            }
            if route == prefix + "/events" {
                self._sse_events();
                return;
            }
            super.do_GET();
        }

        def _sse_events(self: _BrokerHandler) -> None {
            if events is None {
                self.send_error(404);
                return;
            }

            q = events.subscribe();
            if q is None {
                self.send_error(503);
                return;
            }
            self.send_response(200);
            self.send_header("Content-Type", "text/event-stream");
            self.send_header("Cache-Control", "no-cache");
            self.send_header("Connection", "keep-alive");

            self.send_header("X-Accel-Buffering", "no");
            self.end_headers();
            try {
                self.wfile.write(b": connected\n\n");
                self.wfile.flush();
                while True {
                    try {
                        msg = q.get(timeout=15);
                    } except queue.Empty {
                        self.wfile.write(b": keepalive\n\n");
                        self.wfile.flush();
                        continue;
                    }
                    if msg is None {
                        break;
                    }
                    self.wfile.write(("data: " + msg + "\n\n").encode("utf-8"));
                    self.wfile.flush();
                }
            } except (BrokenPipeError, ConnectionResetError, OSError) { } finally {
                events.unsubscribe(q);
            }
        }

        def do_POST(self: _BrokerHandler) -> None {
            if self._reject_foreign_host() {
                return;
            }

            if self._reject_cross_site() {
                return;
            }
            route = urlparse(self.path).path;
            if route == prefix + "/session" {
                body = self._read_json_body();
                if body is None {
                    return;
                }
                token = str(body.get("token", "") or "");
                tok_store.write(token);
                self._json({"ok": True});
                return;
            }
            if route == prefix + "/invoke" {
                if dispatch is None {
                    self.send_error(404);
                    return;
                }
                try {
                    n = int(self.headers.get("Content-Length", 0) or 0);
                } except (TypeError, ValueError) {
                    n = 0;
                }

                if n > 1048576 {
                    self.send_error(413);
                    return;
                }
                raw = self.rfile.read(n) if n > 0 else b"";
                body = raw.decode("utf-8") if raw else "[]";
                self._raw_json(dispatch(body));
                return;
            }
            if sv_bridge is not None
            and (route.startswith("/walker/") or route.startswith("/function/")) {
                try {
                    n = int(self.headers.get("Content-Length", 0) or 0);
                } except (TypeError, ValueError) {
                    n = 0;
                }
                if n > 1048576 {
                    self.send_error(413);
                    return;
                }
                raw = self.rfile.read(n) if n > 0 else b"";
                auth = self.headers.get("Authorization", "") or "";
                token = auth[7:] if auth.startswith("Bearer ") else "";
                (status, sv_body, ctype) = sv_bridge("POST", route, raw, token);
                self._raw_response(sv_body, status, ctype);
                return;
            }
            self.send_error(404);
        }

        def do_DELETE(self: _BrokerHandler) -> None {
            if self._reject_foreign_host() {
                return;
            }

            if self._reject_cross_site() {
                return;
            }
            route = urlparse(self.path).path;
            if route == prefix + "/session" {
                tok_store.clear();
                self._json({"ok": True});
                return;
            }
            self.send_error(404);
        }

        def _oauth_start(self: _BrokerHandler) -> None {
            q = parse_qs(urlparse(self.path).query);
            platform = (q.get("platform", [""])[0] or "").strip();
            api_base = (q.get("api_base", [""])[0] or "").strip();
            operation = (q.get("operation", ["login"])[0] or "login").strip();
            state = pending.issue();
            try {
                url = build_sso_login_url(
                    api_base, platform, self._callback_url(state), operation
                );
            } except ValueError as e {
                pending.consume(state);
                self._json({"ok": False, "error": str(e)}, status=400);
                return;
            }

            tok_store.clear();
            try {
                opener(url);
            } except Exception as e {
                self._json({"ok": False, "error": f"open_failed: {e}"}, status=500);
                return;
            }
            self._json({"ok": True, "login_url": url});
        }

        def _oauth_callback(self: _BrokerHandler, state: str) -> None {
            q = parse_qs(urlparse(self.path).query);
            token = (q.get("token", [""])[0] or "").strip();
            error = (q.get("error", [""])[0] or "").strip();

            if not pending.consume(state) {
                self._html(
                    _CLOSE_PAGE.format(
                        heading="Sign-in failed",
                        body="This sign-in link is invalid or has expired."
                    ),
                    status=400
                );
                return;
            }
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
