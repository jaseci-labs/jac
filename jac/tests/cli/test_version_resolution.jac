"""Version-resolution tests for `jac --version` (#8804).

`resolve_cli_version` must honor the manifest walk-up contract documented in
jac.toml: the nearest ANCESTOR jac.toml wins, no merging. The dev-mode probes
start from the directory containing jaclang/ (JAC_DEV_SOURCE, or derived from
jaclang.__file__), while the manifest usually lives at the repo root above it,
so a probe that only checks the starting directory silently falls through to
the launcher binary's baked-in dist metadata and misreports the version.
"""

import os;
import tempfile;
import from pathlib { Path }
import from jaclang.cli.manifest_route { _nearest_toml_version, resolve_cli_version }


def _make_tree(base: Path, rel: str, toml_at: str, version: (str | None)) -> Path {
    start = base / rel;
    start.mkdir(parents=True, exist_ok=True);
    body = f'[project]\nname = "x"\nversion = "{version}"\n' if version else '[project]\nname = "x"\n';
    (base / toml_at / 'jac.toml').write_text(body, encoding='utf-8');
    return start;
}


test "version is read from a jac.toml in the starting directory" {
    with tempfile.TemporaryDirectory() as td {
        start = _make_tree(Path(td), 'jac', 'jac', '1.2.3');
        assert _nearest_toml_version(start) == '1.2.3';
    }
}

test "version walks up to the nearest ancestor jac.toml" {
    with tempfile.TemporaryDirectory() as td {
        start = _make_tree(Path(td), 'repo/jac', 'repo', '4.5.6');
        assert _nearest_toml_version(start) == '4.5.6';
    }
}

test "nearest jac.toml wins even without a version (no merging)" {
    with tempfile.TemporaryDirectory() as td {
        base = Path(td);
        start = _make_tree(base, 'repo/jac', 'repo', '7.8.9');
        (base / 'repo' / 'jac' / 'jac.toml').write_text('[dev]\n', encoding='utf-8');
        assert _nearest_toml_version(start) is None;
    }
}

test "no jac.toml on the walk-up path yields None" {
    with tempfile.TemporaryDirectory() as td {
        deep = Path(td) / 'a' / 'b';
        deep.mkdir(parents=True);
        assert _nearest_toml_version(deep) is None;
    }
}

test "resolve_cli_version honors JAC_DEV_SOURCE pointing below the manifest" {
    with tempfile.TemporaryDirectory() as td {
        start = _make_tree(Path(td), 'repo/jac', 'repo', '9.9.9');
        saved = os.environ.get('JAC_DEV_SOURCE');
        os.environ['JAC_DEV_SOURCE'] = str(start);
        try {
            assert resolve_cli_version() == '9.9.9';
        } finally {
            if saved is None {
                del os.environ['JAC_DEV_SOURCE'];
            } else {
                os.environ['JAC_DEV_SOURCE'] = saved;
            }
        }
    }
}
