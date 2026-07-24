import tempfile;
import unittest.mock;
import jaclang.scale.injector.binary as binary_mod;
import from jaclang.scale.injector.binary { _exact_of, _resolve_target_version }
import from jaclang.project.config { JacConfig }
import from pathlib { Path }

glob REPO: str = "jaseci-labs/jac";


def _project(toml: str) -> str {
    d = tempfile.mkdtemp();
    (Path(d) / "jac.toml").write_text(toml, encoding="utf-8");
    return d;
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
    pub = ["0.33.0", "0.34.1", "0.34.2", "0.34.3", "0.35.0"];
    with unittest.mock.patch.object(
        binary_mod, "_list_release_versions", return_value=pub
    ) {
        assert _resolve_target_version(REPO, ">=0.34,<0.35") == "0.34.3";
        assert _resolve_target_version(REPO, "<=0.34.2") == "0.34.2";
        assert _resolve_target_version(REPO, "~=0.34.1") == "0.34.3";
        assert _resolve_target_version(REPO, ">=1.0") == "";
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
    (dist, sha) = binary_mod._admin_dist_urls("stable", "0.34.2");
    assert "releases/download/v0.34.2/jac-0.34.2-admin-dist.tar.gz" in dist;
    assert sha == dist + ".sha256";
}


test "config round-trips the stamped jac-version pin" {
    toml = '[project]\nname = "x"\nversion = "0.1.0"\njac-version = "==0.34.3"\n';
    cfg = JacConfig.from_toml_str(toml);
    assert cfg.project.jac_version == "==0.34.3";
}
