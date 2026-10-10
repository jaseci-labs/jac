"""Blocking HTTP/1.1 client for the package manager (registry + tarballs).

One request per connection (`Connection: close`), body read to EOF into a
ByteBuf, then de-chunked and inflated (gzip/deflate) as the headers say.
Follows up to 5 redirects. TLS via the engine's OpenSSL binding, verifying
peers unless asked not to (bun: `--no-verify` / `BUN_CONFIG_NO_VERIFY`).

Sequential on purpose for now: the differential harness measures parity, not
speed. Concurrency (bun opens up to 48 sockets) is a P2 item.
"""

import from engine.src.ffi.libc { recv, close, getenv }
import from engine.src.runtime.mem { io_alloc, io_free, read_byte }
import from engine.src.net.tcp_socket {
    TCPSocket,
    tcp_connect,
    tcp_write_all,
    tcp_close
}
import from engine.src.tls.tls {
    TLSConfig,
    TLSSocket,
    tls_connect,
    tls_read_into,
    tls_write,
    tls_close
}
import from engine.src.pm.bytes {
    ByteBuf,
    bytebuf_new,
    bytebuf_free,
    bytebuf_append,
    bytebuf_from,
    bytes_to_str,
    bytes_find
}
import from engine.src.pm.gunzip { gunzip_bytes }
import from engine.src.version { JS_ENGINE_VERSION }

glob:pub HTTP_MAX_REDIRECTS: int = 5;
glob:priv _READ_CHUNK: int = 65536;

obj:pub HttpUrl {
    has ok: bool = False,
        scheme: str = "",
        host: str = "",
        port: int = 0,
        path: str = "/";
}

obj:pub HttpResponse {
    has status: int = 0,
        headers: dict[str, str] = {},
        body: ByteBuf = ByteBuf(),
        error: str = "",
        url: str = "";
}

# lower-case header names
# decoded body bytes
# transport / protocol failure
# final URL (after redirects)
def:pub http_parse_url(url: str) -> HttpUrl {
    u: HttpUrl = HttpUrl();
    rest: str = url;
    if rest.startswith("https://") {
        u.scheme = "https";
        u.port = 443;
        rest = rest[8:];
    } elif rest.startswith("http://") {
        u.scheme = "http";
        u.port = 80;
        rest = rest[7:];
    } else {
        return u;
    }
    slash: int = rest.find("/");
    hostport: str = rest;
    if slash >= 0 {
        hostport = rest[0:slash];
        u.path = rest[slash:];
    } else {
        u.path = "/";
    }
    at: int = hostport.rfind("@");
    if at >= 0 {
        hostport = hostport[at + 1:];
    }  # userinfo is not sent (auth goes in headers)
    if hostport.startswith("[") {
        close_b: int = hostport.find("]");
        if close_b < 0 {
            return u;
        }
        u.host = hostport[1:close_b];
        tail: str = hostport[close_b + 1:];
        if tail.startswith(":") and len(tail) > 1 {
            u.port = int(tail[1:]);
        }
    } else {
        colon: int = hostport.rfind(":");
        if colon >= 0 {
            ps: str = hostport[colon + 1:];
            if ps != "" and ps.isdigit() {
                u.port = int(ps);
            }
            u.host = hostport[0:colon];
        } else {
            u.host = hostport;
        }
    }
    if u.host == "" {
        return u;
    }
    u.ok = True;
    return u;
}

"""Origin ("scheme://host[:port]") of a parsed URL, default ports elided."""
def:pub http_origin(u: HttpUrl) -> str {
    o: str = u.scheme + "://" + u.host;
    if (u.scheme == "http" and u.port != 80)
        or (u.scheme == "https" and u.port != 443) {
        o = o + ":" + str(u.port);
    }
    return o;
}

def:pub http_user_agent -> str {
    return "js_engine/" + JS_ENGINE_VERSION + " (bun-compat)";
}

"""Whether a "Name: value" header line carries credentials."""
def _is_credential_header(h: str) -> bool {
    l: str = h.lower();
    return l.startswith("authorization:")
        or l.startswith("proxy-authorization:")
        or l.startswith("cookie:");
}

"""Headers to send on to a redirect target `next_url` after a request to `u`:
`headers` unchanged while the redirect stays on one origin (scheme, host and
port); without its credentials once it leaves — a private registry that
redirects tarball downloads to a CDN, an object store or plain http must not
hand that service its token (the Fetch spec and curl drop them the same way).
The caller keeps the result, so credentials dropped once stay dropped."""
def:pub http_redirect_headers(u: HttpUrl, next_url: str, headers: list[str]) -> list[str] {
    nu: HttpUrl = http_parse_url(next_url);
    if nu.ok and http_origin(nu).lower() == http_origin(u).lower() {
        return headers;
    }
    kept: list[str] = [];
    for h in headers {
        if not _is_credential_header(h) {
            kept.append(h);
        }
    }
    return kept;
}

