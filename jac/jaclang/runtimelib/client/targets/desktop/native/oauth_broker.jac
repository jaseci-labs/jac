"""Loopback OAuth + session broker for the Jac-native desktop shell.

The desktop app serves its UI from `http://127.0.0.1:<port>` (a loopback origin)
inside an OS webview. OAuth/SSO providers refuse to render their login pages in
an embedded webview and only redirect to a registered *server* URL, so the token
cannot be handed to the webview directly. This broker bridges that gap using the
one thing the webview and the system browser share: this loopback HTTP server.

Flow (RFC 8252, "OAuth 2.0 for Native Apps"):

1. The UI calls `GET /__jac/oauth/start?platform=<p>&api_base=<url>`. The broker
   mints a single-use `state` nonce, clears any stale session token, and opens
   the *system browser* at `<api_base>/sso/<p>/login`, passing this server's own
   `/__jac/oauth/callback/<nonce>` as the `client_callback` (the nonce rides in
   the path because the server appends `?token=...` to the callback verbatim).
2. The provider authenticates the user and redirects to the app server, which
   mints a token and -- because `client_callback` is a validated loopback URL
   (see `is_safe_loopback_redirect` on the server) -- redirects the browser to
   `/__jac/oauth/callback/<nonce>?token=...` here.
3. The broker checks the nonce (single-use, expiring) before storing the token,
   so an unrelated page in the system browser cannot inject one. The UI polls
   `GET /__jac/session` to pick the token up and writes it into `localStorage`
   on its own origin.

The session store also persists the token to disk, so a logged-in session
survives an app restart even though the loopback port -- and therefore the
origin -- changes on every launch.

All routes are pinned to a loopback `Host` header so a DNS-rebinding page cannot
reach the broker as same-origin and read the token from `/session`.

This module is transpiled to dependency-free Python (`jac jac2py`) at build time
and shipped beside the binary: the desktop host's embedded CPython has only the
stdlib (no jaclang), so the broker stays pure-stdlib. Tests import it directly.
"""

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

# Hosts that resolve to this machine. Every request's `Host` header must be one
# of these (see `_host_allowed`) so a DNS-rebinding page -- which arrives with
# its own hostname in `Host` -- cannot become same-origin and read the token.
glob _LOOPBACK_HOSTS: frozenset = frozenset({"127.0.0.1", "localhost", "::1"});

glob DEFAULT_PREFIX: str = "/__jac",
     # Providers the desktop shell knows how to start. Kept in lockstep with
     # jac_scale.enums.Platforms; an unknown value is rejected before we ever open a
     # browser so a crafted `platform` can't be reflected into the login URL.
     ALLOWED_PLATFORMS: tuple = ("google", "github", "apple"),
     # SSO operations the server exposes at /sso/<platform>/<operation>. Validated
     # before the URL is built so a crafted `operation` can't be reflected either.
     ALLOWED_OPERATIONS: tuple = ("login", "register"),
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


