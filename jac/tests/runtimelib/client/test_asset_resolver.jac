"""Conformance tests for unified static asset resolution.

One table drives the shared `AssetResolver`, and the same table is replayed
through both transport adapters (the dev `BaseHTTPRequestHandler` and the scale
FastAPI app). Divergence between the two servers is what this file exists to
prevent: an entry that passes at the resolver level but fails through an adapter
means an adapter is making a policy decision it has no business making.
"""

import io;
import pytest;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.runtimelib.client.assets {
    AssetOutcome,
    AssetPolicy,
    AssetResolver,
    AssetRoot,
    AssetRootMode,
    ASSET_MEDIA_TYPES,
    SOURCE_ONLY_EXTENSIONS,
    default_asset_roots,
    is_content_hashed,
    parse_byte_range
}

"""Build a project tree covering every root and every interesting file kind."""
def _make_project(base: Path) {
    files = {
        '.jac/client/dist/client.DEADBEEF.js': 'console.log(1)',
        '.jac/client/dist/styles.css': '.a{}',
        '.jac/client/dist/nested/deep.png': 'png-bytes',
        'dist/styles.css': '.stale{}',
        'dist/report.pdf': '%PDF-1.4',
        'public/robots.txt': 'User-agent: *',
        'assets/fonts/Inter.woff2': 'woff2-bytes',
        'assets/flat-only.svg': '<svg/>',
        'assets/data.json': '{}',
        'assets/theme.scss': '$c: red;',
        'assets/.env': 'SECRET=1',
        'secrets.json': '{"token": "leak"}',
        'src/app.js': 'export default 1;'
    };
    for (rel, body) in files.items() {
        target = base / rel;
        target.parent.mkdir(parents=True, exist_ok=True);
        target.write_text(body, encoding='utf-8');
    }
}

"""A resolver over `base` with the built-in defaults and no jac.toml involved."""
def _resolver(base: Path, dev: bool = False) -> AssetResolver {
    return AssetResolver(
        policy=AssetPolicy(
            roots=default_asset_roots(base),
            extensions=set(ASSET_MEDIA_TYPES.keys()),
            reserved_prefixes=['walker/', 'function/', 'user/', 'cl/', 'healthz'],
            dev=dev
        )
    );
}

"""(url, expected outcome, expected media type or '', note).

Media type is only asserted when non-empty.
"""
glob CASES: list[tuple[(str, str, str, str)]] = [
         (
             '/client.DEADBEEF.js',
             AssetOutcome.SERVED.value,
             'text/javascript; charset=utf-8',
             'build output at root'
         ),
         (
             '/static/client.DEADBEEF.js',
             AssetOutcome.SERVED.value,
             'text/javascript; charset=utf-8',
             'same file under the static prefix'
         ),
         (
             '/styles.css',
             AssetOutcome.SERVED.value,
             'text/css; charset=utf-8',
             'css is not a special case'
         ),
         (
             '/nested/deep.png',
             AssetOutcome.SERVED.value,
             'image/png',
             'nested path preserved'
         ),
         (
             '/fonts/Inter.woff2',
             AssetOutcome.SERVED.value,
             'font/woff2',
             'fonts serve without being listed anywhere'
         ),
         (
             '/report.pdf',
             AssetOutcome.SERVED.value,
             'application/pdf',
             'pdf served in both servers, not just scale'
         ),
         (
             '/robots.txt',
             AssetOutcome.SERVED.value,
             'text/plain; charset=utf-8',
             'public root is reachable'
         ),
         (
             '/data.json',
             AssetOutcome.SERVED.value,
             'application/json; charset=utf-8',
             'json asset'
         ),
         (
             '/sub/dir/flat-only.svg',
             AssetOutcome.SERVED.value,
             'image/svg+xml',
             'legacy basename fallback on a flatten root'
         ),
         (
             '/missing.png',
             AssetOutcome.NOT_FOUND.value,
             '',
             'known extension miss is a hard 404, never an SPA render'
         ),
         (
             '/static/missing-anything.xyz',
             AssetOutcome.NOT_FOUND.value,
             '',
             'anything under /static/ that misses is a hard 404'
         ),
         (
             '/dashboard/settings',
             AssetOutcome.NOT_AN_ASSET.value,
             '',
             'extensionless deep link falls through to the SPA router'
         ),
         (
             '/users/v1.2/profile',
             AssetOutcome.NOT_AN_ASSET.value,
             '',
             'a dot in a route segment is not an asset request'
         ),
         (
             '/walker/create_item',
             AssetOutcome.NOT_AN_ASSET.value,
             '',
             'reserved prefixes belong to the router'
         ),
         (
             '/theme.scss',
             AssetOutcome.FORBIDDEN.value,
             '',
             'bundler input is never served'
         ),
         ('/.env', AssetOutcome.FORBIDDEN.value, '', 'dotfiles are never served'),
         (
             '/../secrets.json',
             AssetOutcome.FORBIDDEN.value,
             '',
             'traversal out of every root'
         ),
         (
             '/..%2Fsecrets.json',
             AssetOutcome.FORBIDDEN.value,
             '',
             'percent-encoded traversal is decoded before the check'
         ),
         (
             '/nested/../../secrets.json',
             AssetOutcome.FORBIDDEN.value,
             '',
             'traversal from a nested path'
         ),
         ('/src/app.js', AssetOutcome.NOT_FOUND.value, '', 'src/ is not a served root'),
         (
             '/secrets.json',
             AssetOutcome.NOT_FOUND.value,
             '',
             'the project root itself is not a served root'
         )
     ];

