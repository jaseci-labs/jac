---
description: The native urllib package - urllib.parse's URLs, urllib.request's urlopen, openers and handlers, urllib.error, urllib.response and urllib.robotparser - with what each has and what is missing next to CPython's.
keywords: urllib, urllib.parse, urllib.request, urllib.error, urllib.response, urllib.robotparser, urlopen, urllib.request.urlopen, urllib.request.Request, urllib.request.build_opener, urllib.request.OpenerDirector, urllib.request.HTTPCookieProcessor, urllib.request.urlretrieve, urllib.error.URLError, urllib.error.HTTPError, RobotFileParser, urlsplit, urlparse, urlunsplit, urlunparse, urljoin, urldefrag, urlencode, quote, quote_plus, unquote, unquote_plus, parse_qs, parse_qsl
---
# urllib

Five native modules handle URLs and open them (see [The library](index.md),
`jac docs library`):

| Module | What it has |
|---|---|
| `urllib.parse` | All of CPython's `urllib.parse`: splitting, joining and quoting URLs, query strings |
| `urllib.request` | `urlopen`, `Request`, and the openers and handlers behind them: `http`, `https`, `ftp`, `file` and `data` URLs, redirects, proxies, authentication, cookies |
| `urllib.error` | `URLError`, `HTTPError`, `ContentTooShortError` |
| `urllib.response` | What `urlopen` returns: `addinfourl` and its bases |
| `urllib.robotparser` | `RobotFileParser`: what a `robots.txt` lets a crawler fetch |

`urllib` is a package with no module of its own: import the submodule (`import urllib.parse;`).
`import urllib;` is W1100. The connections are [http.client](http.md)'s, and
[ftplib](mailclients.md)'s for an `ftp` URL.

```jac
import from urllib.parse { urlsplit, urljoin, urlencode, quote, unquote, parse_qs }
import urllib.request;
import urllib.error;
import http.client;

with entry {
    u = urlsplit("HTTPS://user@Example.com:8443/a/b?q=1&r=two#frag");
    print(u.scheme, u.netloc, u.hostname, u.port, u.path, u.query, u.fragment);
    print(urljoin("http://a/b/c/d;p?q", "../g"), parse_qs("a=1&a=2&b=3"));
    print(urlencode({"q": "jac lang", "page": 2}), quote("a b/c"), unquote("%C3%A9"));
    print(http.client.responses[404]);
    with urllib.request.urlopen("data:text/plain;charset=utf-8,hello%20world") as resp {
        print(resp.read(), resp.headers["Content-Type"]);
    }
    try {
        urllib.request.urlopen("http://127.0.0.1:9/");
    } except urllib.error.URLError as e {
        print("URLError, an OSError:", isinstance(e, OSError));
    }
}
```

```output
https user@Example.com:8443 example.com 8443 /a/b q=1&r=two frag
http://a/b/g {'a': ['1', '2'], 'b': ['3']}
q=jac+lang&page=2 a%20b/c é
Not Found
b'hello world' text/plain;charset=utf-8
URLError, an OSError: True
```

## urllib.parse

Every function and result type of CPython's module: `urlsplit`, `urlparse`, `urlunsplit`,
`urlunparse`, `urljoin`, `urldefrag`, `quote`, `quote_plus`, `quote_from_bytes`, `unquote`,
`unquote_plus`, `unquote_to_bytes`, `parse_qs`, `parse_qsl`, `urlencode`, `unwrap`, the result
tuples (`SplitResult`, `ParseResult`, `DefragResult` and their bytes forms) and the scheme lists.
They behave as CPython 3.15's: the scheme and `hostname` are lower-cased but `netloc` is not,
bracketed hosts are checked (`ValueError: Invalid IPv6 URL`,
`ValueError: An IPv4 address cannot be in brackets`), `urlsplit` drops leading whitespace and
control characters and removes tabs and line breaks anywhere (`" http://ex\tample.com/"` is
split as `http://example.com/`), `.port` out of range raises
`ValueError: Port out of range 0-65535`, a result compares equal to a plain tuple, and `urljoin`
follows RFC 3986's examples.

Differences:

- **The functions take `str`.** `urlsplit(b"...")` is a compile error (E1053), as a Jac
  function has one return type. Decode the bytes first, and `encode()` the result for the
  bytes form.
- **`urlunsplit` and `urljoin` of parts that are not `str`**, and `urljoin("", None)`, raise
  `TypeError` where CPython returns another type. The `missing_as_none` parameter is not there.

## urllib.request and urllib.error

`urlopen(url, data=None, timeout=..., *, context=None)` opens a URL, or a `Request`: a GET, or a
POST when `data` is given. It follows redirects and returns the response: an
`http.client.HTTPResponse` for an `http` or `https` URL, an `addinfourl` for an `ftp`, a `file`
or a `data` URL. A response whose status is not a success raises `HTTPError`, which is also the
response: its body can be read. An `https` connection verifies the server's certificate and
host name against the system's CA certificates, or is made with the [ssl](socket.md#ssl)
context given as `context`. An `ftp` URL that ends in a file name gives the file, and one that
ends in `/` the directory's listing; a user and a password in the URL log in, and without
them the login is anonymous.

The example below is its own server, an [http.server](http.md) in a thread, so that it needs no
network:

