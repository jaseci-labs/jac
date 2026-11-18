"""TLS for jac's Postgres wire client: libpq's sslmode and sslrootcert.

A one-connection fake server stands in for Postgres. It answers the
SSLRequest with 'S' (and does the handshake with a throwaway certificate)
or with 'N', reads the startup message the client sends next, and answers
it with an ErrorResponse, so a client that got as far as authenticating
fails with that error's text. What the server received shows whether the
startup message travelled inside TLS. The certificates come from the
openssl CLI; the handshake tests skip without it.
"""

import os;
import shutil;
import socket;
import ssl;
import struct;
import subprocess;
import threading;
import from tempfile { TemporaryDirectory }
import from jaclang.data.pgwire {
    PgWireConnection,
    PgWireError,
    PROTOCOL_VERSION,
    SSL_REQUEST_CODE,
    _tls_context
}
import from jaclang.data.pgpool { pool_key }
import from jaclang.data.store { ConnInfo }
import from jaclang.server.session { conninfo_from_url }

glob REACHED = 'reached startup',
     SSL_REQUEST = struct.pack('!ii', 8, SSL_REQUEST_CODE);


def _recv_exact(sock: any, n: int) -> bytes {
    out = b'';
    while len(out) < n {
        chunk = sock.recv(n - len(out));
        if not chunk {
            break;
        }
        out += chunk;
    }
    return out;
}


def _error_response(message: str) -> bytes {
    fields = b'SFATAL\x00C28000\x00M' + message.encode('utf-8') + b'\x00\x00';
    return b'E' + struct.pack('!i', len(fields) + 4) + fields;
}


# Serves one connection. `tls` is the server-side context that answers the
# SSLRequest with 'S'; without one the server answers 'N'.
obj _FakeServer {
    has tls: any = None,
        unix_path: str = '',
        first: bytes = b'',
        startup: bytes = b'',
        tls_version: str = '',
        error: str = '',
        port: int = 0,
        _listener: any = None,
        _thread: any = None;

    def postinit {
        if self.unix_path {
            lsock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM);
            lsock.bind(self.unix_path);
        } else {
            lsock = socket.socket(socket.AF_INET, socket.SOCK_STREAM);
            lsock.bind(('127.0.0.1', 0));
            self.port = lsock.getsockname()[1];
        }
        lsock.listen(1);
        lsock.settimeout(10.0);
        self._listener = lsock;
        self._thread = threading.Thread(target=self._serve, daemon=True);
        self._thread.start();
    }

    def _serve {
        conn: any = None;
        try {
            (conn, _addr) = self._listener.accept();
            conn.settimeout(10.0);
            self.first = _recv_exact(conn, 8);
            head = self.first;
            if self.first == SSL_REQUEST {
                if self.tls is None {
                    conn.sendall(b'N');
                } else {
                    conn.sendall(b'S');
                    conn = self.tls.wrap_socket(conn, server_side=True);
                    self.tls_version = conn.version() or '';
                }
                head = _recv_exact(conn, 8);
            }
            if len(head) == 8 {
                size = struct.unpack('!i', head[:4])[0];
                self.startup = head + _recv_exact(conn, size - 8);
                conn.sendall(_error_response(REACHED));
            }
        } except Exception as e {
            self.error = f"{type(e).__name__}: {e}";
        } finally {
            if conn is not None {
                try {
                    conn.close();
                } except Exception {}
            }
            self._listener.close();
        }
    }

    def join {
        self._thread.join(10.0);
    }
}


# Connects with `kwargs` and returns what the attempt raised.
def _attempt(server: _FakeServer, **kwargs: any) -> Exception {
    caught: any = None;
    try {
        if server.unix_path {
            PgWireConnection(
                user='jac', unix_sock=server.unix_path, timeout=10.0, **kwargs
            );
        } else {
            host = kwargs.pop('host', '127.0.0.1');
            PgWireConnection(
                user='jac', host=host, port=server.port, timeout=10.0, **kwargs
            );
        }
    } except Exception as e {
        caught = e;
    }
    server.join();
    assert caught is not None , 'the fake server never answers successfully';
    return caught;
}


def _reached(err: Exception) -> bool {
    return isinstance(err, PgWireError) and REACHED in str(err);
}


# A self-signed certificate for `name` (DNS) in `td`; '' without openssl.
def _make_cert(td: str, name: str, stem: str) -> str {
    if not shutil.which('openssl') {
        return '';
    }
    cert = os.path.join(td, f"{stem}.pem");
    key = os.path.join(td, f"{stem}.key");
    done = subprocess.run(
        [
            'openssl',
            'req',
            '-x509',
            '-newkey',
            'rsa:2048',
            '-nodes',
            '-days',
            '2',
            '-subj',
            f"/CN={name}",
            '-addext',
            f"subjectAltName=DNS:{name}",
            '-keyout',
            key,
            '-out',
            cert
        ],
        capture_output=True
    );
    return cert if done.returncode == 0 else '';
}


def _server_ctx(cert: str) -> ssl.SSLContext {
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);
    ctx.load_cert_chain(cert, cert.replace('.pem', '.key'));
    return ctx;
}