test "resolver conformance table" {
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        _make_project(base);
        resolver = _resolver(base);
        failures: list[str] = [];
        for (url, expected, media, note) in CASES {
            got = resolver.resolve(url);
            if got.outcome != expected {
                failures.append(
                    f"{url}: expected {expected}, got {got.outcome} ({note})"
                );
                continue;
            }
            if media and (got.media_type != media) {
                failures.append(
                    f"{url}: expected media {media}, got {got.media_type} ({note})"
                );
            }
        }
        assert not failures , "\n".join(failures);
    }
}

test "build output wins over a stale checked-in dist" {
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        _make_project(base);
        got = _resolver(base).resolve('/styles.css');
        assert got.is_served();
        assert got.path.read_text(encoding='utf-8') == '.a{}';
    }
}

test "cache policy follows provenance not code path" {
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        _make_project(base);
        prod = _resolver(base);
        hashed = prod.resolve('/client.DEADBEEF.js');
        assert hashed.cache_control == 'public, max-age=31536000, immutable';
        plain = prod.resolve('/styles.css');
        assert plain.cache_control == 'no-cache';
        busted = prod.resolve('/styles.css', 'hash=abcd1234');
        assert busted.cache_control == 'public, max-age=31536000, immutable';
        dev = _resolver(base, dev=True);
        assert dev.resolve('/styles.css').cache_control == 'no-store';
        assert dev.resolve('/client.DEADBEEF.js').cache_control == 'public, max-age=31536000, immutable';
    }
}

test "served assets carry validators and answer conditional requests" {
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        _make_project(base);
        resolver = _resolver(base);
        got = resolver.resolve('/styles.css');
        assert got.etag;
        assert got.last_modified;
        assert got.is_fresh(if_none_match=got.etag);
        assert got.is_fresh(if_none_match=f'W/{got.etag}');
        assert got.is_fresh(if_none_match='*');
        assert not got.is_fresh(if_none_match='"nope"');
        assert got.is_fresh(if_modified_since=got.last_modified);
        assert not got.is_fresh(if_modified_since='Thu, 01 Jan 1970 00:00:00 GMT');
        missing = resolver.resolve('/missing.png');
        assert not missing.is_fresh(if_none_match='*');
    }
}

test "content hash detection" {
    hashed = ['client.DEADBEEF.js', 'index-DsUxa2sh.js', 'app.a1b2c3d4.css'];
    plain = [
        'styles.css',
        'logo.png',
        'hero-illustration.svg',
        'my-component.js',
        'background-image01.png',
        'background-image001.png',
        'Inter-Regular.woff2',
        'index.html'
    ];
    for name in hashed {
        assert is_content_hashed(name) , f"{name} should read as content-hashed";
    }
    for name in plain {
        assert not is_content_hashed(name) , f"{name} should not read as hashed";
    }
}

