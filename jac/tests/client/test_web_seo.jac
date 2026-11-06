"""`[client.seo]` makes a web build write `robots.txt` and `sitemap.xml` from the
app's routes, and every server that answers `/robots.txt` tells a host other than
`site_url` to stay out (#9456)."""

import tempfile;
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.client.route_scanner { RouteEntry }
import from jaclang.client.targets.seo_build {
    crawl_rules,
    normalized_site_url,
    render_robots,
    robots_blocks,
    sitemap_paths
}
import from jaclang.client.targets.web_target { WebTarget }
import from jaclang.client.vite_bundler { ViteBundler }
import from jaclang.runtime.runtime { JacRuntime as Jac }
import from jaclang.project.client_paths { client_seo_config }
import from jaclang.project.config { JacConfig, ServeConfigError }
import from jaclang.server.static_files {
    DISALLOW_ALL_ROBOTS,
    logger as serve_logger,
    robots_override
}

glob SITE: str = "https://example.org",
     PREVIEW_HOST: str = "pr-12.preview.example.net",
     HAND_WRITTEN: str = "User-agent: *\nDisallow: /secret\n";

def route(
    path: str, auth: bool = False, layout: bool = False, catch_all: bool = False
) -> RouteEntry {
    return RouteEntry(
        path=path,
        component_import="Page",
        file_path=Path("page.jac"),
        source_export="Page",
        auth_required=auth,
        is_layout=layout,
        is_catch_all=catch_all
    );
}

"""A single-app project whose `[client.seo]` body is `seo` (none when empty)."""
def make_project(
    project_dir: Path, seo: str, pages: dict[str, str], public: dict[str, str]
) -> Path {
    entry_path = project_dir / "main.jac";
    entry_path.write_text(
        'def:pub app(children: any) -> JsxElement { return <div>{children}</div>; }'
    );
    toml = '[project]\nname = "site"\nkind = "web-app"\n';
    if seo {
        toml += f"\n[client.seo]\n{seo}\n";
    }
    (project_dir / "jac.toml").write_text(toml);
    (project_dir / "package.json").write_text('{"name":"site","version":"0.0.0"}');
    for (rel, body) in pages.items() {
        path = project_dir / "pages" / rel;
        path.parent.mkdir(parents=True, exist_ok=True);
        path.write_text(body);
    }
    for (rel, text) in public.items() {
        path = project_dir / "public" / rel;
        path.parent.mkdir(parents=True, exist_ok=True);
        path.write_text(text);
    }
    return entry_path;
}

"""Run `WebTarget.build` with the Vite step writing a stub `client.test.js`, and
return the dist directory."""
def build_web(project_dir: Path, entry_path: Path) -> Path {
    previous = Jac.get_full_target_path();
    Jac.set_full_target_path(str(entry_path));
    def bundle(self: ViteBundler, *args: any, **kwargs: any) {
        self.output_dir.mkdir(parents=True, exist_ok=True);
        (self.output_dir / "client.test.js").write_text('export function app() {}');
    }
    try {
        with patch.object(ViteBundler, "build", bundle) {
            bundle_path = WebTarget().build(entry_path, project_dir);
        }
    } finally {
        Jac.set_full_target_path(previous);
    }
    return bundle_path.parent;
}

"""RFC 9309: the longest matching rule decides, and Allow wins a tie."""
def crawlable(path: str, allows: list[str], disallows: list[str]) -> bool {
    allowed = max(
        [
            len(r)
            for r in allows
            if robots_blocks(r, path)
        ],
        `default=-1
    );
    blocked = max(
        [
            len(r)
            for r in disallows
            if robots_blocks(r, path)
        ],
        `default=-1
    );
    return allowed >= blocked;
}

def header(resp: any, name: str) -> str {
    for (key, value) in dict(resp.headers).items() {
        if key.lower() == name {
            return str(value);
        }
    }
    return "";
}

def page(name: str) -> str {
    return f'def:pub {name}() -> JsxPage {{ return <div>{name}</div>; }}';
}

