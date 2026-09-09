import os;
import json;
import tempfile;
import unittest.mock;
import jaclang.scale.injector.binary as binary_mod;
import from jaclang.scale.injector.binary { _exact_of, _resolve_target_version }
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


test "exact pins (== or bare) are detected; ranges and junk are not" {
    assert _exact_of("==0.34.3") == "0.34.3";
    assert _exact_of("0.34.3") == "0.34.3";
    assert _exact_of(">=0.34.3") == "";
    assert _exact_of(">=0.34,<0.35") == "";
    assert _exact_of("~=0.34.3") == "";
    assert _exact_of("==0.34.*") == "";
    assert _exact_of("") == "";
    assert _exact_of("not-a-version") == "";
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


test "the admin console uses the same release tag as the pinned binary" {
    meta = _release_meta(
        ["jac-0.34.2-admin-dist.tar.gz", "jac-0.34.2-admin-dist.tar.gz.sha256"]
    );
    with unittest.mock.patch.object(
        binary_mod, "_http_get_bytes", return_value=meta
    ) as fetch {
        (dist, sha) = binary_mod._admin_dist_urls("stable", "0.34.2");
        assert "releases/tags/v0.34.2" in fetch.call_args[0][0];
        assert dist.endswith("jac-0.34.2-admin-dist.tar.gz");
        assert sha == dist + ".sha256";
    }
}


test "a pinned console without a published checksum aborts" {
    meta = _release_meta(["jac-0.34.2-admin-dist.tar.gz"]);
    with unittest.mock.patch.object(binary_mod, "_http_get_bytes", return_value=meta) {
        raised = False;
        try {
            binary_mod._admin_dist_urls("stable", "0.34.2");
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
    meta = _release_meta(["jac-0.30.0-linux-x86_64", "jac-0.30.0-linux-x86_64.sha256"]);
    with unittest.mock.patch.object(binary_mod, "_http_get_bytes", return_value=meta) {
        assert binary_mod.download_admin_dist("stable", "0.30.0") is None;
    }
}


test "a pinned no-console release clears a previously staged console" {
    import from urllib.error { HTTPError }
    d = _project('[project]\nname = "x"\nversion = "0.1.0"\n');
    stale = Path(d) / ".jac" / "admin";
    stale.mkdir(parents=True);
    (stale / "index.html").write_text("stale", encoding="utf-8");
    with unittest.mock.patch.object(
        binary_mod,
        "_http_get_bytes",
        return_value=_release_meta(["jac-0.30.0-linux-x86_64"])
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


test "the preflight refuses a pin that names no published release" {
    # An exact pin short-circuits resolve_deploy_version, so only the release
    # record reveals the typo.
    import from urllib.error { HTTPError }
    d = _project(
        '[project]\nname = "x"\nversion = "0.1.0"\njac-version = "==0.34.99"\n'
    );
    def _absent(url: str) -> bytes {
        raise HTTPError(url, 404, "Not Found", {}, None);
    }
    with unittest.mock.patch.object(binary_mod, "_http_get_bytes", _absent) {
        raised = False;
        try {
            binary_mod.preflight_pod_runtime(d, "stable", "x86_64");
        } except RuntimeError {
            raised = True;
        }
        assert raised;
    }
}


test "the preflight needs the pod binary and the host sealing binary" {
    # Since jac#7989 a deploy may also fetch a host-platform build of the same
    # version to seal the .jab, so a release missing either one cannot deploy.
    # The pod arch is chosen to DIFFER from the host arch: on a linux host
    # whose arch matches the pod's, the two required asset names collapse into
    # one and neither "missing" leg can trip.
    d = _project(
        '[project]\nname = "x"\nversion = "0.1.0"\njac-version = "==0.34.3"\n'
    );
    pod_arch = "aarch64" if binary_mod.host_arch() == "x86_64" else "x86_64";
    pod = f"jac-0.34.3-linux-{pod_arch}";
    host = f"jac-0.34.3-{binary_mod.host_seal_platform()}-{binary_mod.host_arch()}";
    assert pod != host;
    for names in [[pod], [host]] {
        with unittest.mock.patch.object(
            binary_mod, "_http_get_bytes", return_value=_release_meta(names)
        ) {
            raised = False;
            try {
                binary_mod.preflight_pod_runtime(d, "stable", pod_arch);
            } except RuntimeError {
                raised = True;
            }
            assert raised;
        }
    }
    with unittest.mock.patch.object(
        binary_mod, "_http_get_bytes", return_value=_release_meta([pod, host])
    ) {
        assert binary_mod.preflight_pod_runtime(d, "stable", pod_arch) == "0.34.3";
    }
}


def _pin_offset(delta: int) -> str {
    (major, minor, _) = binary_mod._ver_key(resolve_cli_version().strip());
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
