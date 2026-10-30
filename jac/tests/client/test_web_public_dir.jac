"""A web build copies `public/` into `dist/`, so a deployment that serves only `dist/`
answers the same root URLs (`/robots.txt`, `/logo.png`) as `jac run --serve` (#9456)."""

import json;
import subprocess;
import tempfile;
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.client.targets.web_target { WebTarget }
import from jaclang.client.vite_bundler { ViteBundler }
import from jaclang.runtime.runtime { JacRuntime as Jac }

"""Run `WebTarget.build` with the Vite step replaced by one that writes a stub bundle,
and return the dist directory the build wrote to."""
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

"""A single-app project with `main.jac` and the given `public/` files."""
def single_app(project_dir: Path, public: dict[str, str]) -> Path {
    entry_path = project_dir / "main.jac";
    entry_path.write_text('def:pub app -> any { return <div>site</div>; }');
    (project_dir / "jac.toml").write_text(
        '[project]\nname = "site"\nkind = "web-app"\n'
    );
    (project_dir / "package.json").write_text('{"name":"site","version":"0.0.0"}');
    for (rel, text) in public.items() {
        path = project_dir / "public" / rel;
        path.parent.mkdir(parents=True, exist_ok=True);
        path.write_text(text);
    }
    return entry_path;
}

test "a web build copies public/ into dist, keeping subfolders" {
    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp).resolve();
        public = {
            "robots.txt": "User-agent: *\nAllow: /\n",
            "sitemap.xml": "<urlset></urlset>\n",
            "img/logo.svg": "<svg></svg>\n"
        };
        entry_path = single_app(project_dir, public);
        dist = build_web(project_dir, entry_path);
        assert (dist / "index.html").is_file() , "the build no longer writes index.html";
        for (rel, text) in public.items() {
            copied = dist / rel;
            assert copied.is_file() , f"public/{rel} is missing from {dist}";
            assert copied.read_text() == text , f"public/{rel} was not copied verbatim";
        }
    }
}

test "a workspace app's own public/ wins over the project root's, as when serving" {
    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp).resolve();
        app_dir = project_dir / "apps" / "web";
        (app_dir / "public").mkdir(parents=True);
        (project_dir / "public").mkdir();
        entry_path = app_dir / "main.jac";
        entry_path.write_text('def:pub app -> any { return <div>site</div>; }');
        (project_dir / "jac.toml").write_text(
            '[project]\nname = "site"\ndefault-app = "web"\n\n'
                + '[apps.web]\nkind = "web-app"\nentry-point = "apps.web.main"\n'
        );
        (project_dir / "package.json").write_text('{"name":"site","version":"0.0.0"}');
        (app_dir / "public" / "robots.txt").write_text("from the app\n");
        (project_dir / "public" / "robots.txt").write_text("from the root\n");
        (project_dir / "public" / "sitemap.xml").write_text("<urlset></urlset>\n");
        dist = build_web(project_dir, entry_path);
        assert (dist / "robots.txt").read_text() == "from the app\n" , (
            "the project root's public/ overrode the app's own"
        );
        assert (dist / "sitemap.xml").is_file() , (
            "a file only in the project root's public/ was not copied"
        );
    }
}

test "a public/ file that would overwrite a build output fails the build" {
    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp).resolve();
        entry_path = single_app(
            project_dir, {"index.html": "<p>stale</p>", "robots.txt": "User-agent: *\n"}
        );
        try {
            build_web(project_dir, entry_path);
            assert False , "the build accepted a public/index.html that collides with its own";
        } except RuntimeError as err {
            assert "index.html" in str(err) , f"the error does not name the file: {err}";
            assert "public/" in str(err) , f"the error does not say how to fix it: {err}";
        }
        built = list((project_dir / ".jac").rglob("index.html"));
        assert built , "the build did not get as far as writing index.html";
        assert all("stale" not in p.read_text() for p in built) , (
            "public/index.html overwrote the built index.html"
        );
        assert not list((project_dir / ".jac").rglob("robots.txt")) , (
            "a failed build still copied part of public/"
        );
    }
}

