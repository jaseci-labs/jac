import os;
import json;
import tempfile;
import unittest.mock;
import jaclang.scale.injector.binary as binary_mod;
import from jaclang.scale.injector.binary { _resolve_target_version }
import from jaclang.project.jac_version { exact_pin, version_key }
import from jaclang.cli.manifest_route { resolve_cli_version }
import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.target { KubernetesTarget }
import inspect;
import io;
import from contextlib { redirect_stderr }
import from jaclang.scale.runtime.realizer.kubernetes_realizer {
    DELEGATED_ENV,
    KubernetesRealizer,
    pinned_deploy_argv
}
import from jaclang.project.config { JacConfig }
import from pathlib { Path }
import from urllib.error { HTTPError, URLError }
import from email.message { Message }

glob REPO: str = "jaseci-labs/jac";


def _project(toml: str) -> str {
    d = tempfile.mkdtemp();
    (Path(d) / "jac.toml").write_text(toml, encoding="utf-8");
    return d;
}


def _release_meta(names: list[str]) -> bytes {
    assets = [
        {"name": n, "browser_download_url": f"https://dl.test/{n}"} for n in names
    ];
    return json.dumps({"assets": assets}).encode("utf-8");
}


def _github(
    calls: list[dict[str, any]],
    names: list[str],
    missing: list[str],
    broken: dict[str, any] | None = None
) -> any {
    # Stands in for urlopen at the network edge, so the code under test picks
    # the URLs, the methods and the headers itself. Anything whose URL contains
    # an entry of `missing` is a 404.
    def fake(req: any, timeout: any = None) -> any {
        url = req if isinstance(req, str) else req.full_url;
        method = "GET" if isinstance(req, str) else req.get_method();
        calls.append({"url": url, "method": method, "req": req});
        for m in missing {
            if m in url {
                raise HTTPError(url, 404, "Not Found", {}, None);
            }
        }
        for (m, exc) in (broken or {}).items() {
            if m in url {
                raise exc;
            }
        }
        if "api.github.com" in url and "releases?per_page" in url {
            body = json.dumps(
                [{"tag_name": "v0.34.3", "assets": [{"name": n} for n in names]}]
            ).encode(
                "utf-8"
            );
        } elif "api.github.com" in url {
            body = _release_meta(names);
        } else {
            body = ("ab" * 32 + "  jac\n").encode("utf-8");
        }
        resp = unittest.mock.MagicMock();
        resp.read.return_value = body;
        resp.status = 200;
        resp.getcode.return_value = 200;
        return resp;
    }
    return fake;
}


def _github_calls(calls: list[dict[str, any]]) -> list[str] {
    return [
        str(c["url"])
        for c in calls
        if "api.github.com" in str(c["url"])
    ];
}


def _set_tokens(env: dict[str, str]) {
    os.environ.pop("GH_TOKEN", None);
    os.environ.pop("GITHUB_TOKEN", None);
    for (k, v) in env.items() {
        os.environ[k] = v;
    }
}


def _pod_and_host(version: str) -> tuple[str, str, str] {
    pod_arch = "aarch64" if binary_mod.host_arch() == "x86_64" else "x86_64";
    pod = f"jac-{version}-linux-{pod_arch}";
    host = f"jac-{version}-{binary_mod.host_seal_platform()}-{binary_mod.host_arch()}";
    assert pod != host;
    return (pod_arch, pod, host);
}


test "exact pins (== or bare) are detected; ranges and junk are not" {
    assert exact_pin("==0.34.3") == "0.34.3";
    assert exact_pin("0.34.3") == "0.34.3";
    assert exact_pin(">=0.34.3") == "";
    assert exact_pin(">=0.34,<0.35") == "";
    assert exact_pin("~=0.34.3") == "";
    assert exact_pin("==0.34.*") == "";
    assert exact_pin("") == "";
    assert exact_pin("not-a-version") == "";
}


