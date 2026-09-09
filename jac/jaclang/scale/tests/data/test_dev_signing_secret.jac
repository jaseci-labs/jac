"""Regression tests for issue 11b: the dev token signing secret must persist.

A dev server that signs with a value it does not keep logs every browser
session out on restart, and the shipped placeholder secret is the same string
in every project, so anyone can mint a token for anyone's dev server. The
secret is generated once per project under .jac/data/ (which is gitignored),
and a deployment that configures its own secret keeps using it.
"""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.server.settings { ServeConfigError, ServeSettings }
import from jaclang.server.serving.authcrypt {
    PLACEHOLDER_JWT_SECRET,
    jwt_decode,
    jwt_encode,
    project_data_dir,
    project_signing_secret
}

glob CLUSTER_ENV: str = "KUBERNETES_SERVICE_HOST",
     DATA_PATH_ENV: str = "JAC_DATA_PATH";


"""Apply `values` over the environment, returning what was there before."""
def _set_env(values: dict[str, str | None]) -> dict[str, str | None] {
    previous: dict[str, str | None] = {};
    for (key, value) in values.items() {
        previous[key] = os.environ.get(key);
        if value is None {
            os.environ.pop(key, None);
        } else {
            os.environ[key] = value;
        }
    }
    return previous;
}


test "the dev signing secret is generated once and survives a restart" {
    with TemporaryDirectory() as tmpdir {
        previous = _set_env({CLUSTER_ENV: None, DATA_PATH_ENV: None});
        try {
            first = project_signing_secret(tmpdir);
            secret_path = Path(tmpdir) / ".jac" / "data" / "jwt_secret";
            assert secret_path.exists();
            assert (secret_path.stat().st_mode & 0o777) == 0o600;
            assert len(first) >= 32;
            assert first != PLACEHOLDER_JWT_SECRET;

            # A second call is what the next `jac run` does: read, do not mint.
            assert project_signing_secret(tmpdir) == first;
        } finally {
            _set_env(previous);
        }
    }
}


test "a token minted before a restart still validates after one" {
    with TemporaryDirectory() as tmpdir {
        previous = _set_env({CLUSTER_ENV: None, DATA_PATH_ENV: None});
        try {
            token = jwt_encode({"sub": "alice"}, project_signing_secret(tmpdir));
            claims = jwt_decode(token, project_signing_secret(tmpdir));
            assert claims["sub"] == "alice";
        } finally {
            _set_env(previous);
        }
    }
}


test "two projects never share a dev signing secret" {
    with TemporaryDirectory() as one {
        with TemporaryDirectory() as two {
            previous = _set_env({CLUSTER_ENV: None, DATA_PATH_ENV: None});
            try {
                assert project_signing_secret(one) != project_signing_secret(two);
            } finally {
                _set_env(previous);
            }
        }
    }
}


test "JAC_DATA_PATH moves the secret the way it moves the core store" {
    with TemporaryDirectory() as project {
        with TemporaryDirectory() as elsewhere {
            previous = _set_env({CLUSTER_ENV: None, DATA_PATH_ENV: elsewhere});
            try {
                assert project_data_dir(project)
                    == os.path.join(elsewhere, ".jac", "data");
                secret = project_signing_secret(project);
                assert (Path(elsewhere) / ".jac" / "data" / "jwt_secret").exists();
                assert not (Path(project) / ".jac").exists();
                assert project_signing_secret(project) == secret;
            } finally {
                _set_env(previous);
            }
        }
    }
}


test "an unwritable project fails closed instead of signing per process" {
    with TemporaryDirectory() as tmpdir {
        blocked = os.path.join(tmpdir, "blocked");
        # A regular file where the .jac directory has to go, so makedirs fails.
        Path(tmpdir, "wall").write_text("", encoding="utf-8");
        previous = _set_env(
            {CLUSTER_ENV: None, DATA_PATH_ENV: os.path.join(tmpdir, "wall")}
        );
        try {
            with testraises(RuntimeError) as exc {
                project_signing_secret(blocked);
            }
            message = str(exc.value);
            assert "[serve.auth] secret" in message;
            assert "keep to" in message;
        } finally {
            _set_env(previous);
        }
    }
}


test "an unconfigured project no longer signs with the shipped placeholder" {
    with TemporaryDirectory() as tmpdir {
        previous = _set_env({CLUSTER_ENV: None, DATA_PATH_ENV: None});
        try {
            secret = ServeSettings.load(tmpdir).auth.resolve_secret(tmpdir);
            assert secret != PLACEHOLDER_JWT_SECRET;
            assert secret == project_signing_secret(tmpdir);
        } finally {
            _set_env(previous);
        }
    }
}


test "a cluster with no configured secret refuses to sign" {
    with TemporaryDirectory() as tmpdir {
        previous = _set_env({CLUSTER_ENV: "10.0.0.1", DATA_PATH_ENV: None});
        try {
            with testraises(ServeConfigError) as exc {
                ServeSettings.load(tmpdir).auth.resolve_secret(tmpdir);
            }
            assert "JAC_SERVE_AUTH_SECRET" in str(exc.value);
            assert not (Path(tmpdir) / ".jac" / "data" / "jwt_secret").exists();
        } finally {
            _set_env(previous);
        }
    }
}


test "a configured secret wins, so a deployment keeps its own source" {
    with TemporaryDirectory() as tmpdir {
        (Path(tmpdir) / "jac.toml").write_text(
            '[serve.auth]\nsecret = "deployed-secret"\n', encoding="utf-8"
        );
        previous = _set_env({CLUSTER_ENV: None, DATA_PATH_ENV: None});
        try {
            secret = ServeSettings.load(tmpdir).auth.resolve_secret(tmpdir);
            assert secret == "deployed-secret";
            assert not (Path(tmpdir) / ".jac" / "data" / "jwt_secret").exists();
        } finally {
            _set_env(previous);
        }
    }
}


test "the environment mirror overrides the project secret" {
    with TemporaryDirectory() as tmpdir {
        (Path(tmpdir) / "jac.toml").write_text(
            '[serve.auth]\nsecret = "deployed-secret"\n', encoding="utf-8"
        );
        previous = _set_env(
            {
                CLUSTER_ENV: None,
                DATA_PATH_ENV: None,
                "JAC_SERVE_AUTH_SECRET": "env-secret"
            }
        );
        try {
            assert ServeSettings.load(tmpdir).auth.resolve_secret(tmpdir)
                == "env-secret";
        } finally {
            _set_env(previous);
        }
    }
}
