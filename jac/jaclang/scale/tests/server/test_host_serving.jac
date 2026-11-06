"""A program hosted by the one server assembly, outside the CLI.

A desktop host, a test harness, an embedding process: each wants the same
server `jac run --serve` assembles, without the CLI around it. Three things the
assembly must offer for that, pinned here against a two-app workspace:

- `serve_background()` runs the transport on a background thread, binding
  127.0.0.1 with an ephemeral port and reporting the bound port, and the
  returned callable stops it;
- `client_dist` in the serve settings names the client bundle the server
  serves, so a host that built its own bundle serves it from wherever it put
  it, index and assets, with the SPA fallback;
- `prepare_inprocess_runtime` colocates the workspace's service apps the way
  the CLI serve flow does, so an in-process server answers `/api/<service>/...`.
"""

import json;
import os;
import shutil;
import socket;
import sys;
import tempfile;
import threading;
import time;
import urllib.request;
import from pathlib { Path }
import from jaclang { JacRuntime as Jac }
import from jaclang.server { sv_client }


glob _TOML: str = (
         '[project]\nname = "hosted"\ndefault-app = "web"\n\n[apps.web]\nkind = "web-app"\nentry-point = "web.main"\n\n[apps.feed]\nkind = "service"\nentry-point = "core.feed"\n'
     ),
     _WEB_SRC: str = (
         "walker:pub Hello {\n"
         "    has who: str = \"world\";\n"
         "\n"
         "    can run with Root entry {\n"
         "        report \"hello \" + self.who;\n"
         "    }\n"
         "}\n"
     ),
     _FEED_SRC: str = (
         "walker:pub Latest {\n"
         "    can run with Root entry {\n"
         "        report [\"a\", \"b\"];\n"
         "    }\n"
         "}\n"
     );


def _workspace -> str {
    tmp = tempfile.mkdtemp(prefix="jac_host_serving_");
    os.makedirs(os.path.join(tmp, "web"), exist_ok=True);
    os.makedirs(os.path.join(tmp, "core"), exist_ok=True);
    (Path(tmp) / "jac.toml").write_text(_TOML);
    (Path(tmp) / "web" / "main.jac").write_text(_WEB_SRC);
    (Path(tmp) / "core" / "feed.jac").write_text(_FEED_SRC);
    return tmp;
}


def _dist(tmp: str) -> str {
    dist = os.path.join(tmp, "bundle");
    os.makedirs(os.path.join(dist, "assets"), exist_ok=True);
    (Path(dist) / "index.html").write_text("<!doctype html><title>hosted</title>ok");
    (Path(dist) / "assets" / "app.js").write_text("console.log('hosted');");
    return dist;
}


def _get(url: str) -> tuple[int, str] {
    try {
        with urllib.request.urlopen(url, timeout=10) as r {
            return (int(r.status), r.read().decode("utf-8"));
        }
    } except urllib.error.HTTPError as e {
        return (int(e.code), e.read().decode("utf-8"));
    }
}


def _post(url: str, body: dict[str, any]) -> tuple[int, str] {
    data = json.dumps(body).encode("utf-8");
    req = urllib.request.Request(
        url, data=data, method="POST", headers={"Content-Type": "application/json"}
    );
    try {
        with urllib.request.urlopen(req, timeout=10) as r {
            return (int(r.status), r.read().decode("utf-8"));
        }
    } except urllib.error.HTTPError as e {
        return (int(e.code), e.read().decode("utf-8"));
    }
}


def _load(tmp: str, mod: str, base: str) {
    if mod in Jac.loaded_modules {
        del Jac.loaded_modules[mod];
    }
    if mod in sys.modules {
        del sys.modules[mod];
    }
    prepare_application(str(Path(base) / (mod + '.jac')), Jac.get_program(), base);
    Jac.jac_import(target=mod, base_path=base, lng="jac");
}


def _reset(tmp: str) {
    sv_client.set_consumer_app("");
    sv_client.clear_local_providers();
    set_config(None);
    Jac.set_full_target_path("");
    shutil.rmtree(tmp, ignore_errors=True);
}


