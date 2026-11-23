impl _request_method(request: Request) -> str {
    if request.method is not None {
        return request.method;
    }
    return "POST" if len(request.data) > 0 else "GET";
}

impl _parse_url(u: str) -> _Url {
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

impl _request_bytes(host: str, path: str, request: Request) -> bytes {
    method = _request_method(request);
    if method.find("\r") != -1
        or method.find("\n") != -1
        or method.find(" ") != -1
        or path.find("\r") != -1
        or path.find("\n") != -1 {
        raise ValueError("illegal request method or path");
    }
    provided: dict[str, str] = {};
    for name in request.headers {
        value = request.headers[name];
        if name.find("\r") != -1
            or name.find("\n") != -1
            or value.find("\r") != -1
            or value.find("\n") != -1 {
            raise ValueError("illegal header name or value");
        }
        provided[name.lower()] = value;
    }
    lines: list[str] = [method + " " + path + " HTTP/1.0"];
    if "host" not in provided {
        lines.append("Host: " + host);
    }
    lines.append("Connection: close");
    if "user-agent" not in provided {
        lines.append("User-Agent: jac-urllib/1.0");
    }
    if "accept" not in provided {
        lines.append("Accept: */*");
    }
    for name in request.headers {
        if name.lower() != "connection" {
            lines.append(name + ": " + request.headers[name]);
        }
    }
    if len(request.data) > 0 and "content-length" not in provided {
        lines.append("Content-Length: " + str(len(request.data)));
    }
    header: bytes = ("\r\n".join(lines) + "\r\n\r\n").encode();
    return header + request.data;
}

impl _replace_content_length(headers: dict[str, str]) -> dict[str, str] {
    out: dict[str, str] = {};
    for name in headers {
        if name.lower() != "content-length" {
            out[name] = headers[name];
        }
    }
    return out;
}

impl _fetch_raw(pu: _Url, request: Request, timeout: (float | None)) -> bytes {
    raw = b"";
    sock: Socket | None = None;
    ss: SSLSocket | None = None;
    try {
        sock = create_connection((pu.host, pu.port), timeout);
        reqb = _request_bytes(pu.host, pu.path, request);
        if pu.scheme == "https" {
            ctx = create_default_context();
            ss = ctx.wrap_socket(sock, server_hostname=pu.host);
            ss.sendall(reqb);
            chunk = ss.recv(8192);
            while len(chunk) > 0 {
                raw += chunk;
                chunk = ss.recv(8192);
            }
        } else {
            sock.sendall(reqb);
            chunk = sock.recv(8192);
            while len(chunk) > 0 {
                raw += chunk;
                chunk = sock.recv(8192);
            }
        }
    } except OSError as e {
        raise URLError(reason=e);
    } except SSLError as e {
        raise URLError(reason=e);
    } finally {
        if ss is not None {
            ss.close();
        } elif sock is not None {
            sock.close();
        }
    }
    return raw;
}

impl _find_header_end(raw: bytes) -> int {
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

impl _parse_response(raw: bytes, url: str) -> HTTPResponse {
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
            names.append(line[:colon].strip());
            values.append(line[colon + 1:].strip());
        }
        i += 1;
    }
    header_map = HTTPHeaders();
    j: int = 0;
    while j < len(names) {
        header_map.add(names[j], values[j]);
        j += 1;
    }
    return HTTPResponse(
        status=status,
        reason=reason,
        _url=url,
        _body=body,
        _header_names=names,
        _header_values=values,
        headers=header_map,
    );
}

impl _resolve_redirect(pu: _Url, loc: str) -> str {
    if loc.startswith("http://") or loc.startswith("https://") {
        return loc;
    }
    base = pu.scheme + "://" + pu.host + ":" + str(pu.port);
    if loc.startswith("/") {
        return base + loc;
    }
    return base + "/" + loc;
}

impl urlopen(
    url: (str | Request), data: (bytes | None), timeout: (float | None)
) -> HTTPResponse {
    request: Request;
    if isinstance(url, Request) {
        request = url;
        if data is not None {
            request.data = data;
            request.headers = _replace_content_length(request.headers);
        }
    } elif isinstance(url, str) {
        if data is not None {
            request = Request(url=url, data=data);
        } else {
            request = Request(url=url);
        }
    } else {
        raise TypeError("urlopen: url must be a str or Request");
    }
    return _urlopen_request(request, timeout);
}

impl _urlopen_request(request: Request, timeout: (float | None)) -> HTTPResponse {
    cur: str = request.url;
    redirects: int = 0;
    while redirects < 10 {
        pu: _Url = _parse_url(cur);
        raw: bytes = _fetch_raw(pu, request, timeout);
        resp: HTTPResponse = _parse_response(raw, cur);
        if resp.status >= 300 and resp.status < 400 {
            loc: str | None = resp.getheader("location", "");
            if loc is not None and len(loc) > 0 {
                target = _resolve_redirect(pu, loc);
                next_url: _Url = _parse_url(target);
                if pu.scheme == "https" and next_url.scheme == "http" {
                    raise OSError("refusing an HTTPS to HTTP redirect");
                }
                changed_origin = (
                    pu.scheme != next_url.scheme
                    or pu.host.lower() != next_url.host.lower()
                    or pu.port != next_url.port
                );
                next_headers: dict[str, str] = {};
                for name in request.headers {
                    lower_name = name.lower();
                    if lower_name == "host" {
                        continue;
                    }
                    if changed_origin
                        and (
                            lower_name == "authorization"
                            or lower_name == "cookie"
                            or lower_name == "proxy-authorization"
                        ) {
                        continue;
                    }
                    next_headers[name] = request.headers[name];
                }
                next_method = _request_method(request);
                next_data = request.data;
                switch_to_get = (changed_origin and next_method.upper() != "HEAD")
                    or (resp.status == 303 and next_method.upper() != "HEAD")
                    or (
                        (resp.status == 301 or resp.status == 302)
                        and next_method.upper() == "POST"
                    );
                if switch_to_get {
                    next_method = "GET";
                    next_data = b"";
                    clean_headers: dict[str, str] = {};
                    for name in next_headers {
                        lower_name = name.lower();
                        if lower_name != "content-length"
                            and lower_name != "content-type"
                            and lower_name != "transfer-encoding" {
                            clean_headers[name] = next_headers[name];
                        }
                    }
                    next_headers = clean_headers;
                }
                request = Request(
                    url=target, data=next_data, headers=next_headers, method=next_method
                );
                cur = target;
                redirects += 1;
                continue;
            }
        }
        if resp.status >= 400 {
            raise HTTPError(
                url=cur, code=resp.status, msg=resp.reason, hdrs=resp.headers, fp=resp
            );
        }
        return resp;
    }
    raise HTTPError(url=cur, msg="too many redirects (>10)");
}