test "an exact pin resolves without listing releases" {
    with unittest.mock.patch.object(
        binary_mod,
        "_list_release_versions",
        side_effect=AssertionError("should not list releases for an exact pin")
    ) {
        assert _resolve_target_version(REPO, "==0.34.3") == "0.34.3";
        assert _resolve_target_version(REPO, "0.34.3") == "0.34.3";
    }
    assert _resolve_target_version(REPO, "") == "";
}


test "a range picks the newest published release that satisfies it" {
    `pub = ["0.33.0", "0.34.1", "0.34.2", "0.34.3", "0.35.0"];
    with unittest.mock.patch.object(
        binary_mod, "_list_release_versions", return_value=`pub
    ) {
        assert _resolve_target_version(REPO, ">=0.34,<0.35") == "0.34.3";
        assert _resolve_target_version(REPO, "<=0.34.2") == "0.34.2";
        assert _resolve_target_version(REPO, "~=0.34.1") == "0.34.3";
        assert _resolve_target_version(REPO, ">=1.0") == "";
    }
}


test "only a release whose tag names its own binary is a candidate" {
    # jac#8960: the retired jaseci meta-package tags are numerically larger
    # than every jac tag, so an open-ended range resolved to 2.3.28 and the
    # deploy aborted on a release shipping no jac-2.3.28 binary. v2.3.27 is the
    # trap: it ships a real jac binary, but of a version its tag does not name.
    releases = json.dumps(
        [
            {"tag_name": "v0.37.3", "assets": [{"name": "jac-0.37.3-linux-x86_64"}]},
            {"tag_name": "v2.3.28", "assets": [{"name": "jaseci-2.3.28.tar.gz"}]},
            {"tag_name": "v2.3.27", "assets": [{"name": "jac-0.16.6-linux-x86_64"}]},
            {"tag_name": "v0.38.0", "draft": True, "assets": []}
        ]
    ).encode(
        "utf-8"
    );
    with unittest.mock.patch.object(
        binary_mod, "_http_get_bytes", return_value=releases
    ) {
        assert binary_mod._list_release_versions(REPO) == ["0.37.3"];
        assert _resolve_target_version(REPO, ">=0.37.3") == "0.37.3";
        assert _resolve_target_version(REPO, ">=0.34") == "0.37.3";
    }
}


test "a malformed spec resolves to '' (no target)" {
    with unittest.mock.patch.object(
        binary_mod, "_list_release_versions", return_value=["0.34.3"]
    ) {
        assert _resolve_target_version(REPO, ">=>=bad") == "";
    }
}


test "no pin, or a non-stable channel, resolves to latest" {
    d = _project('[project]\nname = "x"\nversion = "0.1.0"\n');
    assert binary_mod.resolve_deploy_version(d, "stable") == "";
    # dev/local/experimental ship their own binary and ignore the pin.
    p = _project(
        '[project]\nname = "x"\nversion = "0.1.0"\njac-version = "==0.34.2"\n'
    );
    assert binary_mod.resolve_deploy_version(p, "dev") == "";
}


test "a declared pin matching no release aborts the deploy" {
    d = _project('[project]\nname = "x"\nversion = "0.1.0"\njac-version = ">=99.0"\n');
    with unittest.mock.patch.object(
        binary_mod, "_list_release_versions", return_value=["0.34.3"]
    ) {
        raised = False;
        try {
            binary_mod.resolve_deploy_version(d, "stable");
        } except RuntimeError {
            raised = True;
        }
        assert raised;
    }
}


test "resolve_deploy_version lists releases once per deploy" {
    d = _project(
        '[project]\nname = "x"\nversion = "0.1.0"\njac-version = ">=0.34,<0.35"\n'
    );
    with unittest.mock.patch.object(
        binary_mod, "_list_release_versions", return_value=["0.34.2"]
    ) as listing {
        assert binary_mod.resolve_deploy_version(d, "stable") == "0.34.2";
        # Every later consumer (console, base image) reuses the memo, so a
        # release publishing mid-deploy cannot split them across release sets.
        assert binary_mod.resolve_deploy_version(d, "stable") == "0.34.2";
        assert listing.call_count == 1;
    }
}


