glob _INT32 = '!i',
     _INT16 = '!h';


impl _encode_param(v: any) -> (bytes | None) {
    if v is None {
        return None;
    }
    if isinstance(v, bool) {
        return b'true' if v else b'false';
    }
    if isinstance(v, bytes) {
        return v;
    }
    if isinstance(v, (list, tuple, set)) {
        return _array_literal(v).encode('utf-8');
    }
    if isinstance(v, dict) {
        import json;
        def _coerce(o: object) -> str {
            return str(o);
        }
        return json.dumps(v, `default=_coerce).encode('utf-8');
    }
    return str(v).encode('utf-8');
}


impl _array_literal(vals: any) -> str {
    parts: list[str] = [];
    for v in vals {
        s = str(v);
        escaped = s.replace('\\', '\\\\').replace('"', '\\"');
        parts.append(f'"{escaped}"');
    }
    return '{' + ','.join(parts) + '}';
}


impl _decode_value(oid: int, raw: bytes) -> any {
    if oid == 16 {
        return raw == b't';
    }
    if oid in (20, 21, 23, 26, 28) {
        return int(raw.decode('utf-8'));
    }
    if oid in (700, 701) {
        return float(raw.decode('utf-8'));
    }
    return raw.decode('utf-8');
}


impl _named_to_positional(sql: str, params: dict) -> tuple[str, list] {
    out: list[str] = [];
    order: dict[str, int] = {};
    args: list = [];
    i = 0;
    n = len(sql);
    in_squote = False;
    in_dquote = False;
    while i < n {
        ch = sql[i];
        if in_squote {
            out.append(ch);
            if ch == "'" {
                if i + 1 < n and sql[i + 1] == "'" {
                    out.append("'");
                    i += 1;
                } else {
                    in_squote = False;
                }
            }
            i += 1;
            continue;
        }
        if in_dquote {
            out.append(ch);
            if ch == '"' {
                in_dquote = False;
            }
            i += 1;
            continue;
        }
        if ch == "'" {
            in_squote = True;
            out.append(ch);
            i += 1;
            continue;
        }
        if ch == '"' {
            in_dquote = True;
            out.append(ch);
            i += 1;
            continue;
        }
        if ch == ':' {
            if i + 1 < n and sql[i + 1] == ':' {
                out.append('::');
                i += 2;
                continue;
            }
            j = i + 1;
            name = '';
            while j < n and (sql[j].isalnum() or sql[j] == '_') {
                name += sql[j];
                j += 1;
            }
            if name and name in params {
                if name not in order {
                    order[name] = len(args) + 1;
                    args.append(params[name]);
                }
                out.append(f"${order[name]}");
                i = j;
                continue;
            }
        }
        out.append(ch);
        i += 1;
    }
    return (''.join(out), args);
}


def _scram_proofs(
    password: str, server_first: str, client_first_bare: str
) -> tuple[str, str, str] {
    fields: dict[str, str] = {};
    for part in server_first.split(',') {
        if '=' in part {
            (k, v) = part.split('=', 1);
            fields[k] = v;
        }
    }
    server_nonce = fields.get('r', '');
    salt = base64.b64decode(fields.get('s', ''));
    iterations = int(fields.get('i', '4096'));
    salted = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt, iterations);
    client_key = hmac.new(salted, b'Client Key', hashlib.sha256).digest();
    stored_key = hashlib.sha256(client_key).digest();
    client_final_wo = f"c=biws,r={server_nonce}";
    auth_message = (
        client_first_bare + ',' + server_first + ',' + client_final_wo
    ).encode(
        'utf-8'
    );
    client_sig = hmac.new(stored_key, auth_message, hashlib.sha256).digest();
    proof = bytes((a ^ b) for (a, b) in zip(client_key, client_sig, strict=True));
    server_key = hmac.new(salted, b'Server Key', hashlib.sha256).digest();
    server_sig = hmac.new(server_key, auth_message, hashlib.sha256).digest();
    return (
        client_final_wo,
        base64.b64encode(proof).decode('ascii'),
        base64.b64encode(server_sig).decode('ascii')
    );
}


def _parse_error_fields(payload: bytes) -> dict[str, str] {
    fields: dict[str, str] = {};
    i = 0;
    while i < len(payload) {
        code = payload[i:i + 1];
        if code == b'\x00' {
            break;
        }
        end = payload.index(b'\x00', i + 1);
        fields[code.decode('ascii')] = payload[i + 1:end].decode(
            'utf-8', errors='replace'
        );
        i = end + 1;
    }
    return fields;
}


impl PgWireConnection.postinit -> None {
    self.notifications = deque();
    self.parameters = {};
    self._sock = None;
    self._closed = False;
    self._connect_socket();
    self._startup();
}


impl PgWireConnection._connect_socket -> None {
    if self.unix_sock {
        s: any = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM);
        s.settimeout(self.timeout);
        s.connect(self.unix_sock);
    } else {
        s: any = socket.create_connection(
            (self.host or '127.0.0.1', self.port), timeout=self.timeout
        );
        s.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1);
    }
    self._sock = s;
}


impl PgWireConnection._startup -> None {
    opts = {
        'user': self.user,
        'database': self.database,
        'application_name': self.application_name,
        'client_encoding': 'UTF8'
    };
    body = struct.pack(_INT32, PROTOCOL_VERSION);
    for (k, v) in opts.items() {
        body += k.encode('utf-8') + b'\x00' + str(v).encode('utf-8') + b'\x00';
    }
    body += b'\x00';
    sock: any = self._sock;
    sock.sendall(struct.pack(_INT32, len(body) + 4) + body);
    while True {
        (mtype, payload) = self._read_message();
        if self._handle_async(mtype, payload) {
            continue;
        }
        if mtype == 'R' {
            code = struct.unpack(_INT32, payload[:4])[0];
            self._authenticate(code, payload);
        } elif mtype == 'K' {
            continue;
        } elif mtype == 'E' {
            raise PgWireError(_parse_error_fields(payload));
        } elif mtype == 'Z' {
            return;
        }
    }
}


impl PgWireConnection._authenticate(code: int, payload: bytes) -> None {
    if code == 0 {
        return;
    }
    if code == 3 {
        assert self.password is not None , 'server requires a password';
        self._send('p', self.password.encode('utf-8') + b'\x00');
        return;
    }
    if code == 5 {
        assert self.password is not None , 'server requires a password (md5)';
        salt = payload[4:8];
        inner = hashlib.md5((self.password + self.user).encode('utf-8')).hexdigest();
        outer = hashlib.md5(inner.encode('ascii') + salt).hexdigest();
        self._send('p', b'md5' + outer.encode('ascii') + b'\x00');
        return;
    }
    if code == 10 {
        self._scram_auth(payload);
        return;
    }
    raise PgWireError({'C': '28000', 'M': f'unsupported authentication method {code}'});
}


impl PgWireConnection._scram_auth(payload: bytes) -> None {
    assert self.password is not None , 'server requires a password (scram)';
    mechs = [
        m.decode('ascii')
        for m in payload[4:].split(b'\x00')
        if m
    ];
    assert 'SCRAM-SHA-256' in mechs , f'no supported SASL mechanism in {mechs}';
    nonce = base64.b64encode(_pysecrets.token_bytes(18)).decode('ascii');
    client_first_bare = f"n=,r={nonce}";
    initial = ('n,,' + client_first_bare).encode('utf-8');
    body = b'SCRAM-SHA-256\x00' + struct.pack(_INT32, len(initial)) + initial;
    self._send('p', body);

    (mtype, resp) = self._read_message();
    while self._handle_async(mtype, resp) {
        (mtype, resp) = self._read_message();
    }
    if mtype == 'E' {
        raise PgWireError(_parse_error_fields(resp));
    }
    assert mtype == 'R' and struct.unpack(_INT32, resp[:4])[0] == 11 , (
        'expected SASL continue'
    );
    server_first = resp[4:].decode('utf-8');
    (client_final_wo, proof_b64, server_sig_b64) = _scram_proofs(
        self.password, server_first, client_first_bare
    );
    server_nonce = client_final_wo.split('r=', 1)[1];
    assert server_nonce.startswith(nonce) , 'server nonce mismatch';
    self._send('p', (client_final_wo + ',p=' + proof_b64).encode('utf-8'));

    (mtype, resp) = self._read_message();
    while self._handle_async(mtype, resp) {
        (mtype, resp) = self._read_message();
    }
    if mtype == 'E' {
        raise PgWireError(_parse_error_fields(resp));
    }
    assert mtype == 'R' and struct.unpack(_INT32, resp[:4])[0] == 12 , (
        'expected SASL final'
    );
    final = resp[4:].decode('utf-8');
    got_sig = final.split('v=', 1)[1] if 'v=' in final else '';
    assert got_sig == server_sig_b64 , 'server signature verification failed';
}


def _frame(msg_type: str, payload: bytes) -> bytes {
    return msg_type.encode('ascii') + struct.pack(_INT32, len(payload) + 4) + payload;
}


impl PgWireConnection._send(msg_type: str, payload: bytes) -> None {
    sock: any = self._sock;
    sock.sendall(_frame(msg_type, payload));
}


impl PgWireConnection._read_exact(n: int) -> bytes {
    buf = b'';
    sock: any = self._sock;
    while len(buf) < n {
        chunk = sock.recv(n - len(buf));
        if not chunk {
            self._closed = True;
            raise PgWireError({'C': '08006', 'M': 'connection closed by server'});
        }
        buf += chunk;
    }
    return buf;
}


impl PgWireConnection._read_message -> tuple[str, bytes] {
    header = self._read_exact(5);
    mtype = header[:1].decode('ascii');
    length = struct.unpack(_INT32, header[1:5])[0];
    payload = self._read_exact(length - 4) if length > 4 else b'';
    return (mtype, payload);
}


impl PgWireConnection._handle_async(msg_type: str, payload: bytes) -> bool {
    if msg_type == 'A' {
        pid = struct.unpack(_INT32, payload[:4])[0];
        rest = payload[4:];
        end = rest.index(b'\x00');
        channel = rest[:end].decode('utf-8');
        body = rest[end + 1:].split(b'\x00')[0].decode('utf-8');
        self.notifications.append((pid, channel, body));
        return True;
    }
    if msg_type == 'S' {
        parts = payload.split(b'\x00');
        if len(parts) >= 2 {
            self.parameters[parts[0].decode('utf-8')] = parts[1].decode('utf-8');
        }
        return True;
    }
    if msg_type == 'N' {
        logger.debug(f"pg notice: {_parse_error_fields(payload).get('M', '')}");
        return True;
    }
    return False;
}


impl PgWireConnection.run(sql: str, **params: any) -> list {
    assert not self._closed , 'connection is closed';
    (pos_sql, args) = _named_to_positional(sql, params);
    bind = b'\x00\x00' + struct.pack(_INT16, 0) + struct.pack(_INT16, len(args));
    for a in args {
        enc = _encode_param(a);
        if enc is None {
            bind += struct.pack(_INT32, -1);
        } else {
            bind += struct.pack(_INT32, len(enc)) + enc;
        }
    }
    bind += struct.pack(_INT16, 0);
    sock: any = self._sock;
    sock.sendall(
        _frame(
            'P', b'\x00' + pos_sql.encode('utf-8') + b'\x00' + struct.pack(_INT16, 0)
        )
            + _frame('B', bind)
            + _frame('D', b'P\x00')
            + _frame('E', b'\x00' + struct.pack(_INT32, 0))
            + _frame('S', b'')
    );

    rows: list = [];
    oids: list[int] = [];
    err: (dict | None) = None;
    while True {
        (mtype, payload) = self._read_message();
        if self._handle_async(mtype, payload) {
            continue;
        }
        if mtype in ('1', '2', '3', 'C', 'n', 's') {
            continue;
        }
        if mtype == 'T' {
            oids = [];
            nfields = struct.unpack(_INT16, payload[:2])[0];
            pos = 2;
            for _i in range(nfields) {
                end = payload.index(b'\x00', pos);
                pos = end + 1 + 6;
                oids.append(struct.unpack(_INT32, payload[pos:pos + 4])[0]);
                pos += 4 + 8;
            }
            continue;
        }
        if mtype == 'D' {
            ncols = struct.unpack(_INT16, payload[:2])[0];
            pos = 2;
            row: list = [];
            for ci in range(ncols) {
                vlen = struct.unpack(_INT32, payload[pos:pos + 4])[0];
                pos += 4;
                if vlen == -1 {
                    row.append(None);
                } else {
                    raw = payload[pos:pos + vlen];
                    pos += vlen;
                    oid = oids[ci] if ci < len(oids) else 25;
                    row.append(_decode_value(oid, raw));
                }
            }
            rows.append(tuple(row));
            continue;
        }
        if mtype == 'E' {
            err = _parse_error_fields(payload);
            continue;
        }
        if mtype == 'Z' {
            if err is not None {
                raise PgWireError(err);
            }
            return rows;
        }
    }
}


impl PgWireConnection.close -> None {
    if self._closed {
        return;
    }
    self._closed = True;
    try {
        self._send('X', b'');
    } except Exception { }
    try {
        sock: any = self._sock;
        sock.close();
    } except Exception { }
}