```jac
import urllib.error;
import urllib.request;
import urllib.robotparser;
import http.cookiejar;
import http.server;
import threading;

class Site(http.server.BaseHTTPRequestHandler) {
    def do_GET -> None {
        if self.path != "/" {
            self.send_error(404);
            return;
        }
        body = f"cookie: {self.headers['Cookie']}".encode();
        self.send_response(200);
        self.send_header("Content-Length", str(len(body)));
        self.send_header("Set-Cookie", "session=abc123");
        self.end_headers();
        self.wfile.write(body);
    }

    def do_POST -> None {
        size = int(self.headers["Content-Length"]);
        body = self.rfile.read(size).upper();
        self.send_response(200);
        self.send_header("Content-Length", str(len(body)));
        self.end_headers();
        self.wfile.write(body);
    }

    override def log_message(format: str, *args: any) -> None {}
}

with entry {
    srv = http.server.HTTPServer(("127.0.0.1", 0), Site);
    t = threading.Thread(target=srv.serve_forever, args=(0.01,));
    t.start();
    base = f"http://127.0.0.1:{srv.server_port}";
    jar = http.cookiejar.CookieJar();
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar));
    for n in range(2) {
        with opener.open(base + "/", timeout=5.0) as resp {
            print(resp.status, resp.read(), [c.name for c in jar]);
        }
    }
    req = urllib.request.Request(base + "/echo", data=b"shout", headers={"X-Demo": "1"});
    print(req.get_method(), req.selector, req.get_header("X-demo"));
    with urllib.request.urlopen(req, timeout=5.0) as resp {
        print(resp.read(), resp.geturl() == base + "/echo");
    }
    try {
        urllib.request.urlopen(base + "/missing", timeout=5.0);
    } except urllib.error.HTTPError as e {
        print(e, e.code, isinstance(e, urllib.error.URLError), len(e.read()) > 0);
    }
    srv.shutdown();
    t.join();
    srv.server_close();
    try {
        urllib.request.urlopen("gopher://example.org/");
    } except urllib.error.URLError as e {
        print(e);
    }
    robots = urllib.robotparser.RobotFileParser();
    robots.parse(["User-agent: *", "Disallow: /private/", "Crawl-delay: 2"]);
    print(robots.can_fetch("bot", "/private/x"), robots.can_fetch("bot", "/public"));
    print(robots.crawl_delay("bot"));
}
```

```output
200 b'cookie: None' ['session']
200 b'cookie: session=abc123' ['session']
POST /echo 1
b'SHOUT' True
HTTP Error 404: Not Found 404 True True
<urlopen error unknown url type: gopher>
False True
2
```

| Name | What it is |
|---|---|
| `Request(url, data=None, headers={}, origin_req_host=None, unverifiable=False, method=None)` | A request to pass to `urlopen`, its `headers` a `dict[str, str]`: `add_header`, `add_unredirected_header`, `has_header`, `get_header`, `remove_header`, `header_items`, `get_full_url`, `get_method`, `set_proxy`, and `full_url`, `host`, `selector`, `type`, `data`, `headers`, `method` |
| `build_opener(*handlers)`, `install_opener(opener)`, `OpenerDirector` | An opener made of the default handlers and the program's: `open(fullurl, data=None, timeout=...)`, `add_handler`, `addheaders`; `install_opener` makes one `urlopen`'s |
| `BaseHandler` | What a handler derives from. An opener finds a handler's methods by their names (`http_open`, `http_request`, `http_response`, `http_error_404`, `default_open`, `unknown_open`), so a program's own handler takes part by declaring them |
| `HTTPHandler`, `HTTPSHandler(debuglevel=None, context=None, check_hostname=None)`, `HTTPRedirectHandler`, `HTTPErrorProcessor`, `HTTPDefaultErrorHandler`, `HTTPCookieProcessor(cookiejar=None)`, `ProxyHandler(proxies=None)`, `FTPHandler`, `FileHandler`, `DataHandler`, `UnknownHandler` | The handlers `build_opener` uses, and the cookie one |
| `CacheFTPHandler`, `ftpwrapper` | An `FTPHandler` that keeps its connections for the next URL of the same host and directory (`setTimeout`, `setMaxConns`), and the connection it retrieves through |
| `HTTPBasicAuthHandler`, `HTTPDigestAuthHandler`, `ProxyBasicAuthHandler`, `ProxyDigestAuthHandler`, `HTTPPasswordMgr`, `HTTPPasswordMgrWithDefaultRealm`, `HTTPPasswordMgrWithPriorAuth` | Authentication |
| `urlretrieve(url, filename=None, reporthook=None, data=None)`, `urlcleanup`, `pathname2url`, `url2pathname`, `getproxies`, `proxy_bypass`, `parse_http_list`, `parse_keqv_list` | As CPython's |
| `URLError` | An `OSError`: a URL that could not be opened, with `reason` (a refused connection's `ConnectionRefusedError`, or a text) |
| `HTTPError` | A `URLError` for an HTTP error status, with `code`, `reason`, `headers`, `url`, and the response's body to `read`; prints `HTTP Error 404: Not Found` |

`urllib.robotparser.RobotFileParser(url="")` reads a site's `robots.txt` (`set_url` and `read`,
or `parse(lines)`) and answers `can_fetch(useragent, url)`, `crawl_delay`, `request_rate` and
`site_maps`.

## What is not there yet

- **`urllib.response.addbase.delete`** is left out (E5142): CPython's `addbase` has no such
  attribute either.
- **The system's proxy settings on macOS**: `getproxies` and `proxy_bypass` read the
  environment (`http_proxy`, `no_proxy`, ...) there.

For an HTTP server, see [http.server](http.md), or [Servers](../apps/server.md)
(`jac docs apps/server`) for a Jac application's.

## Where to go next

- Connections, servers and cookies: [http](http.md).
- Sockets and TLS: [socket](socket.md).
- Every native module: [Standard-library modules](stdlib.md).