"""GET `url`. `extra_headers` are complete "Name: value" lines; credential
headers among them are dropped once a redirect leaves the origin (see
http_redirect_headers). `verify` false disables TLS peer verification;
`ca_file` adds a PEM bundle."""
def:pub http_get(
    url: str, extra_headers: list[str], verify: bool, ca_file: str
) -> HttpResponse {
    cur: str = url;
    hdrs: list[str] = extra_headers;
    hops: int = 0;
    while True {
        u: HttpUrl = http_parse_url(cur);
        if not u.ok {
            r: HttpResponse = HttpResponse();
            r.url = cur;
            r.error = "invalid URL: " + cur;
            return r;
        }
        r: HttpResponse = _http_once(u, hdrs, verify, ca_file);
        r.url = cur;
        if r.error != "" {
            return r;
        }
        if (
            r.status == 301
            or r.status == 302
            or r.status == 303
            or r.status == 307
            or r.status == 308
        )
            and "location" in r.headers {
            hops = hops + 1;
            if hops > HTTP_MAX_REDIRECTS {
                r.error = "too many redirects";
                return r;
            }
            loc: str = r.headers["location"];
            if loc.startswith("http://") or loc.startswith("https://") {
                cur = loc;
            } elif loc.startswith("/") {
                cur = http_origin(u) + loc;
            } else {
                base: str = u.path;
                cut: int = base.rfind("/");
                if cut >= 0 {
                    base = base[0:cut + 1];
                } else {
                    base = "/";
                }
                cur = http_origin(u) + base + loc;
            }
            hdrs = http_redirect_headers(u, cur, hdrs);
            bytebuf_free(r.body);
            continue;
        }
        return r;
    }
}

def _http_once(
    u: HttpUrl, extra_headers: list[str], verify: bool, ca_file: str
) -> HttpResponse {
    r: HttpResponse = HttpResponse();
    host_hdr: str = u.host;
    if (u.scheme == "http" and u.port != 80)
        or (u.scheme == "https" and u.port != 443) {
        host_hdr = host_hdr + ":" + str(u.port);
    }
    lines: list[str] = [];
    lines.append("GET " + u.path + " HTTP/1.1");
    lines.append("Host: " + host_hdr);
    lines.append("User-Agent: " + http_user_agent());
    has_accept: bool = False;
    for h in extra_headers {
        if h.lower().startswith("accept:") {
            has_accept = True;
        }
        lines.append(h);
    }
    if not has_accept {
        lines.append("Accept: */*");
    }
    lines.append("Accept-Encoding: gzip, deflate");
    lines.append("Connection: close");
    req: str = "\r\n".join(lines) + "\r\n\r\n";

    raw: ByteBuf = bytebuf_new(_READ_CHUNK);
    chunk: int = io_alloc(_READ_CHUNK + 1);
    if u.scheme == "https" {
        cfg: TLSConfig = TLSConfig(
            verify_peer=verify,
            ca_certs="",
            cert_file="",
            key_file="",
            server_name=u.host
        );
        if ca_file != "" {
            cfg.ca_certs = ca_file;
        } else {
            extra_ca: str = getenv("NODE_EXTRA_CA_CERTS");
            if extra_ca != None and extra_ca != "" {
                cfg.ca_certs = extra_ca;
            }
        }
        ts: TLSSocket = tls_connect(u.host, u.port, cfg);
        if not ts.handshake_done {
            r.error = "TLS connection to " + u.host + ":" + str(u.port) + " failed";
            io_free(chunk);
            bytebuf_free(raw);
            return r;
        }
        if tls_write(ts, req) < 0 {
            r.error = "failed to send request to " + u.host;
            tls_close(ts);
            io_free(chunk);
            bytebuf_free(raw);
            return r;
        }
        while True {
            n: int = tls_read_into(ts, chunk, _READ_CHUNK);
            if n <= 0 {
                break;
            }
            bytebuf_append(raw, chunk, n);
        }
        tls_close(ts);
    } else {
        sock: TCPSocket = tcp_connect(u.host, u.port);
        if not sock.connected {
            r.error = "connection to " + u.host + ":" + str(u.port) + " failed";
            io_free(chunk);
            bytebuf_free(raw);
            return r;
        }
        if tcp_write_all(sock, req) < 0 {
            r.error = "failed to send request to " + u.host;
            tcp_close(sock);
            io_free(chunk);
            bytebuf_free(raw);
            return r;
        }
        while True {
            n: int = recv(sock.fd, chunk, _READ_CHUNK, 0);
            if n <= 0 or n > _READ_CHUNK {
                break;
            }
            bytebuf_append(raw, chunk, n);
        }
        tcp_close(sock);
    }
    io_free(chunk);
    _http_parse_response(r, raw);
    bytebuf_free(raw);
    return r;
}