test "the sitemap lists public pages only, with exclude and extra applied" {
    routes = [
        route("/"),
        route("/about"),
        route("/docs/intro"),
        route("/dashboard", auth=True),
        route("/users/:id"),
        route("/files/*", catch_all=True),
        route("/", layout=True)
    ];
    rows = [
        ("scanned routes", routes, [], [], ["/", "/about", "/docs/intro"]),
        ("exclude", routes, ["/about"], [], ["/", "/docs/intro"]),
        (
            "extra",
            routes,
            [],
            ["/blog/launch", "faq"],
            ["/", "/about", "/docs/intro", "/blog/launch", "/faq"]
        ),
        ("no file routes", [], [], [], ["/"]),
        (
            "paths are percent-encoded",
            [],
            [],
            ["/café menu", "/caf%C3%A9%20menu", "/search?q=a&b=c"],
            ["/", "/caf%C3%A9%20menu", "/search?q=a&b=c"]
        )
    ];
    for (label, scanned, exclude, extra, want) in rows {
        got = sitemap_paths(scanned, exclude, extra);
        assert got == want , f"{label}: {got}";
    }
}

test "robots.txt keeps protected routes out but never the bundle, stylesheet or a sitemap URL" {
    rows = [
        (
            "protected routes and disallow",
            [
                route("/"),
                route("/dashboard", auth=True),
                route("/users/:id/settings", auth=True)
            ],
            ["/internal", "admin"],
            ["/dashboard$", "/dashboard/", "/users/", "/internal", "/admin"],
            ["/"],
            []
        ),
        (
            "an (auth) home",
            [route("/", auth=True), route("/about"), route("/pricing")],
            [],
            ["/$"],
            ["/about", "/pricing"],
            []
        ),
        (
            "an (auth) route a public route starts with",
            [route("/admin", auth=True), route("/administrators-guide")],
            [],
            ["/admin$", "/admin/"],
            ["/administrators-guide"],
            []
        ),
        (
            "a dynamic (auth) route beside a public page",
            [
                route("/:org", auth=True),
                route("/users/:id", auth=True),
                route("/about")
            ],
            [],
            ["/", "/users/"],
            ["/about"],
            ["/about$"]
        ),
        (
            "a disallowed page leaves the sitemap",
            [route("/"), route("/internal/docs")],
            ["/internal"],
            ["/internal"],
            ["/"],
            []
        )
    ];
    for (label, routes, listed, want_disallows, want_paths, want_allows) in rows {
        (paths, allows, disallows) = crawl_rules(routes, [], [], listed);
        assert disallows == want_disallows , f"{label}: {disallows}";
        assert paths == want_paths , f"{label}: sitemap {paths}";
        assert allows == want_allows , f"{label}: allows {allows}";
        for path in paths {
            assert crawlable(path, allows, disallows) , (
                f"{label}: robots.txt blocks sitemap URL {path}: {disallows}"
            );
            if not allows {
                assert not any(robots_blocks(r, path) for r in disallows) , (
                    f"{label}: a Disallow matches sitemap URL {path}: {disallows}"
                );
            }
        }
    }
    text = render_robots(SITE, ["/dashboard$"], ["/client.abc123.js", "/styles.css"]);
    lines = text.splitlines();
    assert lines[0] == "User-agent: *" , text;
    for asset in ["/client.abc123.js", "/styles.css"] {
        assert f"Allow: {asset}" in lines , f"robots.txt may block {asset}:\n{text}";
    }
    assert "Disallow: /dashboard$" in lines , text;
    assert f"Sitemap: {SITE}/sitemap.xml" in lines , text;
    open_text = render_robots(SITE, [], ["/client.abc123.js"]);
    assert "Allow: /" in open_text.splitlines() , open_text;
    assert "Disallow" not in open_text , open_text;
}

test "[client.seo] needs an absolute http(s) site_url and lists of strings" {
    assert normalized_site_url("https://example.org/") == SITE;
    for bad in ["example.org", "/docs", "ftp://example.org", "https://"] {
        try {
            normalized_site_url(bad);
            assert False , f"accepted site_url {bad!r}";
        } except RuntimeError as err {
            assert "site_url" in str(err) , f"{bad!r}: {err}";
        }
    }
    good = f'[client.seo]\nsite_url = "{SITE}"\nsite_hosts = ["www.example.org"]\n'
        + '[client.seo.sitemap]\nexclude = ["/a"]\nextra = ["/b"]\n'
        + '[client.seo.robots]\ndisallow = ["/c"]\n';
    seo = client_seo_config(JacConfig.from_toml_str(good));
    assert seo["site_hosts"] == ["www.example.org"] , seo;
    rows = [
        ("exclude", '[client.seo.sitemap]\nexclude = "/about"\n'),
        ("extra", '[client.seo.sitemap]\nextra = [1]\n'),
        ("disallow", '[client.seo.robots]\ndisallow = "/internal"\n'),
        ("site_hosts", '[client.seo]\nsite_hosts = "www.example.org"\n'),
        ("site_urll", '[client.seo]\nsite_urll = "https://example.org"\n'),
        ("[client.seo]", '[client]\nseo = "https://example.org"\n')
    ];
    for (key, toml) in rows {
        try {
            client_seo_config(JacConfig.from_toml_str(toml));
            assert False , f"accepted {toml!r}";
        } except ServeConfigError as err {
            assert key in str(err) , f"{toml!r}: {err}";
        }
    }
}