test "an edited pin re-resolves instead of serving a stale memo" {
    d = _project(
        '[project]\nname = "x"\nversion = "0.1.0"\njac-version = ">=0.34,<0.35"\n'
    );
    with unittest.mock.patch.object(
        binary_mod, "_list_release_versions", return_value=["0.34.2"]
    ) {
        assert binary_mod.resolve_deploy_version(d, "stable") == "0.34.2";
    }
    # Editing the pin changes the jac.toml content, so a redeploy in the same
    # process must not serve the stale 0.34.2 from the memo.
    (Path(d) / "jac.toml").write_text(
        '[project]\nname = "x"\nversion = "0.1.0"\njac-version = ">=0.35,<0.36"\n',
        encoding="utf-8"
    );
    with unittest.mock.patch.object(
        binary_mod, "_list_release_versions", return_value=["0.35.1"]
    ) {
        assert binary_mod.resolve_deploy_version(d, "stable") == "0.35.1";
    }
}


test "the pin is discovered from an ancestor jac.toml (nested entry)" {
    proj = _project(
        '[project]\nname = "x"\nversion = "0.1.0"\njac-version = "==0.34.2"\n'
    );
    sub = Path(proj) / "apps" / "web";
    sub.mkdir(parents=True);
    # A deploy whose code_folder is the nested entry dir still finds the project
    # pin instead of silently deploying latest.
    assert binary_mod.resolve_deploy_version(str(sub), "stable") == "0.34.2";
}


test "a deploy boundary re-resolves a range after a new release publishes" {
    d = _project(
        '[project]\nname = "x"\nversion = "0.1.0"\njac-version = ">=0.34,<0.36"\n'
    );
    with unittest.mock.patch.object(
        binary_mod, "_list_release_versions", return_value=["0.34.2"]
    ) {
        assert binary_mod.resolve_deploy_version(d, "stable") == "0.34.2";
    }
    # A newer matching release publishes. The memo holds the old result within
    # the deploy, but the next deploy's reset picks up the new one.
    with unittest.mock.patch.object(
        binary_mod, "_list_release_versions", return_value=["0.34.2", "0.35.9"]
    ) {
        assert binary_mod.resolve_deploy_version(d, "stable") == "0.34.2";
        binary_mod.reset_deploy_version_cache();
        assert binary_mod.resolve_deploy_version(d, "stable") == "0.35.9";
    }
}


test "the base image uses the same resolver as the pinned binary" {
    d = _project(
        '[project]\nname = "x"\nversion = "0.1.0"\njac-version = ">=0.34,<0.35"\n'
    );
    with unittest.mock.patch.object(
        binary_mod, "resolve_deploy_version", return_value="0.34.2"
    ) {
        with unittest.mock.patch.object(
            binary_mod, "_http_get_bytes", return_value=b"{}"
        ) {
            assert binary_mod.resolve_pod_base_image(d, "") == "jaseci/jaclang:0.34.2";
        }
    }
    # An unresolvable pin aborts the image resolution too -- no silent `latest`.
    with unittest.mock.patch.object(
        binary_mod, "resolve_deploy_version", side_effect=RuntimeError("no match")
    ) {
        raised = False;
        try {
            binary_mod.resolve_pod_base_image(d, "");
        } except RuntimeError {
            raised = True;
        }
        assert raised;
    }
}


test "a pinned console failure aborts; unpinned stays soft" {
    d = _project('[project]\nname = "x"\nversion = "0.1.0"\n');
    with unittest.mock.patch.object(
        binary_mod, "download_admin_dist", side_effect=RuntimeError("checksum mismatch")
    ) {
        raised = False;
        try {
            binary_mod.stage_admin_dist(d, "stable", "0.34.2");
        } except RuntimeError {
            raised = True;
        }
        assert raised;
        # Unpinned keeps the warn-and-continue behavior.
        assert binary_mod.stage_admin_dist(d, "stable") == False;
    }
}


