import atexit;
import os;
import socket;
import threading;
import time;
import from urllib.parse { urlsplit }
import from pymongo { MongoClient }
import from testcontainers.mongodb { MongoDbContainer }

import from jaclang.scale.persistence.db { _wait_mongo_ready }
import from jaclang.scale._optdeps.pymongo { ConnectionFailure, OperationFailure }

glob _shared: dict = {};


obj _FlakyAdmin {
    has fails: int = 2,
        exc: any = ConnectionFailure,
        calls: int = 0;

    def command(name: str) -> str {
        self.calls += 1;
        if self.calls <= self.fails {
            raise self.exc("not ready yet");
        }
        return "ok";
    }
}


obj _FlakyClient {
    has admin: _FlakyAdmin = _FlakyAdmin();
}


def _get_mongo -> tuple {
    if "container" not in _shared {
        container = MongoDbContainer("mongo:6.0");
        container.start();
        _shared["container"] = container;
        _shared["uri"] = container.get_connection_url();
        atexit.register(container.stop);
    }
    parts = urlsplit(_shared["uri"]);
    return (parts.hostname, int(parts.port), parts.username, parts.password);
}


def _pump(src: any, dst: any) {
    try {
        while True {
            data = src.recv(65536);
            if not data {
                break;
            }
            dst.sendall(data);
        }
    } except OSError { }
    try {
        src.close();
    } except OSError { }
    try {
        dst.close();
    } except OSError { }
}


def _delayed_proxy(delay_s: float, listen_port: int, host: str, port: int) -> None {
    # Refuse connections for delay_s, then forward to the real mongod: the
    # shape of a pod booting before its database endpoint exists.
    time.sleep(delay_s);
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM);
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
    srv.bind(("127.0.0.1", listen_port));
    srv.listen(8);
    while True {
        try {
            (conn, addr) = srv.accept();
        } except OSError {
            return;
        }
        try {
            up = socket.create_connection((host, port));
        } except OSError {
            conn.close();
            continue;
        }
        threading.Thread(target=_pump, args=(conn, up), daemon=True).start();
        threading.Thread(target=_pump, args=(up, conn), daemon=True).start();
    }
}


def _free_port -> int {
    probe = socket.socket(socket.AF_INET, socket.SOCK_STREAM);
    probe.bind(("127.0.0.1", 0));
    port = probe.getsockname()[1];
    probe.close();
    return port;
}


test "first mongo handshake retries transient connection failures only" {
    saved = os.environ.get("JAC_SCALE_RUNTIME");
    os.environ["JAC_SCALE_RUNTIME"] = "1";
    try {
        client: any = _FlakyClient();
        _wait_mongo_ready(client, tries=5, delay=0.01);
        assert client.admin.calls == 3;

        hopeless: any = _FlakyClient(admin=_FlakyAdmin(fails=99));
        raised = False;
        try {
            _wait_mongo_ready(hopeless, tries=3, delay=0.01);
        } except ConnectionFailure {
            raised = True;
        }
        assert raised;
        assert hopeless.admin.calls == 3;

        # Auth/config errors are not transient: raise on the first attempt so
        # bad credentials never hang through the retry budget.
        misconfigured: any = _FlakyClient(
            admin=_FlakyAdmin(fails=99, exc=OperationFailure)
        );
        raised = False;
        try {
            _wait_mongo_ready(misconfigured, tries=5, delay=0.01);
        } except OperationFailure {
            raised = True;
        }
        assert raised;
        assert misconfigured.admin.calls == 1;

        # Outside a scale runtime the guard returns immediately: no pings, no wait.
        os.environ.pop("JAC_SCALE_RUNTIME", None);
        untouched: any = _FlakyClient(admin=_FlakyAdmin(fails=99));
        _wait_mongo_ready(untouched, tries=3, delay=0.01);
        assert untouched.admin.calls == 0;
        os.environ["JAC_SCALE_RUNTIME"] = "1";
    } finally {
        if saved is None {
            os.environ.pop("JAC_SCALE_RUNTIME", None);
        } else {
            os.environ["JAC_SCALE_RUNTIME"] = saved;
        }
    }
}


test "real mongo: handshake succeeds with valid credentials" {
    (host, port, user, pw) = _get_mongo();
    saved = os.environ.get("JAC_SCALE_RUNTIME");
    os.environ["JAC_SCALE_RUNTIME"] = "1";
    try {
        client = MongoClient(
            f"mongodb://{user}:{pw}@{host}:{port}", serverSelectionTimeoutMS=5000
        );
        _wait_mongo_ready(client, tries=3, delay=0.5);
        client.close();
    } finally {
        if saved is None {
            os.environ.pop("JAC_SCALE_RUNTIME", None);
        } else {
            os.environ["JAC_SCALE_RUNTIME"] = saved;
        }
    }
}


test "real mongo: bad credentials fail fast, not through the retry budget" {
    (host, port, user, pw) = _get_mongo();
    saved = os.environ.get("JAC_SCALE_RUNTIME");
    os.environ["JAC_SCALE_RUNTIME"] = "1";
    try {
        client = MongoClient(
            f"mongodb://{user}:wrong-password@{host}:{port}",
            serverSelectionTimeoutMS=5000
        );
        start = time.monotonic();
        raised = False;
        try {
            _wait_mongo_ready(client);
        } except OperationFailure {
            raised = True;
        }
        elapsed = time.monotonic() - start;
        client.close();
        assert raised;
        # The default budget is 15 tries x 2s; retrying auth errors would
        # take >= 28s.
        assert elapsed < 15.0;
    } finally {
        if saved is None {
            os.environ.pop("JAC_SCALE_RUNTIME", None);
        } else {
            os.environ["JAC_SCALE_RUNTIME"] = saved;
        }
    }
}


test "real mongo: handshake rides out a connect-refused window and recovers" {
    (host, port, user, pw) = _get_mongo();
    saved = os.environ.get("JAC_SCALE_RUNTIME");
    os.environ["JAC_SCALE_RUNTIME"] = "1";
    try {
        listen_port = _free_port();
        threading.Thread(
            target=_delayed_proxy, args=(1.0, listen_port, host, port), daemon=True
        ).start();
        client = MongoClient(
            f"mongodb://{user}:{pw}@127.0.0.1:{listen_port}",
            serverSelectionTimeoutMS=500,
            directConnection=True
        );
        start = time.monotonic();
        _wait_mongo_ready(client, tries=20, delay=0.5);
        elapsed = time.monotonic() - start;
        client.close();
        # It must have actually waited through the refused window rather than
        # succeeding on a first attempt or dying on it.
        assert elapsed >= 0.9;
    } finally {
        if saved is None {
            os.environ.pop("JAC_SCALE_RUNTIME", None);
        } else {
            os.environ["JAC_SCALE_RUNTIME"] = saved;
        }
    }
}