test "robots.txt on a host other than site_url disallows everything" {
    cdn_origin = "origin.cdn.example.net";
    rows = [
        ("canonical host", SITE, "example.org", [], None),
        ("canonical host with a port", SITE, "example.org:443", [], None),
        ("host in another case", SITE, "Example.ORG", [], None),
        ("host with a trailing dot", SITE, "example.org.", [], None),
        ("preview host", SITE, PREVIEW_HOST, [], DISALLOW_ALL_ROBOTS),
        ("www host", SITE, "www.example.org", [], DISALLOW_ALL_ROBOTS),
        ("www host in site_hosts", SITE, "www.example.org", ["WWW.example.org"], None),
        (
            "CDN origin host in site_hosts",
            SITE,
            f"{cdn_origin}:8080",
            [cdn_origin],
            None
        ),
        ("malformed host", SITE, "[::1", [], DISALLOW_ALL_ROBOTS),
        ("no site_url", "", PREVIEW_HOST, [], None)
    ];
    for (label, site_url, host, site_hosts, want) in rows {
        got = robots_override(site_url, host, site_hosts);
        assert got == want , f"{label}: {got!r}";
    }
    with patch.object(serve_logger, "warning") as warning {
        for _ in range(2) {
            robots_override(SITE, "once.preview.example.net", []);
        }
    }
    assert warning.call_count == 1 , warning.call_args_list;
    assert "once.preview.example.net" in str(warning.call_args) , warning.call_args;
}

test "a build with site_url writes robots.txt and sitemap.xml from its pages" {
    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp).resolve();
        pages = {
            "index.jac": page("Home"),
            "about.jac": page("About"),
            "(auth)/dashboard.jac": page("Dashboard"),
            "users/[id].jac": page("User")
        };
        seo = f'site_url = "{SITE}/"\n[client.seo.sitemap]\n'
            + 'extra = ["/search?q=a&b=c", "/café menu"]';
        entry_path = make_project(project_dir, seo, pages, {});
        dist = build_web(project_dir, entry_path);
        sitemap = (dist / "sitemap.xml").read_text();
        for path in ["/", "/about", "/search?q=a&amp;b=c", "/caf%C3%A9%20menu"] {
            assert f"<loc>{SITE}{path}</loc>" in sitemap , f"{path} missing:\n{sitemap}";
        }
        for path in ["/dashboard", "/users"] {
            assert f"{SITE}{path}" not in sitemap , f"{path} listed:\n{sitemap}";
        }
        assert "lastmod" not in sitemap , sitemap;
        robots = (dist / "robots.txt").read_text();
        robots_lines = robots.splitlines();
        assert "Disallow: /dashboard$" in robots_lines , robots;
        assert "Allow: /client.test.js" in robots_lines , robots;
        assert f"Sitemap: {SITE}/sitemap.xml" in robots_lines , robots;
        (project_dir / "pages" / "contact.jac").write_text(page("Contact"));
        dist = build_web(project_dir, entry_path);
        assert f"<loc>{SITE}/contact</loc>" in (dist / "sitemap.xml").read_text() , (
            "a page added under pages/ did not reach the sitemap on the next build"
        );
    }
}

test "a hand-written public/robots.txt wins over the generated one" {
    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp).resolve();
        entry_path = make_project(
            project_dir,
            f'site_url = "{SITE}"',
            {"index.jac": page("Home")},
            {"robots.txt": HAND_WRITTEN}
        );
        dist = build_web(project_dir, entry_path);
        assert (dist / "robots.txt").read_text() == HAND_WRITTEN , (
            "the generated robots.txt replaced the hand-written one"
        );
        assert (dist / "sitemap.xml").is_file() , (
            "the sitemap is still generated when only robots.txt is hand-written"
        );
    }
}