test "a pinned release with no console asset is skipped, not fatal" {
    calls: list[dict[str, any]] = [];
    with unittest.mock.patch.object(
        binary_mod, "urlopen", _github(calls, [], ["jac-0.30.0-admin-dist.tar.gz"])
    ) {
        assert binary_mod.download_admin_dist("stable", "0.30.0") is None;
    }
}


test "a pinned no-console release clears a previously staged console" {
    import from urllib.error { HTTPError }
    d = _project('[project]\nname = "x"\nversion = "0.1.0"\n');
    stale = Path(d) / ".jac" / "admin";
    stale.mkdir(parents=True);
    (stale / "index.html").write_text("stale", encoding="utf-8");
    calls: list[dict[str, any]] = [];
    with unittest.mock.patch.object(
        binary_mod, "urlopen", _github(calls, [], ["jac-0.30.0-admin-dist.tar.gz"])
    ) {
        # Pinned: the stale console from an earlier deploy must not ship.
        assert binary_mod.stage_admin_dist(d, "stable", "0.30.0") == False;
        assert not stale.exists();
    }
    with unittest.mock.patch.object(
        binary_mod,
        "_http_get_bytes",
        side_effect=HTTPError("url", 404, "Not Found", None, None)
    ) {
        # Unpinned keeps whatever was staged before.
        (stale).mkdir(parents=True);
        (stale / "index.html").write_text("stale", encoding="utf-8");
        assert binary_mod.stage_admin_dist(d, "stable") == False;
        assert stale.exists();
    }
}


test "config round-trips the stamped jac-version pin" {
    toml = '[project]\nname = "x"\nversion = "0.1.0"\njac-version = "==0.34.3"\n';
    cfg = JacConfig.from_toml_str(toml);
    assert cfg.project.jac_version == "==0.34.3";
}


def _pin_offset(delta: int) -> str {
    (major, minor, _) = version_key(resolve_cli_version().strip());
    return _project(
        f'[project]\nname = "x"\njac-version = "=={major}.{minor + delta}.0"\n'
    );
}


test "a deploy is refused when the pin is a minor line off the deployer" {
    # The pin picks the pod image and the seal; the deploying jac renders the
    # manifests and provisions the database. #8766: nothing compared the two,
    # so a 0.34 deployer stood up Mongo for an app pinned to a Postgres
    # runtime and said so to nobody. Patch drift is fine, a minor line is not.
    running = resolve_cli_version().strip();
    assert binary_mod.deploy_generation_refusal(_pin_offset(0), "stable") == "" , (
        "an app on the deployer's own minor line must always deploy"
    );

    refusal = binary_mod.deploy_generation_refusal(_pin_offset(1), "stable");
    assert running in refusal , f"{refusal!a} must name the deployer";
    assert "mongo" not in refusal.lower() and "postgres" not in refusal.lower() , (
        f"{refusal!a} names a backend; a deployer only knows its own generation"
    );
    # Both directions: a newer deployer cannot serve an older pin either.
    assert binary_mod.deploy_generation_refusal(_pin_offset(-1), "stable") != "";

    # No pin, and a channel that ships its own binary, are unconstrained.
    assert binary_mod.deploy_generation_refusal(
        _project('[project]\nname = "x"\n'), "stable"
    )
        == "";
    assert binary_mod.deploy_generation_refusal(_pin_offset(1), "dev") == "";

    # A pin naming no published release is the preflight's error to raise,
    # with the message that lists what does exist.
    unmatched = _project('[project]\nname = "x"\njac-version = ">=99.0"\n');
    with unittest.mock.patch.object(
        binary_mod, "_list_release_versions", return_value=["0.34.3"]
    ) {
        assert binary_mod.deploy_generation_refusal(unmatched, "stable") == "";
    }
}