"""In-memory, single-use store of pending OAuth `state` nonces (RFC 6749 sec.
10.12 / RFC 8252).

Each `/oauth/start` mints a high-entropy nonce that is embedded in the loopback
`client_callback` path; the matching `/oauth/callback/<nonce>` must present it
back. This binds a token-bearing callback to a flow this process actually
started, so an unrelated page open in the system browser cannot inject (or
replay) a token by hitting the callback URL. Nonces are single-use (consumed on
match), expire after a TTL, and live in memory only -- they must never persist
across a restart.
"""
class _PendingAuth {
    def init(self: _PendingAuth, ttl_seconds: float = 600.0, max_entries: int = 16) {
        self.ttl = ttl_seconds;
        self.max_entries = max_entries;
        # nonce -> monotonic deadline
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
            # `.pop` (not `del`) keeps this module dependency-free: jac lowers
            # `del subscript` to a jaclang runtime call the host can't import.
            self.states.pop(nonce, None);
        }
    }

    """Mint, store, and return a fresh single-use state nonce."""
    def issue(self: _PendingAuth) -> str {
        self._prune();
        # Bound the store so a burst of starts can't grow it without limit; drop
        # the soonest-to-expire entry to make room.
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

    """Whether `nonce` is one we issued and have not yet consumed or expired.

    Constant-time match (no early-out on a per-byte mismatch), then single-use
    removal so the same callback URL can never be replayed.
    """
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


"""Build the app server's SSO-initiate URL carrying the loopback callback.

Raises `ValueError` on an unknown platform or empty `api_base` so the caller
fails before opening a browser.
"""
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


"""Build a request handler that serves `directory` plus the broker routes.

`opener(url)` opens the system browser (default `webbrowser.open`); tests pass a
recorder. `tok_store` is a SessionStore.
"""
def make_handler(
    directory: str,
    tok_store: SessionStore,
    opener: Callable = webbrowser.open,
    prefix: str = DEFAULT_PREFIX,
    dispatch: Callable | None = None,
    events: object | None = None
) -> type {
    # Per-broker pending-flow store. Shared across all requests this server
    # handles (the same loopback process serves both the UI and the system
    # browser's callback), so the nonce issued at /oauth/start is visible to the
    # callback that comes back.
    pending = _PendingAuth();

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

        # Write an already-serialized JSON string verbatim (PluginHost.dispatch
        # returns its own JSON envelope; re-encoding would double-wrap it).
        def _raw_json(self: _BrokerHandler, raw: str, status: int = 200) {
            payload = raw.encode("utf-8");
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

        def _host_allowed(self: _BrokerHandler) -> bool {
            # Pin to loopback. A DNS-rebinding page reaches us with its own
            # hostname in `Host`; rejecting that stops it reading `/session` as
            # same-origin. A missing `Host` (a non-browser local client) is
            # allowed -- rebinding only happens through a browser, which always
            # sends one.
            raw = self.headers.get("Host");
            if not raw {
                return True;
            }
            try {
                # `urlparse("//host:port")` strips the port and brackets and
                # lowercases the host, matching is_safe_loopback_redirect on the
                # server side.
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

        def _callback_url(self: _BrokerHandler, state: str) -> str {
            # Derive the callback from the request's Host so it always matches
            # the OS-assigned loopback port the UI reached us on (Host is already
            # pinned to loopback by _host_allowed). The state nonce rides in the
            # path: the server appends `?token=...` to this URL verbatim, so a
            # query-string nonce would collide with it.
            fallback = f"127.0.0.1:{self.server.server_address[1]}";
            host = self.headers.get("Host") or fallback;
            return f"http://{host}{prefix}/oauth/callback/{state}";
        }

        # ---- routing ----
        def do_GET(self: _BrokerHandler) -> None {
            if self._reject_foreign_host() {
                return;
            }
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
            cb_route = prefix + "/oauth/callback";
            if route == cb_route or route.startswith(cb_route + "/") {
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

        # ---- server-sent events (host->JS push for the CEF target) ----
        # The page's EventSource subscribes here; the plugin host fans emit()/
        # eval_js() out to one queue.Queue per connection. Requires a threaded
        # server (the stream blocks for the connection's lifetime) -- the CEF
        # host uses ThreadingTCPServer. Loopback-pinned by _reject_foreign_host
        # above, same as every other route.
        def _sse_events(self: _BrokerHandler) -> None {
            if events is None {
                self.send_error(404);
                return;
            }
            # Each stream pins a server thread for its lifetime; refuse once the
            # subscriber pool is full so connections can't exhaust the host.
            q = events.subscribe();
            if q is None {
                self.send_error(503);
                return;
            }
            self.send_response(200);
            self.send_header("Content-Type", "text/event-stream");
            self.send_header("Cache-Control", "no-cache");
            self.send_header("Connection", "keep-alive");
            # Defeat proxy/output buffering so events flush immediately.
            self.send_header("X-Accel-Buffering", "no");
            self.end_headers();
            try {
                self.wfile.write(b": connected\n\n");
                self.wfile.flush();
                while True {
                    try {
                        msg = q.get(timeout=15);
                    } except queue.Empty {
                        # Periodic comment doubles as a dead-client probe.
                        self.wfile.write(b": keepalive\n\n");
                        self.wfile.flush();
                        continue;
                    }
                    if msg is None {
                        break;  # shutdown sentinel
                    }
                    self.wfile.write(("data: " + msg + "\n\n").encode("utf-8"));
                    self.wfile.flush();
                }
            } except (BrokenPipeError, ConnectionResetError, OSError) {
            # client disconnected; fall through to unsubscribe
            } finally {
                events.unsubscribe(q);
            }
        }

        def do_POST(self: _BrokerHandler) -> None {
            if self._reject_foreign_host() {
                return;
            }
            route = urlparse(self.path).path;
            if route == prefix + "/session" {
                token = str(self._read_json_body().get("token", "") or "");
                tok_store.write(token);
                self._json({"ok": True});
                return;
            }
            if route == prefix + "/invoke" {
                # JS->plugin bridge for the CEF target: the page's __jac_invoke
                # fetch shim POSTs the wire array [plugin, command, args] here and
                # we hand it straight to the in-process plugin host. dispatch()
                # owns parsing + the {ok/error} envelope and returns a JSON
                # string, so we echo it verbatim. _reject_foreign_host() above
                # already pins this to loopback, same as /session.
                if dispatch is None {
                    self.send_error(404);
                    return;
                }
                try {
                    n = int(self.headers.get("Content-Length", 0) or 0);
                } except (TypeError, ValueError) {
                    n = 0;
                }
                # Loopback-pinned, but still cap the body so a runaway/hostile
                # page can't drive the host OOM with one giant POST.
                if n > 1048576 {  # 1 MiB
                    self.send_error(413);
                    return;
                }
                raw = self.rfile.read(n) if n > 0 else b"";
                body = raw.decode("utf-8") if raw else "[]";
                self._raw_json(dispatch(body));
                return;
            }
            self.send_error(404);
        }

        def do_DELETE(self: _BrokerHandler) -> None {
            if self._reject_foreign_host() {
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

        # ---- broker actions ----
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
                # Release the just-issued nonce so a stream of bad requests can't
                # churn the (bounded) pending-state store.
                pending.consume(state);
                self._json({"ok": False, "error": str(e)}, status=400);
                return;
            }
            # A new flow supersedes any token already on disk, so the UI's session
            # poll can't read a previous login's token before this flow lands one
            # (re-login as a different user would otherwise keep the old token).
            tok_store.clear();
            try {
                opener(url);
            } except Exception as e {  # browser launch is best-effort
                self._json({"ok": False, "error": f"open_failed: {e}"}, status=500);
                return;
            }
            self._json({"ok": True, "login_url": url});
        }

        def _oauth_callback(self: _BrokerHandler, state: str) -> None {
            q = parse_qs(urlparse(self.path).query);
            token = (q.get("token", [""])[0] or "").strip();
            error = (q.get("error", [""])[0] or "").strip();
            # Bind this callback to a flow we started: only a live, single-use
            # nonce we issued is accepted. Without this, any page in the system
            # browser could navigate to the callback and inject (or replay) a
            # token into our session store.
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