test "a rebuild drops the robots.txt and sitemap.xml the last build generated" {
    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp).resolve();
        entry_path = make_project(
            project_dir, f'site_url = "{SITE}"', {"index.jac": page("Home")}, {}
        );
        dist = build_web(project_dir, entry_path);
        assert (dist / "robots.txt").is_file() and (dist / "sitemap.xml").is_file();
        (project_dir / "public").mkdir();
        (project_dir / "public" / "robots.txt").write_text(HAND_WRITTEN);
        dist = build_web(project_dir, entry_path);
        assert (dist / "robots.txt").read_text() == HAND_WRITTEN , (
            "the hand-written robots.txt did not replace the last build's generated one"
        );
        (project_dir / "public" / "robots.txt").unlink();
        (project_dir / "jac.toml").write_text(
            '[project]\nname = "site"\nkind = "web-app"\n'
        );
        dist = build_web(project_dir, entry_path);
        assert not (dist / "robots.txt").exists() , (
            "robots.txt from an earlier build survived removing site_url"
        );
        assert not (dist / "sitemap.xml").exists() , (
            "sitemap.xml from an earlier build survived removing site_url"
        );
    }
}

test "without site_url the build writes neither file" {
    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp).resolve();
        entry_path = make_project(project_dir, "", {"index.jac": page("Home")}, {});
        dist = build_web(project_dir, entry_path);
        assert (dist / "index.html").is_file() , "the build did not finish";
        assert not (dist / "robots.txt").exists() , "robots.txt written without site_url";
        assert not (dist / "sitemap.xml").exists() , "sitemap.xml written without site_url";
    }
}

test "the gateways and jac run --serve answer robots.txt per host" {
    import from jaclang.scale.runtime.gateway.embedded_gateway { EmbeddedGateway }
    import from jaclang.scale.runtime.gateway.microservice_gateway {
        MicroserviceGateway
    }
    import from jaclang.scale.runtime.gateway.service_registry {
        ServiceEntry,
        ServiceRegistry
    }
    import from jaclang.scale.runtime.transport.transport { InProcessTransport }
    import from jaclang.testing.testing { JacTestClient }
    import from jaclang.testing.testkit { ServingTestClient }
    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp).resolve();
        (project_dir / "jac.toml").write_text(
            f'[project]\nname = "site"\n\n[client.seo]\nsite_url = "{SITE}"\n'
        );
        (project_dir / "main.jac").write_text(
            'def:pub ping -> str { return "pong"; }\n'
        );
        public = project_dir / "public";
        public.mkdir();
        (public / "robots.txt").write_text(HAND_WRITTEN);
        (public / "sitemap.xml").write_text("<urlset></urlset>\n");
        microservice = MicroserviceGateway(
            registry=ServiceRegistry(),
            client_dist_dir=str(public),
            base_path=str(project_dir)
        );
        microservice.setup();
        embedded = EmbeddedGateway(
            registry=ServiceRegistry(),
            transport=InProcessTransport(),
            client_dist_dir=str(public),
            base_path=str(project_dir)
        );
        embedded.setup();
        server = JacTestClient.from_file(
            str(project_dir / "main.jac"), base_path=str(project_dir)
        );
        servers: list[tuple[str, any]] = [
            ("microservice gateway", ServingTestClient(microservice.app)),
            ("embedded gateway", ServingTestClient(embedded.app)),
            ("jac run --serve", server)
        ];
        try {
            for (label, client) in servers {
                canonical = client.get("/robots.txt", headers={"host": "example.org"});
                assert canonical.status_code == 200 , f"{label}: {canonical.status_code}";
                assert canonical.text == HAND_WRITTEN , f"{label}: {canonical.text!r}";
                assert "text/plain" in header(canonical, "content-type") , label;
                preview = client.get("/robots.txt", headers={"host": PREVIEW_HOST});
                assert preview.status_code == 200 , f"{label}: {preview.status_code}";
                assert preview.text == DISALLOW_ALL_ROBOTS , (
                    f"{label} served the production robots.txt to a preview host"
                );
                assert "text/plain" in header(preview, "content-type") , label;
                sitemap = client.get("/sitemap.xml", headers={"host": "example.org"});
                assert sitemap.status_code == 200 , f"{label}: {sitemap.status_code}";
                assert "xml" in header(sitemap, "content-type") , label;
                for (what, resp) in [
                    ("robots.txt", canonical),
                    ("the preview robots.txt", preview),
                    ("sitemap.xml", sitemap)
                ] {
                    assert header(resp, "cache-control") == "no-cache" , (
                        f"{label} sends {what} with Cache-Control "
                        f"{header(resp, 'cache-control')!r}, not no-cache"
                    );
                }
            }
        } finally {
            server.close();
        }
    }
    with tempfile.TemporaryDirectory() as tmp {
        workspace = Path(tmp).resolve();
        for name in ("web", "api") {
            (workspace / name).mkdir();
            (workspace / name / "main.jac").write_text(
                'def:pub ping -> str { return "pong"; }\n'
            );
        }
        (workspace / "jac.toml").write_text(
            '[project]\nname = "ws"\n\n'
                + '[apps.web]\nkind = "web-app"\nentry-point = "web.main"\n\n'
                + '[apps.api]\nkind = "service"\nentry-point = "api.main"\n\n'
                + f'[apps.web.client.seo]\nsite_url = "{SITE}"\n'
        );
        (workspace / "robots.txt").write_text(HAND_WRITTEN);
        registry = ServiceRegistry();
        registry.register(
            ServiceEntry(name="web", file="web/main.jac", prefix="/web", is_root=True)
        );
        gateways: list[tuple[str, any]] = [
            (
                "microservice gateway",
                MicroserviceGateway(
                    registry=registry,
                    client_dist_dir=str(workspace),
                    base_path=str(workspace)
                )
            ),
            (
                "embedded gateway",
                EmbeddedGateway(
                    registry=registry,
                    transport=InProcessTransport(),
                    client_dist_dir=str(workspace),
                    base_path=str(workspace)
                )
            )
        ];
        for (label, gateway) in gateways {
            gateway.setup();
            client = ServingTestClient(gateway.app);
            preview = client.get("/robots.txt", headers={"host": PREVIEW_HOST});
            assert preview.text == DISALLOW_ALL_ROBOTS , (
                f"{label} in a workspace without default-app served the "
                f"production robots.txt to a preview host: {preview.text!r}"
            );
            canonical = client.get("/robots.txt", headers={"host": "example.org"});
            assert canonical.text == HAND_WRITTEN , f"{label}: {canonical.text!r}";
        }
    }
}

