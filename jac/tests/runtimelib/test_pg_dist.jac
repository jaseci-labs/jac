"""The Postgres distribution resolves through the artifact router: a configured
dist wins, a cached one is found without the network, and a missing one is
provisioned loudly -- or refused in an offline project."""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from jaclang.artifacts.model { ArtifactUnavailable, Source }
import from jaclang.artifacts.router { forget, require, resolve }
import from jaclang.project.config { DatabaseConfig, JacConfig }
import from tests.support { offline_project }

def _fake_dist(bin_dir: Path) -> Path {
    bin_dir.mkdir(parents=True);
    (bin_dir / "postgres").write_text("");
    return bin_dir;
}

def _project_config(project: Path, database: DatabaseConfig) -> JacConfig {
    config = JacConfig();
    config.project_root = project;
    config.database = database;
    return config;
}

def _resolve_in(
    cache: str, config: (JacConfig | None), env: (dict[str, str] | None) = None
) -> any {
    forget("postgres");
    overrides = {"JAC_CACHE_HOME": cache, "JAC_PG_DIST": "", "JAC_PG_HOME": ""};
    if env {
        overrides.update(env);
    }
    with patch.dict(os.environ, overrides), patch(
        "jaclang.project.config.get_config", return_value=config
    ), patch("jaclang.data.pg_dist._system", return_value=None) {
        return resolve("postgres");
    }
}

test "a configured distribution wins, relative to its project" {
    with TemporaryDirectory() as tmp {
        project = Path(tmp);
        _fake_dist(project / "pg" / "bin");
        resolution = _resolve_in(
            str(project / "cache"),
            _project_config(project, DatabaseConfig(postgres_dist="pg"))
        );
        assert resolution.found is not None;
        assert resolution.found.source == Source.CONFIGURED;
        assert resolution.found.path == str(project / "pg" / "bin");
    }
}

test "a configured distribution without binaries is named, not skipped" {
    with TemporaryDirectory() as tmp {
        project = Path(tmp);
        resolution = _resolve_in(
            str(project / "cache"),
            _project_config(project, DatabaseConfig(postgres_dist="nope"))
        );
        assert resolution.found is None;
        assert "postgres_dist" in resolution.reason , resolution.reason;
    }
}

test "a cached distribution of the pinned major is found without the network" {
    import from jaclang.data.pg_dist { PG_MAJOR, platform_slug }
    slug = platform_slug();
    if slug is None {
        return;
    }
    with TemporaryDirectory() as tmp {
        dist = Path(tmp) / "pg" / "dist";
        _fake_dist(dist / f"{slug}-{PG_MAJOR - 1}.4.0" / "bin");
        pinned = _fake_dist(dist / f"{slug}-{PG_MAJOR}.1.0" / "bin");
        with patch("jaclang.data.pg_dist._published", side_effect=AssertionError) {
            resolution = _resolve_in(tmp, None);
        }
        assert resolution.found is not None;
        assert resolution.found.source == Source.CACHE;
        assert resolution.found.path == str(pinned);
    }
}

test "an offline project refuses to provision a missing distribution" {
    with TemporaryDirectory() as tmp {
        forget("postgres");
        with patch.dict(
            os.environ, {"JAC_CACHE_HOME": tmp, "JAC_PG_DIST": "", "JAC_PG_HOME": ""}
        ), patch("jaclang.project.config.get_config", return_value=None), patch(
            "jaclang.data.pg_dist._system", return_value=None
        ), patch("jaclang.data.pg_dist.download_dist", side_effect=AssertionError), offline_project() {
            try {
                require("postgres");
                assert False , "an offline project must not provision";
            } except ArtifactUnavailable as e {
                assert "offline" in str(e) , str(e);
            }
        }
        forget("postgres");
    }
}