test "a database url carries sslmode and sslrootcert" {
    plain = conninfo_from_url('postgresql://u:p@db.example:5433/app');
    assert (plain.sslmode, plain.sslrootcert) == ('', '');
    info = conninfo_from_url(
        'postgresql://u:p@db.example/app?sslmode=verify-full&sslrootcert=/ca.pem&channel_binding=prefer'
    );
    assert (info.host, info.port, info.database) == ('db.example', 5432, 'app');
    assert (info.sslmode, info.sslrootcert) == ('verify-full', '/ca.pem');
}


test "channel_binding=require is refused rather than silently dropped" {
    err: any = None;
    try {
        conninfo_from_url(
            'postgresql://u:p@db.example/app?sslmode=require&channel_binding=require'
        );
    } except ValueError as e {
        err = e;
    }
    assert err is not None and 'channel_binding=require' in str(err) , str(err);
}


test "an unknown sslmode is refused before connecting" {
    err: any = None;
    try {
        # Port 1 refuses connections: only a check made first can win.
        PgWireConnection(user='jac', host='127.0.0.1', port=1, sslmode='always');
    } except ValueError as e {
        err = e;
    }
    assert err is not None and "'always'" in str(err) , str(err);
}


test "sslrootcert=system needs verify-full" {
    for mode in ('require', 'verify-ca') {
        err: any = None;
        try {
            _tls_context(mode, 'system');
        } except ValueError as e {
            err = e;
        }
        assert err is not None , mode;
    }
    assert _tls_context('verify-full', 'system').check_hostname;
}


test "without sslmode the client sends the startup message in the clear" {
    server = _FakeServer();
    err = _attempt(server);
    assert _reached(err) , str(err);
    assert struct.unpack('!ii', server.first)[1] == PROTOCOL_VERSION;
    assert b'user\x00jac\x00' in server.startup;
}


test "sslmode=require refuses a server that declines TLS" {
    server = _FakeServer();
    err = _attempt(server, sslmode='require');
    assert isinstance(err, PgWireError) , repr(err);
    assert 'does not accept TLS' in str(err) , str(err);
    assert server.first == SSL_REQUEST;
    assert server.startup == b'' , 'the startup message went out in the clear';
}


test "sslmode=prefer falls back to plaintext when the server declines TLS" {
    for mode in ('prefer', 'allow') {
        server = _FakeServer();
        err = _attempt(server, sslmode=mode);
        assert _reached(err) , f"{mode}: {err}";
        assert server.first == SSL_REQUEST , mode;
        assert b'user\x00jac\x00' in server.startup , mode;
        assert server.tls_version == '' , mode;
    }
}


test "a Unix socket never negotiates TLS" {
    with TemporaryDirectory() as td {
        server = _FakeServer(unix_path=os.path.join(td, '.s.PGSQL.5432'));
        err = _attempt(server, sslmode='require');
        assert _reached(err) , str(err);
        assert struct.unpack('!ii', server.first)[1] == PROTOCOL_VERSION;
    }
}


test "the startup message travels inside TLS" {
    with TemporaryDirectory() as td {
        cert = _make_cert(td, 'localhost', 'server');
        if not cert {
            testskip('the openssl CLI is needed to make a test certificate');
        }
        for mode in ('require', 'prefer') {
            server = _FakeServer(tls=_server_ctx(cert));
            err = _attempt(server, sslmode=mode);
            assert _reached(err) , f"{mode}: {err} / server: {server.error}";
            assert server.tls_version.startswith('TLS') , mode;
            assert b'user\x00jac\x00' in server.startup , mode;
        }
    }
}


test "verify-ca checks the chain, verify-full the host name too" {
    with TemporaryDirectory() as td {
        cert = _make_cert(td, 'localhost', 'server');
        other = _make_cert(td, 'localhost', 'other');
        if not cert or not other {
            testskip('the openssl CLI is needed to make a test certificate');
        }
        # (host, sslmode, sslrootcert) -> reaches startup?
        cases = [
            ('localhost', 'verify-full', cert, True),
            ('127.0.0.1', 'verify-full', cert, False),
            ('127.0.0.1', 'verify-ca', cert, True),
            ('127.0.0.1', 'verify-ca', other, False),
            ('localhost', 'verify-full', '', False),
            # As in libpq, require with a root certificate verifies the chain.
            ('127.0.0.1', 'require', cert, True),
            ('127.0.0.1', 'require', other, False),

        ];
        for (host, mode, ca, ok) in cases {
            server = _FakeServer(tls=_server_ctx(cert));
            err = _attempt(server, host=host, sslmode=mode, sslrootcert=ca);
            label = f"{host} {mode} ca={os.path.basename(ca) or '-'}";
            if ok {
                assert _reached(err) , f"{label}: {err} / server: {server.error}";
            } else {
                assert isinstance(err, ssl.SSLCertVerificationError) , f"{label}: {err!r}";
                assert server.startup == b'' , label;
            }
        }
    }
}


test "the pool keeps connections with different TLS settings apart" {
    base = ConnInfo(host='db.example', password='p');
    keys = {
        pool_key(base),
        pool_key(ConnInfo(host='db.example', password='p', sslmode='require')),
        pool_key(
            ConnInfo(
                host='db.example',
                password='p',
                sslmode='verify-full',
                sslrootcert='/ca.pem'
            )
        )
    };
    assert len(keys) == 3;
    assert pool_key(base) == pool_key(ConnInfo(host='db.example', password='p'));
}
