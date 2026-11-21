---
description: The native http package - http.client's connections and responses over HTTP and HTTPS, http.server's servers and request handlers, http.cookies and http.cookiejar, and HTTPStatus - with what each has and how it differs from CPython's.
keywords: http, http.HTTPStatus, HTTPStatus, http.client, http.client.HTTPConnection, HTTPConnection, http.client.HTTPSConnection, HTTPSConnection, http.client.HTTPResponse, http.client.responses, http.client.HTTPException, http.server, http.server.HTTPServer, http.server.ThreadingHTTPServer, http.server.HTTPSServer, http.server.BaseHTTPRequestHandler, BaseHTTPRequestHandler, http.server.SimpleHTTPRequestHandler, http.cookies, http.cookies.SimpleCookie, SimpleCookie, http.cookies.Morsel, http.cookiejar, http.cookiejar.CookieJar, http.cookiejar.MozillaCookieJar, HTTP client, HTTP server, cookies
---
# http

The `http` package is native, with the names and behavior of CPython 3.15's (see
[The library](index.md), `jac docs library`):

| Module | What it has |
|---|---|
| `http` | `HTTPStatus`, the status codes as an int enum |
| `http.client` | `HTTPConnection`, `HTTPSConnection` and `HTTPResponse`: the client side of HTTP/1.1 |
| `http.server` | `HTTPServer`, `HTTPSServer` and their threading forms, `BaseHTTPRequestHandler`, `SimpleHTTPRequestHandler` |
| `http.cookies` | `SimpleCookie`, `BaseCookie`, `Morsel`: the `Cookie` and `Set-Cookie` headers |
| `http.cookiejar` | `CookieJar` and its file forms, and the policies that decide which cookies a client keeps |

They are written over [socket, socketserver and ssl](socket.md) and the [email](email.md)
package, whose `Message` holds a request's and a response's headers. [urllib](urllib.md) opens
URLs with them.

```jac
import http.client;
import http.cookies;
import http.server;
import threading;
import from http { HTTPStatus }

class Hello(http.server.BaseHTTPRequestHandler) {
    def do_GET -> None {
        if self.path == "/missing" {
            self.send_error(404, "No such page");
            return;
        }
        body = f"hello {self.path} from {self.headers['User-Agent']}".encode();
        self.send_response(200);
        self.send_header("Content-Type", "text/plain");
        self.send_header("Content-Length", str(len(body)));
        self.send_header("Set-Cookie", "session=abc123; Path=/; HttpOnly");
        self.end_headers();
        self.wfile.write(body);
    }

    override def log_message(format: str, *args: any) -> None {}
}

with entry {
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Hello);
    t = threading.Thread(target=srv.serve_forever, args=(0.01,));
    t.start();
    conn = http.client.HTTPConnection("127.0.0.1", srv.server_port, timeout=5.0);
    conn.request("GET", "/world", headers={"User-Agent": "docs"});
    resp = conn.getresponse();
    print(resp.status, resp.reason, resp.getheader("Content-Type"), resp.read());
    cookie = http.cookies.SimpleCookie(resp.getheader("Set-Cookie"));
    print(cookie["session"].value, cookie["session"]["path"], cookie["session"]["httponly"]);
    conn.request("GET", "/missing");
    resp = conn.getresponse();
    print(resp.status, resp.reason, len(resp.read()) > 0, resp.version);
    conn.close();
    srv.shutdown();
    t.join();
    srv.server_close();
    print(HTTPStatus.NOT_FOUND, repr(HTTPStatus.NOT_FOUND), http.client.responses[404]);
    print(http.client.NOT_FOUND == 404, HTTPStatus(200).name);
    jar = http.cookies.SimpleCookie();
    jar["theme"] = "dark";
    jar["theme"]["max-age"] = 3600;
    jar.load("lang=en; tz=UTC");
    print(sorted(jar.keys()), jar["theme"].OutputString());
    print(jar.output(["max-age"], "Cookie:", ", "));
}
```

```output
200 OK text/plain b'hello /world from docs'
abc123 / True
404 No such page True 10
404 <HTTPStatus.NOT_FOUND: 404> Not Found
True OK
['lang', 'theme', 'tz'] theme=dark; Max-Age=3600
Cookie: lang=en, Cookie: theme=dark; Max-Age=3600, Cookie: tz=UTC
```

The server runs in a thread ([threading](threading.md)) so that the program can be its own
client: `serve_forever` serves until `shutdown()`. A `ThreadingHTTPServer` answers each
request in a thread of its own; an `HTTPServer` takes one at a time.

## http.client