test "a missing distribution is provisioned once, loudly" {
    import from jaclang.data.pg_dist { platform_slug }
    slug = platform_slug();
    if slug is None {
        return;
    }
    with TemporaryDirectory() as tmp {
        calls: list[str] = [];
        def _download -> str {
            calls.append("download");
            return str(
                _fake_dist(Path(tmp) / "pg" / "dist" / f"{slug}-19.0.0" / "bin")
            );
        }
        forget("postgres");
        with patch.dict(
            os.environ, {"JAC_CACHE_HOME": tmp, "JAC_PG_DIST": "", "JAC_PG_HOME": ""}
        ), patch("jaclang.project.config.get_config", return_value=None), patch(
            "jaclang.data.pg_dist._system", return_value=None
        ), patch("jaclang.data.pg_dist.download_dist", side_effect=_download), patch(
            "jaclang.project.config.offline_mode", return_value=False
        ) {
            found = require("postgres").found;
            assert found is not None and found.source == Source.CACHE;
            require("postgres");
        }
        assert calls == ["download"] , calls;
        forget("postgres");
    }
}


test "JAC_PG_DIST wins over a configured distribution" {
    with TemporaryDirectory() as tmp {
        project = Path(tmp);
        _fake_dist(project / "envpg" / "bin");
        resolution = _resolve_in(
            str(project / "cache"),
            _project_config(project, DatabaseConfig(postgres_dist="confpg")),
            env={"JAC_PG_DIST": str(project / "envpg")}
        );
        assert resolution.found is not None;
        assert resolution.found.source == Source.CONFIGURED;
        assert resolution.found.path == str(project / "envpg" / "bin");
    }
}


test "a broken JAC_PG_DIST fails closed, never the system" {
    with TemporaryDirectory() as tmp {
        project = Path(tmp);
        resolution = _resolve_in(
            str(project / "cache"),
            _project_config(project, DatabaseConfig(postgres_dist="confpg")),
            env={"JAC_PG_DIST": str(project / "missing")}
        );
        assert resolution.found is None;
        assert "JAC_PG_DIST" in resolution.reason , resolution.reason;
    }
}


test "the platform slug and server name cover Windows" {
    import from jaclang.data.pg_dist { platform_slug, postgres_exe }
    with patch("jaclang.data.pg_dist.platform.system", return_value="Windows"), patch(
        "jaclang.data.pg_dist.platform.machine", return_value="AMD64"
    ) {
        assert platform_slug() == "windows-amd64";
        assert postgres_exe() == "postgres.exe";
    }
}


test "the postgres artifact claims exactly the platforms it supports" {
    import sys;
    import from jaclang.data.pg_dist { PostgresArtifact }
    artifact = PostgresArtifact();
    for (token, expected) in [
        ("linux", True),
        ("darwin", True),
        ("win32", True),
        ("freebsd", False)
    ] {
        with patch.object(sys, "platform", token) {
            assert artifact.host_supported() == expected , f"{token} expected {expected}";
        }
    }
}


test "bundled_dist_dir vendors only a relocatable distribution" {
    import from jaclang.data.pg_dist { bundled_dist_dir }
    with TemporaryDirectory() as tmp {
        project = Path(tmp);
        relocatable = project / "pg";
        _fake_dist(relocatable / "bin");
        (relocatable / "lib").mkdir(parents=True);
        (relocatable / "share").mkdir();
        with patch.dict(os.environ, {"JAC_PG_DIST": str(relocatable)}) {
            assert bundled_dist_dir() == str(relocatable);
        }
        # A system layout with libraries but no share tree beside the
        # binaries (Debian's /usr/lib/postgresql/<v>) cannot run from a
        # copied tree: its share data lives outside the prefix.
        debian = project / "usr" / "lib" / "postgresql" / "17";
        _fake_dist(debian / "bin");
        (debian / "lib").mkdir(parents=True);
        with patch.dict(os.environ, {"JAC_PG_DIST": str(debian)}) {
            try {
                bundled_dist_dir();
                assert False , "a system tree without share/ must not be bundled";
            } except ArtifactUnavailable as e {
                assert "share/" in str(e) , str(e);
            }
        }
        bare = project / "system";
        _fake_dist(bare / "bin");
        with patch.dict(os.environ, {"JAC_PG_DIST": str(bare)}) {
            try {
                bundled_dist_dir();
                assert False , "a bare system bin dir must not be bundled";
            } except ArtifactUnavailable as e {
                assert "lib/" in str(e) , str(e);
            }
        }
    }
}