test "a public/ folder where the build writes a file fails the build" {
    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp).resolve();
        entry_path = single_app(
            project_dir,
            {"client.test.js/readme.txt": "clash", "robots.txt": "User-agent: *\n"}
        );
        try {
            build_web(project_dir, entry_path);
            assert False , "the build accepted a public/ folder named like its bundle";
        } except RuntimeError as err {
            assert "client.test.js" in str(err) , f"the error does not name the path: {err}";
        }
        assert not list((project_dir / ".jac").rglob("robots.txt")) , (
            "a failed build still copied part of public/"
        );
    }
}

test "a file in one public/ and a folder of the same name in another fails before copying" {
    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp).resolve();
        app_dir = project_dir / "apps" / "web";
        (app_dir / "public").mkdir(parents=True);
        (project_dir / "public" / "docs.txt").mkdir(parents=True);
        entry_path = app_dir / "main.jac";
        entry_path.write_text('def:pub app -> any { return <div>site</div>; }');
        (project_dir / "jac.toml").write_text(
            '[project]\nname = "site"\ndefault-app = "web"\n\n'
                + '[apps.web]\nkind = "web-app"\nentry-point = "apps.web.main"\n'
        );
        (project_dir / "package.json").write_text('{"name":"site","version":"0.0.0"}');
        (app_dir / "public" / "docs.txt").write_text("a file\n");
        (project_dir / "public" / "docs.txt" / "page.txt").write_text("a folder\n");
        (project_dir / "public" / "robots.txt").write_text("User-agent: *\n");
        try {
            build_web(project_dir, entry_path);
            assert False , "the build accepted docs.txt as both a file and a folder";
        } except RuntimeError as err {
            for part in ["apps/web/public/docs.txt", "docs.txt/page.txt"] {
                assert part in str(err) , f"the error does not name {part}: {err}";
            }
        }
        assert not list((project_dir / ".jac").rglob("robots.txt")) , (
            "a failed build still copied part of public/"
        );
    }
}

test "linked folders inside public/ are copied, links that leave it or loop are not" {
    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp).resolve();
        entry_path = single_app(project_dir, {"shared/logo.svg": "<svg></svg>\n"});
        public = project_dir / "public";
        secret = project_dir / "secret";
        secret.mkdir();
        (secret / "key.txt").write_text("not public\n");
        (public / "icons").symlink_to("shared", target_is_directory=True);
        (public / "loop").symlink_to(".", target_is_directory=True);
        (public / "outside").symlink_to("../secret", target_is_directory=True);
        (public / "leak.txt").symlink_to("../secret/key.txt");
        dist = build_web(project_dir, entry_path);
        rows = [
            ("a real folder", "shared/logo.svg", True),
            ("a link to a folder inside public/", "icons/logo.svg", True),
            ("a link to a folder outside public/", "outside/key.txt", False),
            ("a link to a file outside public/", "leak.txt", False),
            ("a link back to public/ itself", "loop/shared/logo.svg", False)
        ];
        for (label, rel, copied) in rows {
            assert (dist / rel).is_file() == copied , (
                f"{label}: {rel} {'missing from' if copied else 'copied into'} dist"
            );
        }
    }
}

test "a PWA build's service worker precaches the files copied from public/" {
    import from jaclang.testing.requires { require_tool }
    require_tool("node");
    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp).resolve();
        entry_path = single_app(
            project_dir, {"logo.png": "png\n", "team's #1?.png": "png\n"}
        );
        with open(project_dir / "jac.toml", "a") as f {
            f.write('\n[client.pwa]\ntheme_color = "#000000"\n');
        }
        dist = build_web(project_dir, entry_path);
        sw_path = dist / "sw.js";
        check = subprocess.run(
            ["node", "--check", str(sw_path)], capture_output=True, text=True
        );
        assert check.returncode == 0 , f"sw.js is not valid JavaScript:\n{check.stderr}";
        sw = sw_path.read_text();
        rows = [
            ("a plain name", "logo.png", "./logo.png"),
            ("a quote, space, # and ?", "team's #1?.png", "./team%27s%20%231%3F.png"),
            ("the built page", "index.html", "./index.html")
        ];
        for (label, name, url) in rows {
            assert (dist / name).is_file() , f"{label}: {name} is missing from dist";
            assert json.dumps(url) in sw , f"{label}: sw.js does not precache {url}";
        }
    }
}
