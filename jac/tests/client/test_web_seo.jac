"""`[client.seo]` makes a web build write `robots.txt` and `sitemap.xml` from the
app's routes, and every server that answers `/robots.txt` tells a host other than
`site_url` to stay out (#9456)."""

import tempfile;
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.client.route_scanner { RouteEntry }
import from jaclang.client.targets.seo_build {
    normalized_site_url,
    render_robots,
    robots_disallows,
    sitemap_paths
}
import from jaclang.client.targets.web_target { WebTarget }
import from jaclang.client.vite_bundler { ViteBundler }
import from jaclang.runtime.runtime { JacRuntime as Jac }
import from jaclang.server.static_files { DISALLOW_ALL_ROBOTS, robots_override }

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
        ("no file routes", [], [], [], ["/"])
    ];
    for (label, scanned, exclude, extra, want) in rows {
        got = sitemap_paths(scanned, exclude, extra);
        assert got == want , f"{label}: {got}";
    }
}

test "robots.txt keeps protected routes out but never the bundle or stylesheet" {
    routes = [
        route("/"),
        route("/dashboard", auth=True),
        route("/users/:id/settings", auth=True)
    ];
    disallows = robots_disallows(routes, ["/internal", "admin"]);
    assert disallows == ["/dashboard", "/users/", "/internal", "/admin"] , disallows;
    text = render_robots(SITE, disallows, ["/client.abc123.js", "/styles.css"]);
    lines = text.splitlines();
    assert lines[0] == "User-agent: *" , text;
    for asset in ["/client.abc123.js", "/styles.css"] {
        assert f"Allow: {asset}" in lines , f"robots.txt may block {asset}:\n{text}";
    }
    assert "Disallow: /dashboard" in lines , text;
    assert f"Sitemap: {SITE}/sitemap.xml" in lines , text;
    open_text = render_robots(SITE, [], ["/client.abc123.js"]);
    assert "Allow: /" in open_text.splitlines() , open_text;
    assert "Disallow" not in open_text , open_text;
}

test "site_url must be an absolute http(s) URL" {
    assert normalized_site_url("https://example.org/") == SITE;
    for bad in ["example.org", "/docs", "ftp://example.org", "https://"] {
        try {
            normalized_site_url(bad);
            assert False , f"accepted site_url {bad!r}";
        } except RuntimeError as err {
            assert "site_url" in str(err) , f"{bad!r}: {err}";
        }
    }
}

test "robots.txt on a host other than site_url disallows everything" {
    rows = [
        ("canonical host", SITE, "example.org", "", None),
        ("canonical host with a port", SITE, "example.org:443", "", None),
        ("host in another case", SITE, "Example.ORG", "", None),
        ("preview host", SITE, PREVIEW_HOST, "", DISALLOW_ALL_ROBOTS),
        ("proxy forwards the canonical host", SITE, "web:8000", "example.org", None),
        (
            "proxy forwards a preview host",
            SITE,
            "web:8000",
            f"{PREVIEW_HOST}, example.org",
            DISALLOW_ALL_ROBOTS
        ),
        ("no site_url", "", PREVIEW_HOST, "", None)
    ];
    for (label, site_url, host, forwarded, want) in rows {
        got = robots_override(site_url, host, forwarded);
        assert got == want , f"{label}: {got!r}";
    }
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
        entry_path = make_project(project_dir, f'site_url = "{SITE}/"', pages, {});
        dist = build_web(project_dir, entry_path);
        sitemap = (dist / "sitemap.xml").read_text();
        for path in ["/", "/about"] {
            assert f"<loc>{SITE}{path}</loc>" in sitemap , f"{path} missing:\n{sitemap}";
        }
        for path in ["/dashboard", "/users"] {
            assert f"{SITE}{path}" not in sitemap , f"{path} listed:\n{sitemap}";
        }
        assert "lastmod" not in sitemap , sitemap;
        robots = (dist / "robots.txt").read_text();
        robots_lines = robots.splitlines();
        assert "Disallow: /dashboard" in robots_lines , robots;
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
    import from jaclang.scale.runtime.gateway.service_registry { ServiceRegistry }
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
                assert "immutable" not in header(canonical, "cache-control") , (
                    f"{label} lets robots.txt be cached as immutable"
                );
                preview = client.get("/robots.txt", headers={"host": PREVIEW_HOST});
                assert preview.status_code == 200 , f"{label}: {preview.status_code}";
                assert preview.text == DISALLOW_ALL_ROBOTS , (
                    f"{label} served the production robots.txt to a preview host"
                );
                sitemap = client.get("/sitemap.xml", headers={"host": "example.org"});
                assert sitemap.status_code == 200 , f"{label}: {sitemap.status_code}";
                assert "xml" in header(sitemap, "content-type") , label;
            }
        } finally {
            server.close();
        }
    }
}