test "an invalid JAC_PG_DIST refuses before any fetch" {
    with TemporaryDirectory() as tmp {
        broken = Path(tmp) / "missing";
        with patch.dict(
            os.environ,
            {"JAC_CACHE_HOME": str(Path(tmp) / "cache"), "JAC_PG_DIST": str(broken)}
        ), patch("jaclang.data.pg_dist._system", return_value=None), patch(
            "jaclang.data.pg_dist.download_dist",
            side_effect=AssertionError("an invalid override must not fetch")
        ) {
            forget("postgres");
            try {
                require("postgres");
                assert False , "an invalid override must not resolve";
            } except ArtifactUnavailable as e {
                assert "JAC_PG_DIST" in str(e) , str(e);
            }
        }
        forget("postgres");
    }
}


test "an offline build refuses to fetch a missing distribution" {
    import from jaclang.data.pg_dist { bundled_dist_dir }
    with TemporaryDirectory() as tmp {
        config = JacConfig();
        config.network.offline = True;
        with patch.dict(
            os.environ, {"JAC_CACHE_HOME": str(Path(tmp) / "cache"), "JAC_PG_DIST": ""}
        ), patch("jaclang.project.config.get_config", return_value=config), patch(
            "jaclang.data.pg_dist.download_dist",
            side_effect=AssertionError("must not reach Maven when offline")
        ) {
            try {
                bundled_dist_dir();
                assert False , "an offline miss must not fetch";
            } except ArtifactUnavailable as e {
                assert "offline" in str(e) , str(e);
            }
        }
    }
}


test "JAC_PG_HOME relocates the pg bucket" {
    import from jaclang.cache.registry { bucket }
    with TemporaryDirectory() as tmp {
        with patch.dict(os.environ, {"JAC_PG_HOME": tmp}) {
            assert str(bucket("pg").path()) == os.path.join(tmp, "pg");
        }
    }
}

test "a dev host runs the distribution it selected, not a cache pick" {
    import from jaclang.data.pg_dist { PG_MAJOR, cached_dist_dir, platform_slug }
    slug = platform_slug();
    if slug is None {
        return;
    }
    with TemporaryDirectory() as tmp {
        project = Path(tmp);
        cached_tree = Path(tmp) / "cache" / "pg" / "dist" / f"{slug}-{PG_MAJOR}.9.9";
        _fake_dist(cached_tree / "bin");
        (cached_tree / "lib").mkdir();
        (cached_tree / "share").mkdir();
        selected = project / "selected";
        _fake_dist(selected / "bin");
        (selected / "lib").mkdir();
        (selected / "share").mkdir();
        # An explicit JAC_PG_DIST wins over the shared cache...
        with patch.dict(
            os.environ,
            {
                "JAC_CACHE_HOME": str(project / "cache"),
                "JAC_PG_HOME": "",
                "JAC_PG_DIST": str(selected)
            }
        ), patch("jaclang.project.config.get_config", return_value=None) {
            assert cached_dist_dir() == str(selected);
        }
        # ...and so does a configured distribution.
        configured = project / "configured";
        _fake_dist(configured / "bin");
        (configured / "lib").mkdir();
        (configured / "share").mkdir();
        with patch.dict(
            os.environ,
            {
                "JAC_CACHE_HOME": str(project / "cache"),
                "JAC_PG_HOME": "",
                "JAC_PG_DIST": ""
            }
        ), patch(
            "jaclang.project.config.get_config",
            return_value=_project_config(
                project, DatabaseConfig(postgres_dist="configured")
            )
        ) {
            assert cached_dist_dir() == str(configured);
        }
        # A selection that cannot serve a dev host is not silently replaced
        # by a cache pick of another version.
        with patch.dict(
            os.environ,
            {
                "JAC_CACHE_HOME": str(project / "cache"),
                "JAC_PG_HOME": "",
                "JAC_PG_DIST": str(project / "missing")
            }
        ), patch("jaclang.project.config.get_config", return_value=None) {
            assert cached_dist_dir() == "" , "must not substitute a cache pick";
        }
        # With no selection, the shared cache still serves.
        with patch.dict(
            os.environ,
            {
                "JAC_CACHE_HOME": str(project / "cache"),
                "JAC_PG_HOME": "",
                "JAC_PG_DIST": ""
            }
        ), patch("jaclang.project.config.get_config", return_value=None) {
            assert cached_dist_dir() == str(cached_tree);
        }
    }
}