test "custom extensions extend rather than replace" {
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        _make_project(base);
        (base / 'assets' / 'manual.dat').write_text('x', encoding='utf-8');
        narrow = AssetResolver(
            policy=AssetPolicy(
                roots=default_asset_roots(base),
                extensions={'.dat'},
                reserved_prefixes=[]
            )
        );
        # The historical bug: configuring one extension used to drop every
        # default, so fonts 404'd. Presence on disk is what serves a file now.
        assert narrow.resolve('/fonts/Inter.woff2').is_served();
        assert narrow.resolve('/manual.dat').is_served();
        assert narrow.resolve('/missing.dat').outcome == AssetOutcome.NOT_FOUND.value;
    }
}

test "declared roots are confined to the project" {
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        _make_project(base);
        escaped = AssetResolver(
            policy=AssetPolicy(
                roots=[
                    AssetRoot(
                        path=base / 'assets',
                        mode=AssetRootMode.SOURCE_ASSET.value,
                        flatten=False
                    )
                ],
                extensions=set(ASSET_MEDIA_TYPES.keys()),
                reserved_prefixes=[]
            )
        );
        assert escaped.resolve('/fonts/Inter.woff2').is_served();
        assert escaped.resolve('/flat-only.svg').is_served();
        # flatten is off, so the basename fallback must not fire
        assert escaped.resolve('/sub/dir/flat-only.svg').outcome == AssetOutcome.NOT_FOUND.value;
    }
}

test "source only extensions are never served" {
    for ext in SOURCE_ONLY_EXTENSIONS {
        assert ext not in ASSET_MEDIA_TYPES , f"{ext} is both servable and denied";
    }
}

"""The client-only preview server must report the same media types.

`jac serve` on a `web-static` build runs a third, much smaller handler over the
dist directory. It has no roots or cache policy to share, but a build previewed
there must not report different content types than the servers that will ship
it, and it must not fall through to the host's mime database.
"""
test "static preview server uses the shared media table" {
    import from jaclang.runtimelib.client.targets.static_target { _DistRequestHandler }
    probe = _DistRequestHandler.__new__(_DistRequestHandler);
    for (ext, expected) in {
        '.wasm': 'application/wasm',
        '.woff2': 'font/woff2',
        '.avif': 'image/avif',
        '.js': 'text/javascript; charset=utf-8',
        '.svg': 'image/svg+xml'
    }.items() {
        assert probe.guess_type(f"/dist/main{ext}") == expected , (
            f"{ext} diverged from the shared table"
        );
    }
}

"""A BaseHTTPRequestHandler stand-in that records what the adapter wrote."""
obj _RecordingHandler {
    has headers: dict[str, str] = {},
        status: int = 0,
        sent: dict[str, str] = {},
        body: bytes = b'',
        wfile: io.BytesIO = io.BytesIO();

    def send_response(code: int) {
        self.status = code;
    }

    def send_header(key: str, value: str) {
        self.sent[key] = value;
    }

    def end_headers { }
}

"""Drive the dev adapter and report (status, headers, body)."""
def _via_dev_adapter(
    resolution: any, request_headers: (dict[(str, str)] | None) = None
) -> _RecordingHandler {
    import from jaclang.runtimelib.client.serving { JacClient }
    handler = _RecordingHandler(headers=request_headers or {});
    handler.wfile = io.BytesIO();
    JacClient.send_asset(handler, resolution);
    handler.body = handler.wfile.getvalue();
    return handler;
}

test "dev adapter mirrors the resolution it is given" {
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        _make_project(base);
        resolver = _resolver(base);
        served = _via_dev_adapter(resolver.resolve('/fonts/Inter.woff2'));
        assert served.status == 200;
        assert served.sent['Content-Type'] == 'font/woff2';
        assert served.sent['Cache-Control'] == 'no-cache';
        assert served.sent['Accept-Ranges'] == 'bytes';
        assert served.body == b'woff2-bytes';
        local = _via_dev_adapter(
            _resolver(base, dev=True).resolve('/fonts/Inter.woff2')
        );
        assert local.sent['Cache-Control'] == 'no-store';
        missing = _via_dev_adapter(resolver.resolve('/missing.png'));
        assert missing.status == 404;
        # A missed asset must never come back as an HTML page.
        assert missing.sent['Content-Type'] == 'text/plain; charset=utf-8';
        denied = _via_dev_adapter(resolver.resolve('/../secrets.json'));
        assert denied.status == 403;
    }
}