"""Observe the real transport's error; optionally hold its worker before boot."""
obj _ObservedServingServer(ServingServer) {
    has startup_error: Exception | None = None,
        gate: threading.Event | None = None,
        entered: threading.Event = threading.Event(),
        finished: threading.Event = threading.Event();

    override def run(
        on_ready: Callable[[int], None] | None = None, port_retries: int = 0
    ) -> int {
        self.entered.set();
        try {
            if self.gate is not None {
                assert self.gate.`wait(timeout=35) , "worker was not released";
            }
            return super.run(on_ready=on_ready, port_retries=port_retries);
        } except Exception as e {
            self.startup_error = e;
            raise;
        } finally {
            self.finished.set();
        }
    }
}


"""Exercise asyncio's context validation after the real listener is bound."""
obj _InvalidTls(TlsSettings) {
    override def build_context -> any {
        return True;
    }
}


"""Fail after real scheduler cleanup to exercise error precedence and bridge cleanup."""
obj _CleanupErrorScheduler(Scheduler) {
    has starts: int = 0,
        stops: int = 0;

    override def start_if_pending {
        self.starts += 1;
        super.start_if_pending();
    }

    override def stop(timeout: float | None = None) {
        self.stops += 1;
        super.stop(timeout=timeout);
        raise RuntimeError('scheduler cleanup failed');
    }
}


"""Capture a startup error and clean up even when the broken baseline returns a handle."""
def _startup_error(srv: any, on_ready: any = None) -> any {
    stop: any = None;
    caught: any = None;
    try {
        try {
            stop = srv.serve_background(on_ready=on_ready, port_retries=0);
        } except Exception as e {
            caught = e;
        }
        assert caught is not None , "startup failure did not reach the caller";
        return caught;
    } finally {
        if stop is not None {
            try {
                stop();
            } except RuntimeError {}
        }
    }
}


test "serve_background propagates an occupied port immediately" {
    with socket.socket() as occupied {
        occupied.bind(('127.0.0.1', 0));
        occupied.listen();
        port = int(occupied.getsockname()[1]);
        srv = ServingServer(app=ServingApp(), host='127.0.0.1', port=port);
        seen: list[int] = [];
        started = time.monotonic();
        caught = _startup_error(srv, lambda (p: int) { seen.append(p); });
        assert isinstance(caught, PortInUseError) and caught.port == port , caught;
        assert time.monotonic() - started < 1.0 , "a known bind failure must wake the caller";
        assert seen == [] , seen;
    }
}


test "serve_background preserves boot and callback errors and closes its listener" {
    for stage in ('tls', 'server', 'callback') {
        with socket.socket() as available {
            available.bind(('127.0.0.1', 0));
            port = int(available.getsockname()[1]);
        }
        settings = ServeSettings();
        if stage == 'tls' {
            settings.tls = TlsSettings(certfile='missing-host-cert.pem');
        } elif stage == 'server' {
            settings.tls = _InvalidTls();
        }
        srv = _ObservedServingServer(
            app=ServingApp(), settings=settings, host='127.0.0.1', port=port
        );
        failure = ValueError('callback startup failed');
        def _fail_ready(_bound_port: int) {
            raise failure;
        }
        caught = _startup_error(srv, _fail_ready if stage == 'callback' else None);
        assert caught is srv.startup_error , stage;
        if stage == 'callback' {
            assert caught is failure;
        } elif stage == 'tls' {
            assert isinstance(caught, ServeConfigError) , caught;
        } else {
            assert isinstance(caught, TypeError) , caught;
        }
        with socket.socket() as replacement {
            replacement.bind(('127.0.0.1', port));
        }
    }
}


test "serve_background timeout suppresses late readiness and stops a delayed worker" {
    release = threading.Event();
    srv = _ObservedServingServer(
        app=ServingApp(), host='127.0.0.1', port=0, gate=release
    );
    seen: list[int] = [];
    caught: any = None;
    try {
        try {
            srv.serve_background(on_ready=lambda (p: int) { seen.append(p); });
        } except Exception as e {
            caught = e;
        }
        assert srv.entered.is_set() , "worker did not enter startup";
        assert isinstance(caught, TimeoutError) , caught;
        release.set();
        assert srv.finished.`wait(timeout=2) , "the late worker kept serving";
        assert seen == [] , "abandoned startup must not notify its host";
        assert srv.startup_error is None , srv.startup_error;
        assert srv._server is not None and not srv._server.is_serving();
    } finally {
        release.set();
        cleanup_deadline = time.monotonic() + 2;
        while not srv.finished.is_set()
            and srv._stop_event is None
            and time.monotonic() < cleanup_deadline {
            time.sleep(0.01);
        }
        if not srv.finished.is_set() and srv._stop_event is not None {
            srv.request_stop();
        }
        assert srv.finished.`wait(timeout=2) , "worker cleanup did not complete";
    }
}


test "API background startup unwinds scheduler and bridge preserving the original error" {
    tmp = _workspace();
    Jac.set_base_path(tmp);
    Jac.set_context(Jac.create_j_context(user_root=None));
    saved_consumers = dict(sv_client._consumer_providers);
    stop_worker();
    use_store(SqliteOutboxStore(path=os.path.join(tmp, 'outbox.sqlite')));
    try {
        set_config(None);
        base = os.path.join(tmp, 'web');
        Jac.set_full_target_path(os.path.join(base, 'main.jac'));
        sv_client.set_consumer_app('web');
        sv_client._declare_consumer_provider('web', 'feed');
        _load(tmp, 'main', base);
        settings = ServeSettings.load(base, {'host': '127.0.0.1', 'port': 0});
        failure = ValueError('transport startup failed');
        scheduler = _CleanupErrorScheduler();
        scheduler.register(
            'pending', lambda {}, ScheduleSpec(interval=60), is_walker=False
        );
        srv = JacAPIServer(
            module_name='main', base_path=base, settings=settings, extensions=[]
        );
        srv.scheduler = scheduler;
        workers: list[threading.Thread] = [];
        def _fail_ready(_bound_port: int) {
            assert scheduler._thread is not None and scheduler._thread.is_alive();
            worker = outbox_module._state.worker;
            assert worker is not None and worker.is_alive();
            workers.append(worker);
            raise failure;
        }
        assert _startup_error(srv, _fail_ready) is failure;
        assert scheduler.starts == 1 and scheduler.stops == 1;
        assert scheduler._thread is not None and not scheduler._thread.is_alive();
        assert len(workers) == 1 and not workers[0].is_alive() and not worker_running();
    } finally {
        stop_worker();
        use_store(None);
        sv_client._consumer_providers.clear();
        sv_client._consumer_providers.update(saved_consumers);
        _reset(tmp);
    }
}


test "serve_background binds loopback on an ephemeral port and serves a client_dist" {
    os.environ["JAC_SCALE_RUNTIME"] = "1";
    tmp = _workspace();
    Jac.set_base_path(tmp);
    Jac.set_context(Jac.create_j_context(user_root=None));
    stop: any = None;
    retry_stop: any = None;
    tick = threading.Event();
    try {
        set_config(None);
        Jac.set_full_target_path(os.path.join(tmp, "web", "main.jac"));
        sv_client.set_consumer_app("web");
        base = os.path.join(tmp, "web");
        _load(tmp, "main", base);
        settings = ServeSettings.load(
            base, {"host": "127.0.0.1", "port": 0, "client_dist": _dist(tmp)}
        );
        assert settings.port == 0 , "an explicit port 0 means ephemeral, not the config port";
        srv = JacAPIServer(
            module_name="main", port=0, base_path=base, settings=settings, extensions=[]
        );
        spec = ScheduleSpec(interval=0.05);
        srv.scheduler.register("tick", lambda { tick.set(); }, spec, is_walker=False);
        seen: list[int] = [];
        stop = srv.serve_background(on_ready=lambda (p: int) { seen.append(p); });
        assert seen and seen[0] > 0 , seen;
        assert srv.port == seen[0] , (srv.port, seen);
        origin = f"http://127.0.0.1:{seen[0]}";

        (code, body) = _get(f"{origin}/healthz/live");
        assert code == 200 , (code, body);

        (code, body) = _get(f"{origin}/");
        assert code == 200 and "hosted" in body , (code, body);
        (code, body) = _get(f"{origin}/assets/app.js");
        assert code == 200 and "hosted" in body , (code, body);
        (code, body) = _get(f"{origin}/some/client/route");
        assert code == 200 and "hosted" in body , (
            f"the SPA fallback must serve the client_dist index: {code} {body}"
        );

        (code, body) = _post(f"{origin}/walker/Hello", {"who": "loopback"});
        assert code == 200 and "hello loopback" in body , (code, body);
        (code, body) = _post(f"{origin}/api/web/walker/Hello", {"who": "routed"});
        assert code == 200 and "hello routed" in body , (code, body);

        assert tick.`wait(2) , "the first API's scheduled task never ran";
        worker = srv.scheduler._thread;
        assert worker is not None;
        with socket.socket() as occupied {
            occupied.bind(("127.0.0.1", 0));
            occupied.listen();
            port = occupied.getsockname()[1];
            dist = settings.client_dist;
            retry_cfg = ServeSettings.load(
                base, {"host": "127.0.0.1", "port": port, "client_dist": dist}
            );
            retry_srv = JacAPIServer(
                module_name="main", base_path=base, settings=retry_cfg, extensions=[]
            );
            assert isinstance(_startup_error(retry_srv), PortInUseError);
            failed_drain = retry_srv.drain;
        }
        peer_ok = [srv.scheduler._thread is worker and worker.is_alive()];
        for _ in range(2) {
            tick.clear();
            peer_ok.append(tick.`wait(2));
        }
        retry_stop = retry_srv.serve_background(port_retries=0);
        asset = f"http://127.0.0.1:{retry_srv.port}/assets/app.js";
        (code, body) = _get(asset);
        assert all(peer_ok) and code == 200 and "hosted" in body , (peer_ok, code);
        failed_drain.start("late cleanup");
        (code, body) = _get(asset);
        assert code == 200 and "hosted" in body , (code, body);
        jobs = JacScaleScheduler();
        jobs._server = srv;
        jobs.stop();
        assert not worker.is_alive() , "shutdown left the owned scheduler running";
    } finally {
        if retry_stop is not None {
            retry_stop();
        }
        if stop is not None {
            stop();
        }
        _reset(tmp);
    }
}


test "API background retries run each static task once and isolate earlier stop handles" {
    tmp = _workspace();
    Jac.set_base_path(tmp);
    Jac.set_context(Jac.create_j_context(user_root=None));
    stop: any = None;
    restarted_stop: any = None;
    try {
        set_config(None);
        base = os.path.join(tmp, "web");
        app = Path(base) / "main.jac";
        app.write_text(
            app.read_text()
                + "\nglob TICKS: list[int] = [];\n"
                + "@schedule(date=\"2099-01-01T00:00:00+00:00\", trigger=ScheduleTrigger.STATIC)\n"
                + "def:protect retry_tick { TICKS.append(1); }\n"
        );
        Jac.set_full_target_path(str(app));
        sv_client.set_consumer_app("web");
        _load(tmp, "main", base);
        with socket.socket() as occupied {
            occupied.bind(("127.0.0.1", 0));
            occupied.listen();
            settings = ServeSettings.load(
                base, {"host": "127.0.0.1", "port": occupied.getsockname()[1]}
            );
            srv = JacAPIServer(
                module_name="main", base_path=base, settings=settings, extensions=[]
            );
            for _ in range(2) {
                assert isinstance(_startup_error(srv), PortInUseError);
            }
        }
        stop = srv.serve_background(port_retries=0);
        for task in srv.scheduler._tasks {
            srv.scheduler._execute(task);
        }
        ticks = list(sys.modules["main"].TICKS);
        stop();
        restarted_stop = srv.serve_background(port_retries=0);
        worker = srv.scheduler._thread;
        assert worker is not None;
        stop();
        assert ticks == [1] and worker.is_alive() , (ticks, worker.is_alive());
    } finally {
        if restarted_stop is not None {
            restarted_stop();
        }
        if stop is not None {
            stop();
        }
        _reset(tmp);
    }
}


test "prepare_inprocess_runtime colocates the workspace's service apps" {
    os.environ["JAC_SCALE_RUNTIME"] = "1";
    tmp = _workspace();
    Jac.set_base_path(tmp);
    Jac.set_context(Jac.create_j_context(user_root=None));
    runtime: any = None;
    try {
        set_config(None);
        Jac.set_full_target_path(os.path.join(tmp, "web", "main.jac"));
        import from jaclang.scale.server.inprocess { prepare_inprocess_runtime }
        runtime = prepare_inprocess_runtime(
            os.path.join(tmp, "web", "main.jac"),
            os.path.join(tmp, "data"),
            endpoint_profile="desktop",
            setup_background_services=False
        );
        client = runtime.client;
        listing = client.get("/api/feed/walkers");
        assert listing.status_code == 200 , (
            f"the colocated service must be mounted: {listing.status_code} {listing.text}"
        );
        assert "Latest" in listing.text , listing.text;
        spawned = client.post("/api/feed/walker/Latest", json={});
        assert spawned.status_code == 200 and "\"a\"" in spawned.text , spawned.text;
        mine = client.post("/api/web/walker/Hello", json={"who": "self"});
        assert mine.status_code == 200 and "hello self" in mine.text , mine.text;
    } finally {
        if runtime is not None {
            runtime.close();
        }
        _reset(tmp);
    }
}