test "a cross-generation deploy is refused before the cluster is contacted" {
    # The refusal has to land before _load_cluster_config, so it reaches an
    # operator with no kubeconfig and costs nothing to discover.
    cfg = KubernetesConfig.from_dict(
        KubernetesConfig, {"app_name": "x", "namespace": "default"}
    );
    result = KubernetesTarget(config=cfg).deploy(
        AppConfig(code_folder=_pin_offset(1), file_name="main.jac")
    );
    assert result.success is False , "a cross-generation deploy must not proceed";
    assert resolve_cli_version().strip() in result.message;
}


test "the pinned jac is handed the same deploy, and cannot delegate again" {
    # A dropped flag silently changes what the child does, and a child that
    # delegates again forks forever, so both are pinned here.
    assert pinned_deploy_argv("/jac", "app.jac", "kubernetes")
        == ["/jac", "scale", "deploy", "app.jac", "--target", "kubernetes"];
    assert pinned_deploy_argv("/jac", "a.jac", "aws", True)[-1] == "--enable-tls";

    app = _project('[project]\nname = "x"\njac-version = "==0.1.0"\n') + "/main.jac";
    r = KubernetesRealizer();
    prior = os.environ.get(DELEGATED_ENV);
    os.environ[DELEGATED_ENV] = "1";
    try {
        with unittest.mock.patch.object(binary_mod, "_http_get_bytes") as mock_http {
            assert r._deploy_on_pinned_jac(app, "kubernetes", False, False) is None;
            mock_http.assert_not_called();
        }
    } finally {
        if prior is None {
            os.environ.pop(DELEGATED_ENV, None);
        } else {
            os.environ[DELEGATED_ENV] = prior;
        }
    }
}


test "delegating runs the pinned binary with this deploy, and forwards its result" {
    # The handoff itself: the child really is executed, with the deploy it was
    # asked for, an env that cannot send it back through the parent's dev
    # source, and its exit code returned unchanged.
    d = tempfile.mkdtemp();
    stub = Path(d) / "jac";
    stub.write_text(
        "#!/bin/sh\n" f'printf "%s\\n" "$@" > {d}/argv\n' f"env > {d}/env\n" "exit 7\n"
    );
    stub.chmod(0o755);
    os.environ["JAC_DEV_SOURCE"] = d;
    err = io.StringIO();
    with unittest.mock.patch.object(
        binary_mod, "host_toolchain_path", return_value=str(stub)
    ), redirect_stderr(err) {
        rc = KubernetesRealizer()._deploy_on_pinned_jac(
            f"{d}/main.jac", "kubernetes", False, False
        );
    }
    os.environ.pop("JAC_DEV_SOURCE", None);

    assert rc == 7 , f"the child exited 7; the deploy reported {rc}";
    # A child that fails quietly would otherwise leave a bare non-zero exit.
    assert "7" in err.getvalue() , (
        f"a failed delegated deploy said nothing: {err.getvalue()!a}"
    );
    argv = (Path(d) / "argv").read_text().split();
    assert argv
        == ["scale", "deploy", f"{d}/main.jac", "--target", "kubernetes"] , argv;
    env = (Path(d) / "env").read_text();
    assert f"{DELEGATED_ENV}=1" in env , "the child can delegate again and fork forever";
    assert "JAC_DEV_SOURCE" not in env , (
        "the child inherited the parent's dev source and would run its code, "
        "not the release it was fetched for"
    );
}