test "dev adapter answers conditional and range requests" {
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        _make_project(base);
        resolver = _resolver(base);
        first = _via_dev_adapter(resolver.resolve('/fonts/Inter.woff2'));
        etag = first.sent['ETag'];
        cached = _via_dev_adapter(
            resolver.resolve('/fonts/Inter.woff2'), {'If-None-Match': etag}
        );
        assert cached.status == 304;
        assert cached.body == b'';
        ranged = _via_dev_adapter(
            resolver.resolve('/fonts/Inter.woff2'), {'Range': 'bytes=0-3'}
        );
        assert ranged.status == 206;
        assert ranged.body == b'woff';
        assert ranged.sent['Content-Range'] == 'bytes 0-3/11';
        suffix = _via_dev_adapter(
            resolver.resolve('/fonts/Inter.woff2'), {'Range': 'bytes=-5'}
        );
        assert suffix.status == 206;
        assert suffix.body == b'bytes';
        bad = _via_dev_adapter(
            resolver.resolve('/fonts/Inter.woff2'), {'Range': 'bytes=99-200'}
        );
        assert bad.status == 200 , "an unsatisfiable range falls back to the whole body";
    }
}

test "byte range parsing" {
    assert parse_byte_range('bytes=0-3', 10) == (0, 3);
    assert parse_byte_range('bytes=5-', 10) == (5, 9);
    assert parse_byte_range('bytes=-4', 10) == (6, 9);
    assert parse_byte_range('bytes=0-99', 10) == (0, 9);
    assert parse_byte_range(None, 10) is None;
    assert parse_byte_range('bytes=10-12', 10) is None;
    assert parse_byte_range('bytes=0-3,6-8', 10) is None , "multi-range is declined";
    assert parse_byte_range('items=0-3', 10) is None;
    assert parse_byte_range('bytes=abc', 10) is None;
    assert parse_byte_range('bytes=0-3', 0) is None;
}

"""Both servers must answer the same table identically.

The dev adapter is exercised in-process above; the scale adapter is exercised
here through the same resolution values. If these ever disagree, an adapter has
grown a policy decision that belongs in the resolver.
"""
test "both adapters agree on status and headers" {
    pytest.importorskip('fastapi');
    import from fastapi { Request }
    import from jaclang.scale.server.serve { JacAPIServerStatic }
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        _make_project(base);
        resolver = _resolver(base);
        scale = JacAPIServerStatic();
        def _scale_request(headers: dict[(str, str)]) -> Request {
            raw = [
                (key.lower().encode(), value.encode())
                for (key, value) in headers.items()
            ];
            return Request({'type': 'http', 'method': 'GET', 'headers': raw});
        }
        probes = [
            ('/fonts/Inter.woff2', {}, 200),
            ('/missing.png', {}, 404),
            ('/../secrets.json', {}, 403),
            ('/theme.scss', {}, 403)
        ];
        for (url, req_headers, expected_status) in probes {
            resolution = resolver.resolve(url);
            dev = _via_dev_adapter(resolution, req_headers);
            prod = scale.asset_response(resolution, _scale_request(req_headers));
            assert dev.status == expected_status , f"{url} dev status";
            assert prod.status_code == expected_status , f"{url} scale status";
            assert dev.sent['Cache-Control'] == prod.headers['cache-control'] , f"{url} cache directive diverged";
            if expected_status == 200 {
                assert dev.sent['Content-Type'] == prod.headers['content-type'] , f"{url} content type diverged";
                assert dev.body == prod.body , f"{url} body diverged";
                assert dev.sent['ETag'] == prod.headers['etag'] , f"{url} etag diverged";
            }
        }
    }
}