"""Split status line + headers off `raw`, then decode the body into r.body."""
def _http_parse_response(r: HttpResponse, raw: ByteBuf) -> None {
    hdr_end: int = bytes_find(raw.ptr, raw.len, 0, "\r\n\r\n");
    sep_len: int = 4;
    if hdr_end < 0 {
        hdr_end = bytes_find(raw.ptr, raw.len, 0, "\n\n");
        sep_len = 2;
    }
    if hdr_end < 0 {
        r.error = "malformed HTTP response (no header terminator)";
        return;
    }
    head: str = bytes_to_str(raw.ptr, 0, hdr_end);
    hlines: list[str] = head.replace("\r\n", "\n").split("\n");
    if len(hlines) == 0 {
        r.error = "malformed HTTP response";
        return;
    }
    status_line: str = hlines[0];
    parts: list[str] = status_line.split(" ");
    if len(parts) < 2 or not parts[0].startswith("HTTP/") {
        r.error = "malformed HTTP status line: " + status_line;
        return;
    }
    code: str = parts[1];
    if not code.isdigit() {
        r.error = "malformed HTTP status: " + status_line;
        return;
    }
    r.status = int(code);
    i: int = 1;
    while i < len(hlines) {
        line: str = hlines[i];
        i = i + 1;
        c: int = line.find(":");
        if c <= 0 {
            continue;
        }
        name: str = line[0:c].strip().lower();
        value: str = line[c + 1:].strip();
        if name in r.headers {
            r.headers[name] = r.headers[name] + ", " + value;
        } else {
            r.headers[name] = value;
        }
    }
    body_off: int = hdr_end + sep_len;
    body_len: int = raw.len - body_off;
    if body_len < 0 {
        body_len = 0;
    }

    # transfer-encoding: chunked
    te: str = "";
    if "transfer-encoding" in r.headers {
        te = r.headers["transfer-encoding"].lower();
    }
    decoded: ByteBuf = bytebuf_new(body_len);
    if te.find("chunked") >= 0 {
        pos: int = body_off;
        end: int = raw.len;
        while pos < end {
            eol: int = bytes_find(raw.ptr, end, pos, "\r\n");
            if eol < 0 {
                break;
            }
            size_s: str = bytes_to_str(raw.ptr, pos, eol - pos).strip();
            semi: int = size_s.find(";");
            if semi >= 0 {
                size_s = size_s[0:semi].strip();
            }
            if size_s == "" {
                break;
            }
            size: int = 0;
            try {
                size = int(size_s, 16);
            } except Exception {
                r.error = "bad chunk size: " + size_s;
                break;
            }
            pos = eol + 2;
            if size == 0 {
                break;
            }
            if pos + size > end {
                size = end - pos;
            }
            bytebuf_append(decoded, raw.ptr + pos, size);
            pos = pos + size + 2;
        }
    } else {
        take: int = body_len;
        if "content-length" in r.headers {
            cl: str = r.headers["content-length"].strip();
            if cl.isdigit() {
                want: int = int(cl);
                if want < take {
                    take = want;
                } elif want > take {
                    r.error = "truncated response body ("
                        + str(take)
                        + " of "
                        + str(want)
                        + " bytes)";
                }
            }
        }
        bytebuf_append(decoded, raw.ptr + body_off, take);
    }

    # content-encoding
    ce: str = "";
    if "content-encoding" in r.headers {
        ce = r.headers["content-encoding"].lower().strip();
    }
    if (ce == "gzip" or ce == "x-gzip" or ce == "deflate") and decoded.len > 0 {
        inflated: ByteBuf = gunzip_bytes(decoded.ptr, decoded.len);
        bytebuf_free(decoded);
        if inflated.len < 0 {
            r.error = "failed to decompress " + ce + " response body";
            r.body = bytebuf_new(0);
            return;
        }
        r.body = inflated;
        return;
    }
    r.body = decoded;
}

"""Body as text (NUL-free bodies only — JSON)."""
def:pub http_body_str(r: HttpResponse) -> str {
    return bytes_to_str(r.body.ptr, 0, r.body.len);
}