test "the child is handed every deploy parameter that can reach it" {
    # A reconstructed command line that silently drops a flag is a class of
    # bug, not one bug, so the omissions are asserted rather than assumed.
    # dry_run never delegates, and show_yaml is read only inside that branch,
    # so neither can change a delegated deploy. Anything else added to
    # realize() has to be forwarded, and this fails until it is.
    accepted = set(inspect.signature(KubernetesRealizer.realize).parameters)
        - {"self", "filename"};
    forwarded = set(inspect.signature(pinned_deploy_argv).parameters)
        - {"jac_bin", "filename"};
    assert accepted - forwarded == {"dry_run", "show_yaml"} , (
        f"realize() takes {sorted(accepted)} but the child is handed "
        f"{sorted(forwarded)}; forward the new one or justify dropping it"
    );
}


test "a jac.toml it cannot read refuses the deploy instead of allowing it" {
    # Returning "" means "no refusal", so a blanket except would let the exact
    # cross-generation deploy this exists to stop proceed on a config nobody
    # could parse. Only an unresolvable pin is swallowed, because the preflight
    # reports that one with the releases that do exist.
    broken = _project('[project\nname = "x"\n');
    raised = False;
    try {
        binary_mod.deploy_generation_refusal(broken, "stable");
    } except Exception {
        raised = True;
    }
    assert raised , (
        "an unreadable jac.toml was treated as no pin, so the deploy runs "
        "without either generation ever being compared"
    );
}


test "the GitHub token rides only on api.github.com requests" {
    api = "https://api.github.com/repos/jaseci-labs/jac/releases/latest";
    rows = [
        ({"GH_TOKEN": "gh-tok"}, api, "Bearer gh-tok"),
        ({"GITHUB_TOKEN": "gha-tok"}, api, "Bearer gha-tok"),
        ({"GH_TOKEN": "gh-tok", "GITHUB_TOKEN": "gha-tok"}, api, "Bearer gh-tok"),
        ({}, api, None),
        (
            {"GH_TOKEN": "gh-tok"},
            "https://github.com/jaseci-labs/jac/releases/download/v0.34.3/jac-0.34.3-linux-x86_64.sha256",
            None
        ),
        (
            {"GH_TOKEN": "gh-tok"},
            "https://hub.docker.com/v2/repositories/jaseci/jaclang/tags/0.34.3",
            None
        ),
        ({"GH_TOKEN": "gh-tok"}, "https://api.github.com.evil.test/steal", None)
    ];
    for (env, url, expected) in rows {
        calls: list[dict[str, any]] = [];
        with unittest.mock.patch.dict(os.environ, {}) {
            _set_tokens(env);
            with unittest.mock.patch.object(
                binary_mod, "urlopen", _github(calls, [], [])
            ) {
                binary_mod._http_get_bytes(url);
            }
        }
        req = calls[0]["req"];
        sent = None if isinstance(req, str) else req.get_header("Authorization");
        assert sent == expected , f"{url}: sent {sent!a}, expected {expected!a}";
        if expected {
            # A redirect must not carry the token to whatever host it names.
            assert "Authorization" in req.unredirected_hdrs;
            assert "Authorization" not in req.headers;
        }
    }
}


test "a known jac version never goes back to the Releases API for its assets" {
    # exact pin: the version is known, so no api.github.com request at all.
    # range: one listing to learn the version, then direct downloads.
    # unpinned: nothing is known, so latest still comes from the API.
    (pod_arch, pod, host) = _pod_and_host("0.34.3");
    rows = [
        ("==0.34.3", [], True),
        (">=0.34,<0.35", ["releases?per_page"], True),
        ("", ["releases/latest"], False)
    ];
    for (spec, allowed_api, direct) in rows {
        pin = f'jac-version = "{spec}"\n' if spec else "";
        d = _project(f'[project]\nname = "x"\nversion = "0.1.0"\n{pin}');
        calls: list[dict[str, any]] = [];
        with unittest.mock.patch.object(
            binary_mod, "urlopen", _github(calls, [pod, host], [])
        ) {
            with unittest.mock.patch.object(
                binary_mod, "_fetch_verified_asset", return_value=b"jac"
            ) as fetched {
                version = binary_mod.preflight_pod_runtime(d, "stable", pod_arch);
                binary_mod.download_release_binary("stable", pod_arch, version);
            }
        }
        for api in _github_calls(calls) {
            assert any(a in api for a in allowed_api) , (
                f"{spec!a}: unexpected GitHub API request {api}"
            );
        }
        if direct {
            assert version == "0.34.3";
            asset = f"https://github.com/{REPO}/releases/download/v0.34.3/{pod}";
            (url, checksum_url) = fetched.call_args[0][:2];
            assert url == asset , f"{spec!a}: downloaded {url}";
            assert checksum_url == asset + ".sha256" , (
                f"{spec!a}: the download must still be checksum-verified"
            );
        }
    }
}