"""GET `target` over a raw socket with `headers`; returns (status, body)."""
def raw_get(port: int, target: str, headers: dict[str, str]) -> tuple[int, bytes] {
    import socket;
    lines = [f"GET {target} HTTP/1.1"]
        + [f"{name}: {value}" for (name, value) in headers.items()]
        + ["Connection: close", "", ""];
    sock = socket.create_connection(("127.0.0.1", port), timeout=5);
    data = b"";
    try {
        sock.sendall("\r\n".join(lines).encode());
        while True {
            chunk = sock.recv(65536);
            if not chunk {
                break;
            }
            data += chunk;
        }
    } finally {
        sock.close();
    }
    (head, _, body) = data.partition(b"\r\n\r\n");
    return (int(head.split(b" ", 2)[1]), body);
}

test "robots.txt takes X-Forwarded-Host only from a proxy in [serve.proxy] trusted" {
    import from jaclang.scale.runtime.gateway.microservice_gateway {
        MicroserviceGateway
    }
    import from jaclang.scale.runtime.gateway.service_registry { ServiceRegistry }
    import from jaclang.server.serving.server { ServingServer }
    import from jaclang.server.settings { ProxySettings, ServeSettings }
    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp).resolve();
        (project_dir / "jac.toml").write_text(
            f'[project]\nname = "site"\n\n[client.seo]\nsite_url = "{SITE}"\n'
        );
        public = project_dir / "public";
        public.mkdir();
        (public / "robots.txt").write_text(HAND_WRITTEN);
        gateway = MicroserviceGateway(
            registry=ServiceRegistry(),
            client_dist_dir=str(public),
            base_path=str(project_dir)
        );
        gateway.setup();
        trusted = ["127.0.0.1/32"];
        rows = [
            (
                "a trusted proxy forwards the canonical host",
                trusted,
                {"Host": "web:8000", "X-Forwarded-Host": "example.org"},
                HAND_WRITTEN
            ),
            (
                "a trusted proxy forwards a preview host",
                trusted,
                {
                    "Host": "web:8000",
                    "X-Forwarded-Host": f"{PREVIEW_HOST}, example.org"
                },
                DISALLOW_ALL_ROBOTS
            ),
            (
                "an untrusted client claims the canonical host",
                [],
                {"Host": PREVIEW_HOST, "X-Forwarded-Host": "example.org"},
                DISALLOW_ALL_ROBOTS
            ),
            (
                "an untrusted client claims a preview host",
                [],
                {"Host": "example.org", "X-Forwarded-Host": PREVIEW_HOST},
                HAND_WRITTEN
            )
        ];
        for (label, proxies, headers, want) in rows {
            server = ServingServer(
                app=gateway.app,
                host="127.0.0.1",
                port=0,
                settings=ServeSettings(proxy=ProxySettings(trusted=proxies))
            );
            stop = server.serve_background();
            try {
                (status, body) = raw_get(server.bound_port, "/robots.txt", headers);
            } finally {
                stop();
            }
            assert status == 200 , f"{label}: {status}";
            assert want.encode() in body , f"{label}: {body!r}";
        }
    }
}

