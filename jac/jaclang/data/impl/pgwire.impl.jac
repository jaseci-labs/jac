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
        if v is None {
            parts.append('NULL');
            continue;
        }
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


impl _named_to_positional(sql: str, params: dict[str, any]) -> tuple[str, list[any]] {
    (pos_sql, order) = _rewrite_named(sql, frozenset(params));
    return (pos_sql, [params[name] for name in order]);
}


impl _rewrite_named(sql: str, names: frozenset[str]) -> tuple[str, tuple[str, ...]] {
    out: list[str] = [];
    order: dict[str, int] = {};
    i = 0;
    n = len(sql);
    in_squote = False;
    in_dquote = False;
    escape_squote = False;
    continuation = False;
    while i < n {
        ch = sql[i];
        if in_squote {
            out.append(ch);
            if escape_squote and ch == '\\' and i + 1 < n {
                out.append(sql[i + 1]);
                i += 2;
                continue;
            }
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
        if sql.startswith('--', i) {
            j = i + 2;
            while j < n and sql[j] not in ('\n', '\r') {
                j += 1;
            }
            out.append(sql[i:j]);
            i = j;
            continue;
        }
        if sql.startswith('/*', i) {
            j = i + 2;
            depth = 1;
            while j < n and depth {
                if sql.startswith('/*', j) {
                    depth += 1;
                    j += 2;
                } elif sql.startswith('*/', j) {
                    depth -= 1;
                    j += 2;
                } else {
                    if sql[j] in ('\n', '\r') {
                        continuation = True;
                    }
                    j += 1;
                }
            }
            out.append(sql[i:j]);
            i = j;
            continue;
        }
        if ch == "'" {
            in_squote = True;
            escape_squote = (escape_squote and continuation)
                or (
                    i > 0
                    and sql[i - 1] in ('E', 'e')
                    and (
                        i < 2
                        or not (
                            sql[i - 2].isalnum()
                            or sql[i - 2] in ('_', '$')
                            or ord(sql[i - 2]) >= 128
                        )
                    )
                );
            continuation = False;
            out.append(ch);
            i += 1;
            continue;
        }
        if ch.isspace() {
            if ch in ('\n', '\r') {
                continuation = True;
            }
        } else {
            escape_squote = False;
            continuation = False;
        }
        if ch == '$'
            and (
                i == 0
                or not (
                    sql[i - 1].isalnum()
                    or sql[i - 1] in ('_', '$')
                    or ord(sql[i - 1]) >= 128
                )
            ) {
            j = i + 1;
            if j < n and (sql[j].isalpha() or sql[j] == '_' or ord(sql[j]) >= 128) {
                j += 1;
                while j < n
                    and (sql[j].isalnum() or sql[j] == '_' or ord(sql[j]) >= 128) {
                    j += 1;
                }
            }
            if j < n and sql[j] == '$' {
                delimiter = sql[i:j + 1];
                end = sql.find(delimiter, j + 1);
                end = n if end < 0 else end + len(delimiter);
                out.append(sql[i:end]);
                i = end;
                continue;
            }
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
            while j < n and (sql[j].isalnum() or sql[j] == '_') {
                j += 1;
            }
            name = sql[i + 1:j];
            if name and name in names {
                if name not in order {
                    order[name] = len(order) + 1;
                }
                out.append(f"${order[name]}");
                i = j;
                continue;
            }
        }
        out.append(ch);
        i += 1;
    }
    return (''.join(out), tuple(order));
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
    self._rbuf = bytearray();
    self._rpos = 0;
    self._stmts = OrderedDict();
    self._stmt_seq = 0;
    self._evicted = [];
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
            self._drain_async();
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


impl PgWireConnection._fill(n: int) -> None {
    buf = self._rbuf;
    sock: any = self._sock;
    while len(buf) - self._rpos < n {
        chunk = sock.recv(READ_CHUNK);
        if not chunk {
            self._closed = True;
            raise PgWireError({'C': '08006', 'M': 'connection closed by server'});
        }
        if self._rpos {
            del buf[:self._rpos];
            self._rpos = 0;
        }
        buf.extend(chunk);
    }
}


impl PgWireConnection._read_message -> tuple[str, bytes] {
    self._fill(5);
    length = struct.unpack_from(_INT32, self._rbuf, self._rpos + 1)[0];
    self._fill(length + 1);
    buf = self._rbuf;
    start = self._rpos;
    end = start + 1 + length;
    mtype = chr(buf[start]);
    payload = bytes(buf[start + 5:end]);
    if end == len(buf) {
        buf.clear();
        self._rpos = 0;
    } else {
        self._rpos = end;
    }
    return (mtype, payload);
}


impl PgWireConnection._drain_async -> None {
    buf = self._rbuf;
    while len(buf) - self._rpos >= 5 and chr(buf[self._rpos]) in ('A', 'S', 'N') {
        length = struct.unpack_from(_INT32, buf, self._rpos + 1)[0];
        if len(buf) - self._rpos < length + 1 {
            return;
        }
        (mtype, payload) = self._read_message();
        self._handle_async(mtype, payload);
    }
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


impl PgWireConnection.run(sql: str, **params: any) -> list[any] {
    assert not self._closed , 'connection is closed';
    (pos_sql, args) = _named_to_positional(sql, params);
    bare = _SQL_COMMENT.sub(' ', pos_sql);
    verb = ' '.join(bare.split()[:3]).upper();
    drops_all = verb.startswith(
        ('DISCARD ALL', 'DEALLOCATE ALL', 'DEALLOCATE PREPARE ALL')
    );
    resets = drops_all or verb.startswith('DEALLOCATE');
    name: str = '';
    fresh = False;
    if not resets {
        cached: (str | None) = self._stmts.get(pos_sql);
        if cached is None {
            fresh = True;
            self._stmt_seq += 1;
            name = f"j{self._stmt_seq}";
        } else {
            name = cached;
            self._stmts.move_to_end(pos_sql);
        }
    }
    stmt = name.encode('ascii') + b'\x00';
    bind = b'\x00' + stmt + struct.pack(_INT16, 0) + struct.pack(_INT16, len(args));
    for a in args {
        enc = _encode_param(a);
        if enc is None {
            bind += struct.pack(_INT32, -1);
        } else {
            bind += struct.pack(_INT32, len(enc)) + enc;
        }
    }
    bind += struct.pack(_INT16, 0);
    out = b''.join(
        _frame('C', b'S' + old.encode('ascii') + b'\x00') for old in self._evicted
    );
    self._evicted = [];
    if fresh or resets {
        out += _frame(
            'P', stmt + pos_sql.encode('utf-8') + b'\x00' + struct.pack(_INT16, 0)
        );
    }
    sock: any = self._sock;
    sock.sendall(
        out
            + _frame('B', bind)
            + _frame('D', b'P\x00')
            + _frame('E', b'\x00' + struct.pack(_INT32, 0))
            + _frame('S', b'')
    );
    parsed = False;

    rows: list[tuple[any, ...]] = [];
    oids: list[int] = [];
    err: (dict[str, any] | None) = None;
    while True {
        (mtype, payload) = self._read_message();
        if self._handle_async(mtype, payload) {
            continue;
        }
        if mtype == '1' {
            parsed = True;
            continue;
        }
        if mtype in ('2', '3', 'C', 'n', 's') {
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
            row: list[any] = [];
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
            self._drain_async();
            if resets and err is None {
                if drops_all {
                    self._stmts.clear();
                    self._evicted = [];
                } else {
                    one = _DEALLOCATE_ONE.match(bare);
                    if one is None {
                        self._evicted = list(self._stmts.values());
                        self._stmts.clear();
                    }
                    gone = '';
                    if one is not None {
                        quoted = one.group(1);
                        if quoted {
                            gone = quoted.replace('""', '"');
                        } else {
                            gone = (one.group(2) or '').lower();
                        }
                    }
                    for (text, held) in list(self._stmts.items()) {
                        if held == gone {
                            del self._stmts[text];
                        }
                    }
                    self._evicted = [
                        old
                        for old in self._evicted
                        if old != gone
                    ];
                }
            }
            if fresh and parsed {
                self._stmts[pos_sql] = name;
                if len(self._stmts) > STATEMENT_CACHE_SIZE {
                    self._evicted.append(self._stmts.popitem(last=False)[1]);
                }
            }
            if err is not None {
                code = err.get('C', '');
                if code == '26000' and not fresh {
                    self._stmts.pop(pos_sql, None);
                    if payload[:1] == b'I' {
                        return self.run(sql, **params);
                    }
                } elif code == '0A000' and not fresh {
                    self._stmts.pop(pos_sql, None);
                    self._evicted.append(name);
                }
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
    } except Exception {}
    try {
        sock: any = self._sock;
        sock.close();
    } except Exception {}
}