test "an exhausted GitHub API quota says so, and only that 403 does" {
    rows = [("0", True), ("17", False), (None, False)];
    for (remaining, is_quota) in rows {
        headers = Message();
        if remaining is not None {
            headers["X-RateLimit-Remaining"] = remaining;
        }
        def forbidden(req: any, timeout: any = None) -> any {
            url = req if isinstance(req, str) else req.full_url;
            raise HTTPError(url, 403, "rate limit exceeded", headers, None);
        }
        err = None;
        with unittest.mock.patch.object(binary_mod, "urlopen", forbidden) {
            try {
                binary_mod.stable_release_meta();
            } except Exception as e {
                err = e;
            }
        }
        assert err is not None;
        if is_quota {
            text = str(err);
            assert "rate limit" in text.lower() , f"{text!a}";
            assert "GH_TOKEN" in text and "jac-version" in text , f"{text!a}";
        } else {
            assert isinstance(err, HTTPError) and err.code == 403 , (
                f"remaining={remaining!a}: a plain 403 must not be reported as quota"
            );
        }
    }
}


test "the preflight proves both pod and sealing assets exist without the API" {
    (pod_arch, pod, host) = _pod_and_host("0.34.3");
    d = _project(
        '[project]\nname = "x"\nversion = "0.1.0"\njac-version = "==0.34.3"\n'
    );
    down = HTTPError("u", 503, "Service Unavailable", {}, None);
    rows = [
        ([], {}, True),
        ([pod], {}, False),
        ([host], {}, False),
        ([pod + ".sha256"], {}, False),
        ([host + ".sha256"], {}, False),
        (["/releases/download/v0.34.3/"], {}, False),
        ([], {"/releases/download/": down}, False),
        ([], {"/releases/download/": URLError("timed out")}, False)
    ];
    for (missing, broken, ok) in rows {
        calls: list[dict[str, any]] = [];
        err = None;
        version = "";
        with unittest.mock.patch.object(
            binary_mod, "urlopen", _github(calls, [], missing, broken)
        ) {
            try {
                version = binary_mod.preflight_pod_runtime(d, "stable", pod_arch);
            } except RuntimeError as e {
                err = e;
            }
        }
        assert _github_calls(calls) == [] , f"{missing!a}: asked the Releases API";
        assert {c["method"] for c in calls} <= {"HEAD"} , f"{missing!a}";
        if ok {
            assert err is None and version == "0.34.3";
            assert len(calls) >= 4 , "the pod and sealing assets must both be probed";
        } else {
            assert err is not None , f"{missing!a} must stop the deploy";
            text = str(err);
            assert "404" not in text , f"{err!a}";
            if broken {
                assert "https://github.com/" in text and "retry" in text , f"{err!a}";
            } else {
                assert pod in text or host in text , f"{err!a} must name the asset";
            }
        }
    }
}