| Name | What it is |
|---|---|
| `HTTPConnection(host, port=None, timeout=..., source_address=None, blocksize=8192, *, max_response_headers=None)` | `request(method, url, body=None, headers={}, *, encode_chunked=False)`, or `putrequest`, `putheader`, `endheaders` and `send`; `getresponse`, `connect`, `close`, `set_tunnel`, `set_debuglevel` |
| `HTTPSConnection(host, port=None, *, timeout=..., source_address=None, context=None, blocksize=8192, max_response_headers=None)` | An `HTTPConnection` whose socket is wrapped by an [ssl](socket.md#ssl) context once it is connected: the one given, or one that verifies the server's certificate and host name against the system's CA certificates |
| `HTTPResponse` | A binary stream over the body, which decodes a chunked one and stops at the end of one with a length: `status`, `reason`, `version`, `headers` (`msg`), `getheader`, `getheaders`, `read`, `read1`, `readinto`, `readline`, `peek`, `geturl`, `info`, `getcode`, `isclosed`, `with` |
| `HTTPMessage`, `parse_headers` | A header block, as `email`'s `compat32` `Message` |
| `responses`, and `OK`, `NOT_FOUND`, ... | The reason phrase of each code; each code as the `HTTPStatus` member |
| `HTTPException`, `NotConnected`, `InvalidURL`, `RemoteDisconnected`, `IncompleteRead`, `BadStatusLine`, `LineTooLong`, `CannotSendRequest`, `ResponseNotReady`, ... | The exceptions |
| `HTTP_PORT`, `HTTPS_PORT` | 80 and 443 |

A body is `bytes`, a `str`, a file or an iterable of `bytes`, sent chunked when its length is not
known. A connection is opened by the first request and again after the server closes it.

## http.server

`HTTPServer(server_address, RequestHandlerClass)` is a `socketserver.TCPServer` that knows its
name (`server_name`, `server_port`).
`HTTPSServer(server_address, RequestHandlerClass, *, certfile, keyfile=None, password=None, alpn_protocols=None)`
serves over TLS with that certificate, and `ThreadingHTTPServer` and `ThreadingHTTPSServer`
give each request a thread of its own. A handler derives from `BaseHTTPRequestHandler` and
declares a `do_<METHOD>` method for each method it answers (`do_GET`, `do_POST`, ...), found by
its name as a request comes; one it lacks is answered 501. In it:

| Name | What it is |
|---|---|
| `command`, `path`, `request_version`, `headers`, `rfile`, `wfile`, `client_address`, `server` | The request, and the connection's files |
| `send_response(code, message=None)`, `send_header(keyword, value)`, `end_headers()`, `send_error(code, message=None, explain=None)`, `send_response_only`, `flush_headers` | The answer |
| `log_request`, `log_error`, `log_message(format, *args)` | A line to stderr for each request; override `log_message` to send it elsewhere |
| `protocol_version`, `server_version`, `error_message_format`, `error_content_type`, `responses`, `version_string`, `date_time_string`, `address_string` | As CPython's |

`SimpleHTTPRequestHandler` serves the files under a directory (`directory=`, the working
directory unless given) and lists a directory without an index page.

## http.cookies and http.cookiejar

A `SimpleCookie` maps each cookie's name to a `Morsel`, which holds its `value` and its
attributes (`path`, `domain`, `expires`, `max-age`, `secure`, `httponly`, `samesite`, ...).
`load` parses a `Cookie` header, and `output` writes `Set-Cookie` headers.

A `CookieJar` is the client's side: `extract_cookies(response, request)` keeps what a response
sets, by the rules of its `CookiePolicy` (`DefaultCookiePolicy`), and
`add_cookie_header(request)` gives a request the `Cookie` header it should send.
`urllib.request.HTTPCookieProcessor(jar)` does both for an opener ([urllib](urllib.md) has an
example). `MozillaCookieJar` and `LWPCookieJar` are `FileCookieJar`s that `save` and `load` the
cookies in a file, in the `cookies.txt` and the `Set-Cookie3` format.

## Differences from CPython

- **`HTTPStatus`'s members are their codes and no more.** A Jac enum member carries one value,
  so `phrase`, `description` and the `is_success` family are not there (E1030): read the phrase
  from `http.client.responses[code]`. The four old aliases (`REQUEST_ENTITY_TOO_LARGE`,
  `REQUEST_URI_TOO_LONG`, `REQUESTED_RANGE_NOT_SATISFIABLE`, `UNPROCESSABLE_ENTITY`) are not
  there either: use `CONTENT_TOO_LARGE`, `URI_TOO_LONG`, `RANGE_NOT_SATISFIABLE` and
  `UNPROCESSABLE_CONTENT`. `http.HTTPMethod`, a str enum, is not there (E1145).
- **`Morsel` and `BaseCookie` are not dicts.** They are mappings of their own, with indexing,
  `in`, iteration, `len`, `keys`, `values`, `items`, `get`, `pop` and the rest as a dict's, but
  `isinstance(cookie, dict)` is `False`.
- **A server's and a handler's class attributes are fields**, as in `socketserver`: a subclass
  declares the field again with its own default (`has protocol_version: str = "HTTP/1.1";`).
- **`log_message` writes plain lines**, without the colours CPython gives them on a terminal.
- **`HTTPSServer.ssl` is left out** (E5142): it is the `ssl` module, kept on the server, and a
  Jac module is not a value. A subclass that makes its own context imports `ssl`.

For a server of a Jac application, with routing, sessions and a client, see
[Servers](../apps/server.md) (`jac docs apps/server`).

## Where to go next

- URLs, and opening one in a call: [urllib](urllib.md).
- The layer below: [socket, socketserver and ssl](socket.md).
- Every native module: [Standard-library modules](stdlib.md).