"""The app's own `/robots.txt` route answers the canonical host, and a preview host
gets `Disallow: /` instead."""
def assert_routed_robots(label: str, client: any) {
    canonical = client.get("/robots.txt", headers={"host": "example.org"});
    assert canonical.status_code == 200 , f"{label}: {canonical.status_code}";
    assert "from the app route" in canonical.text , f"{label}: {canonical.text!r}";
    preview = client.get("/robots.txt", headers={"host": PREVIEW_HOST});
    assert preview.text == DISALLOW_ALL_ROBOTS , (
        f"{label}: the app's own route answered a preview host: {preview.text!r}"
    );
}

test "a preview host gets Disallow even from an app that routes /robots.txt itself" {
    import os;
    import from jaclang.scale.runtime.gateway.microservice_gateway {
        MicroserviceGateway
    }
    import from jaclang.scale.runtime.gateway.service_registry {
        ServiceEntry,
        ServiceRegistry,
        ServiceStatus
    }
    import from jaclang.server.serving.server { ServingServer }
    import from jaclang.testing.testing { JacTestClient }
    import from jaclang.testing.testkit { ServingTestClient }
    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp).resolve();
        (project_dir / "jac.toml").write_text(
            f'[project]\nname = "site"\n\n[client.seo]\nsite_url = "{SITE}"\n'
        );
        main_file = project_dir / "main.jac";
        main_file.write_text(
            'import from jaclang.runtime.builtin { restspec }\n'
                + 'import from http { HTTPMethod }\n\n'
                + '@restspec(method=HTTPMethod.GET, path="/robots.txt")\n'
                + 'def:pub robots_route -> str { return "from the app route"; }\n'
        );
        server = JacTestClient.from_file(str(main_file), base_path=str(project_dir));
        try {
            assert_routed_robots("jac run --serve", server);
        } finally {
            server.close();
        }
        # A microservice member runs with JAC_SV_SIBLING set, and the gateway
        # reaches it without the public Host. The gateway's dist has no
        # robots.txt, so a canonical-host request goes on to the app route.
        member = JacTestClient.from_file(str(main_file), base_path=str(project_dir));
        with patch.dict(os.environ, {"JAC_SV_SIBLING": "1"}) {
            member_app = member.server.require_app();
        }
        assert member.get("/openapi.json").status_code == 200;
        backend = ServingServer(app=member_app, host="127.0.0.1", port=0);
        stop = backend.serve_background();
        try {
            registry = ServiceRegistry();
            registry.register(
                ServiceEntry(
                    name="main",
                    file="main.jac",
                    prefix="/main",
                    port=backend.bound_port,
                    url=f"http://127.0.0.1:{backend.bound_port}",
                    status=ServiceStatus.HEALTHY
                )
            );
            dist = project_dir / "dist";
            dist.mkdir();
            gateway = MicroserviceGateway(
                registry=registry, client_dist_dir=str(dist), base_path=str(project_dir)
            );
            gateway.setup();
            assert_routed_robots(
                "a microservice member behind the gateway",
                ServingTestClient(gateway.app)
            );
        } finally {
            stop();
            member.close();
        }
    }
}