test "a pinned admin console is found by direct URL and stays checksum-gated" {
    dist = "jac-0.34.2-admin-dist.tar.gz";
    base = f"https://github.com/{REPO}/releases/download/v0.34.2/{dist}";
    rows = [
        ([], (base, base + ".sha256"), False),
        ([dist], ("", ""), False),
        ([dist + ".sha256"], None, True),
        ([dist, "/releases/tag/v0.34.2"], None, True)
    ];
    for (missing, expected, refused) in rows {
        calls: list[dict[str, any]] = [];
        got = None;
        raised = False;
        with unittest.mock.patch.object(
            binary_mod, "urlopen", _github(calls, [], missing)
        ) {
            try {
                got = binary_mod._admin_dist_urls("stable", "0.34.2");
            } except RuntimeError {
                raised = True;
            }
        }
        assert _github_calls(calls) == [] , f"{missing!a}: asked the Releases API";
        assert raised == refused , f"{missing!a}";
        if not refused {
            assert got == expected , f"{missing!a}: {got!a}";
        }
    }
}


test "a failed release listing is reported as such, not as a pin matching nothing" {
    api = "https://api.github.com/repos/jaseci-labs/jac/releases?per_page=100";
    quota = Message();
    quota["X-RateLimit-Remaining"] = "0";
    rows = [
        (
            {"releases?per_page": HTTPError(api, 403, "rate limit", quota, None)},
            [],
            "GH_TOKEN"
        ),
        ({"releases?per_page": HTTPError(api, 503, "down", {}, None)}, [], "retry"),
        ({"releases?per_page": URLError("timed out")}, [], "retry"),
        ({}, [], "matches no published")
    ];
    for (broken, names, fragment) in rows {
        d = _project(
            '[project]\nname = "x"\nversion = "0.1.0"\njac-version = ">=0.34,<0.35"\n'
        );
        err = None;
        with unittest.mock.patch.object(
            binary_mod, "urlopen", _github([], names, [], broken)
        ) {
            try {
                binary_mod.resolve_deploy_version(d, "stable");
            } except Exception as e {
                err = e;
            }
        }
        assert isinstance(err, RuntimeError) , f"{fragment!a}: {err!a}";
        assert fragment in str(err) , f"{fragment!a} missing from {str(err)!a}";
        if fragment != "matches no published" {
            assert "matches no published" not in str(err) , f"{str(err)!a}";
        }
    }
}


test "a rejected GitHub token is retried once without it, and says so" {
    api = "https://api.github.com/repos/jaseci-labs/jac/releases/latest";
    rows = [
        ({"GH_TOKEN": "stale"}, api, True, True, 2, True),
        ({"GH_TOKEN": "stale"}, api, False, False, 2, True),
        ({}, api, False, False, 1, False),
        (
            {"GH_TOKEN": "stale"},
            "https://github.com/jaseci-labs/jac",
            False,
            False,
            1,
            False
        )
    ];
    for (env, url, anon_ok, succeeds, attempts, warns) in rows {
        calls: list[any] = [];
        def fake(req: any, timeout: any = None) -> any {
            calls.append(req);
            if req.has_header("Authorization") or not anon_ok {
                raise HTTPError(req.full_url, 401, "Bad credentials", {}, None);
            }
            resp = unittest.mock.MagicMock();
            resp.read.return_value = b"{}";
            return resp;
        }
        err = None;
        with unittest.mock.patch.dict(os.environ, {}) {
            _set_tokens(env);
            with unittest.mock.patch.object(binary_mod, "urlopen", fake) {
                with unittest.mock.patch.object(
                    binary_mod.logger, "warning"
                ) as warned {
                    try {
                        binary_mod._http_get_bytes(url);
                    } except HTTPError as e {
                        err = e;
                    }
                }
            }
        }
        label = f"{env!a} {url} anon_ok={anon_ok}";
        assert (err is None) == succeeds , f"{label}: {err!a}";
        assert len(calls) == attempts , f"{label}: {len(calls)} requests";
        if attempts == 2 {
            assert not calls[1].has_header("Authorization") , f"{label}";
        }
        assert warned.called == warns , f"{label}";
        if warns {
            assert "GH_TOKEN" in str(warned.call_args[0][0]) , f"{label}";
        }
    }
}
