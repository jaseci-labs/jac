import from socket { create_connection }
import from ssl { create_default_context }


obj:pub HTTPResponse {
    has status: int,
        body_length: int,
        reason: str,
        url: str,
        body: bytes,
        header_names: list[str],
        header_values: list[str];
}


obj _Url {
    has scheme: str,
        host: str,
        port: int,
        path: str;
}


def _parse_url(u: str) -> _Url {
    scheme = "http";
    rest = u;
    if u.startswith("https://") {
        scheme = "https";
        rest = u[8:];
    } elif u.startswith("http://") {
        scheme = "http";
        rest = u[7:];
    }
    hostport = rest;
    path = "/";
    slash = rest.find("/");
    if slash != -1 {
        hostport = rest[:slash];
        path = rest[slash:];
    }
    host = hostport;
    port = 443 if scheme == "https" else 80;
    colon = hostport.find(":");
    if colon != -1 {
        host = hostport[:colon];
        port = int(hostport[colon + 1:]);
    }
    return _Url(scheme=scheme, host=host, port=port, path=path);
}


def _request_text(host: str, path: str) -> str {
    return "GET " + path + " HTTP/1.0\r\nHost: " + host + "\r\nConnection: close\r\nUser-Agent: jac-urllib/1.0\r\nAccept: */*\r\n\r\n";
}


def _fetch_raw(pu: _Url) -> bytes {
    sock = create_connection((pu.host, pu.port));
    reqb = _request_text(pu.host, pu.path).encode();
    raw = b"";
    if pu.scheme == "https" {
        ctx = create_default_context();
        ss = ctx.wrap_socket(sock, server_hostname=pu.host);
        ss.sendall(reqb);
        chunk = ss.recv(8192);
        while len(chunk) > 0 {
            raw += chunk;
            chunk = ss.recv(8192);
        }
        ss.close();
    } else {
        sock.sendall(reqb);
        chunk = sock.recv(8192);
        while len(chunk) > 0 {
            raw += chunk;
            chunk = sock.recv(8192);
        }
        sock.close();
    }
    return raw;
}


def _find_header_end(raw: bytes) -> int {
    n = len(raw);
    i = 0;
    while i + 3 < n {
        if raw[i] == 13
        and raw[i + 1] == 10
        and raw[i + 2] == 13
        and raw[i + 3] == 10 {
            return i;
        }
        i += 1;
    }
    return -1;
}


def _parse_response(raw: bytes, url: str) -> HTTPResponse {
    sep = _find_header_end(raw);
    header_bytes = raw[:sep] if sep != -1 else raw;
    body = raw[sep + 4:] if sep != -1 else b"";
    header_text = header_bytes.decode();
    lines = header_text.split("\r\n");
    status: int = 0;
    reason: str = "";
    status_line = lines[0];
    sp1 = status_line.find(" ");
    if sp1 != -1 {
        after = status_line[sp1 + 1:];
        sp2 = after.find(" ");
        if sp2 == -1 {
            status = int(after);
        } else {
            status = int(after[:sp2]);
            reason = after[sp2 + 1:];
        }
    }
    names: list[str] = [];
    values: list[str] = [];
    i: int = 1;
    while i < len(lines) {
        line = lines[i];
        colon = line.find(":");
        if colon != -1 {
            names.append(line[:colon].strip().lower());
            values.append(line[colon + 1:].strip());
        }
        i += 1;
    }
    return HTTPResponse(
        status=status,
        body_length=len(body),
        reason=reason,
        url=url,
        body=body,
        header_names=names,
        header_values=values
    );
}


def _header_value(resp: HTTPResponse, name: str) -> str {
    i: int = 0;
    while i < len(resp.header_names) {
        if resp.header_names[i] == name {
            return resp.header_values[i];
        }
        i += 1;
    }
    return "";
}


def _resolve_redirect(pu: _Url, loc: str) -> str {
    if loc.startswith("http://") or loc.startswith("https://") {
        return loc;
    }
    base = pu.scheme + "://" + pu.host + ":" + str(pu.port);
    if loc.startswith("/") {
        return base + loc;
    }
    return base + "/" + loc;
}


def:pub urlopen(url: str) -> HTTPResponse {
    cur = url;
    redirects: int = 0;
    while redirects < 10 {
        pu = _parse_url(cur);
        raw = _fetch_raw(pu);
        resp = _parse_response(raw, cur);
        if resp.status >= 300 and resp.status < 400 {
            loc = _header_value(resp, "location");
            if len(loc) > 0 {
                cur = _resolve_redirect(pu, loc);
                redirects += 1;
                continue;
            }
        }
        return resp;
    }
    raise Exception("urlopen: too many redirects (>10) for " + url);
}
