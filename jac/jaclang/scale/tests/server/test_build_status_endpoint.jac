"""The server serves the dev-loop status document the hot reloader holds.

`GET /__build_status` must hand back the same `{"status": ..., "diagnostics":
[...]}` value the hot reloader holds. This exercises the registration
directly: `register_diagnostics_endpoints` against a recording host, then the
endpoint's own callback.
"""

import asyncio;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.server.hmr { HotReloader }
import from jaclang.server.watcher { JacFileWatcher }

obj _CapturedServer {
    has endpoints: list = [],
        base_path: str = "";

    def add_endpoint(ep: any) {
        self.endpoints.append(ep);
    }
}

"""Return every process-global this file touches to its default.

Test workers are pooled, so a live HotReloader or a latched rate limiter would
ride into whatever runs next in the same worker.
"""
def _reset_client_globals {
    import from jaclang.client.source_mapping {
        _locator_cache,
        _mapper_cache,
        _error_rate_limiter
    }
    _locator_cache.clear();
    _mapper_cache.clear();
    _error_rate_limiter._seen = {};
    _error_rate_limiter._count = 0;
    _error_rate_limiter._window_start = 0.0;
    active = HotReloader._active;
    if active is not None {
        active.stop();
    }
    HotReloader._active = None;
}

def _reloader(base: Path) -> HotReloader {
    _reset_client_globals();
    watcher = JacFileWatcher(watch_paths=[str(base)], _debounce_ms=50);
    return HotReloader(base_path=str(base), module_name="app", watcher=watcher);
}

test "the scale build status route serves the status document shape" {
    import from jaclang.server.endpoints.pages { register_diagnostics_endpoints }
    import from jaclang.server.serving.datatypes { Request }
    with TemporaryDirectory() as tmp {
        stub = _CapturedServer(base_path=tmp);
        register_diagnostics_endpoints(stub);
        status_eps = [
            e
            for e in stub.endpoints
            if e.path == "/__build_status"
        ];
        assert len(status_eps) == 1;
        ep = status_eps[0];
        body = asyncio.run(ep.callback(Request())).content;
        assert body == {"status": "unavailable", "diagnostics": []} , body;
        reloader = _reloader(Path(tmp));
        try {
            reloader.start();
            reloader.record_error("main.jac", "boom");
            body = asyncio.run(ep.callback(Request())).content;
            assert body["status"] == "error" , body;
            assert body["diagnostics"][0]["file"] == "main.jac" , body;
            assert body["diagnostics"][0]["rendered"].startswith("error[") , body;
        } finally {
            reloader.stop();
            _reset_client_globals();
        }
    }
}
