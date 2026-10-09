"""`jac update --self`: offline tests for the self-update flow.

GitHub and download calls are patched at their module boundaries
(`GitHub.release`, the `.sha256` sidecar GET, toolchains `fetch`, the
JacPython probe -- the fake fetch still enforces the digest contract); the update
target is a throwaway file with a real JACBIN01 trailer, so the genuine trailer
parser and the genuine atomic replace are exercised.
"""

import os;
import hashlib;
import tempfile;
import shutil;
import from pathlib { Path }
import from unittest.mock { patch }

import from jaclang.cli.commands { project as cmds }
import from jaclang.dist.fused.trailer { MAGIC, build_trailer }
import from jaclang.dist.fused_binary { linked_source_dir }
import from jaclang.dist.self_update {
    platform_triple,
    release_asset,
    update_self,
    up_to_date
}


def fake_release(ver: str) -> dict[str, any] {
    # One platform asset plus the dev/jacpython look-alikes that must never match.
    return {
        "tag_name": "v24.1",
        "assets": [
            {
                "name": f"jac-{ver}-linux-x86_64",
                "browser_download_url": f"https://x.test/jac-{ver}-linux-x86_64"
            },
            {"name": f"jac-{ver}-linux-x86_64-jacpython"},
            {"name": "jac-dev-linux-x86_64"}
        ]
    };
}


def fake_bin(data: bytes = b"\x7fJAC fake launcher") -> bytes {
    return data + build_trailer(MAGIC, len(data), hashlib.sha256(data).hexdigest());
}


# Runs update_self against a temp target with GitHub, the sidecar, and the
# runtime fingerprint faked. Returns (rc, target, fetch_mock, tags, tmpdir);
# `tags` collects the tag each GitHub.release lookup asked for.
def run_flow(
    release: str = "",
    ver: str = "1.2.2",
    asset_ver: str = "1.2.3",
    payload: bytes = fake_bin(b"new body"),
    real_bin: bool = True,
    linked: str | None = None,
    readonly: bool = False,
    jacpython: bool = False,
    managed: bool = False,
    sidecar: str = "ok"
) -> (int, Path, any, list[str], Path) {
    tmp = Path(tempfile.mkdtemp(prefix="upd_self_"));
    target = tmp / "jac";
    body = fake_bin() if real_bin else b"#!/bin/sh\necho nope\n";
    target.write_bytes(body);
    os.chmod(target, 0o755);
    if managed {
        (tmp / "metadata.json").write_text(
            '{"installed_at":"2026-01-01T00:00:00Z","sha256":"'
                + ("0" * 64)
                + '","target":"linux-x86_64","url":"https://x.test/jac","version":"'
                + ver
                + '"}'
        );
    }

    digest = hashlib.sha256(payload).hexdigest();
    tags: list[str] = [];

    def fake_release_call(repo: str, tag: str) -> dict[str, any] {
        tags.append(tag);
        return fake_release(asset_ver);
    }

    def fake_sidecar(url: str) -> (str | None) {
        if sidecar == "missing" {
            return None;
        }
        if sidecar == "junk" {
            return "not-a-checksum\n";
        }
        lying = sidecar == "lying";
        return ("0" * 64 if lying else digest) + "\n";
    }

    def fake_fetch(
        artifact: any, destination: any = None, bucket_name: str = ""
    ) -> Path {
        # The real fetch verifies the digest before the file lands.
        if artifact.digest != digest {
            raise ValueError(
                f"Checksum mismatch for {artifact.name} {artifact.version}"
            );
        }
        Path(destination).write_bytes(payload);
        return Path(destination);
    }

    fetchm = patch("jaclang.toolchains.store.fetch", side_effect=fake_fetch).start();
    patch("jaclang.dist.self_update._fetch_text", side_effect=fake_sidecar).start();
    patch(
        "jaclang.dist.self_update._running_jacpython", return_value=jacpython
    ).start();
    patch(
        "jaclang.packages.github.GitHub.release", side_effect=fake_release_call
    ).start();
    patch(
        "jaclang.dist.fused_binary.materialized_runtime_dir", return_value=None
    ).start();
    patch(
        "jaclang.dist.fused_binary.running_executable", return_value=str(target)
    ).start();
    if linked is not None {
        patch(
            "jaclang.dist.fused_binary.linked_source_dir", return_value=linked
        ).start();
    }
    if readonly {
        os.chmod(tmp, 0o555);
    }
    try {
        rc = update_self(release, ver, False);
    } finally {
        patch.stopall();
        if readonly {
            os.chmod(tmp, 0o755);
        }
    }
    return (rc, target, fetchm, tags, tmp);
}


test "platform triple maps linux and macos hosts, rejects the rest" {
    assert platform_triple("Linux", "x86_64") == ("linux", "x86_64");
    assert platform_triple("Linux", "amd64") == ("linux", "x86_64");
    assert platform_triple("Darwin", "arm64") == ("macos", "aarch64");
    assert platform_triple("Windows", "x86_64") is None;
    assert platform_triple("Linux", "s390x") is None;
}


test "asset match takes the default binary only, with its version" {
    hit = release_asset(fake_release("2.3.1")["assets"], "linux", "x86_64");
    assert hit is not None
        and hit[0]["name"] == "jac-2.3.1-linux-x86_64"
        and hit[1] == "2.3.1";
    near = [
        {"name": "jac-dev-linux-x86_64"},
        {"name": "jac-2.3.1-linux-x86_64-jacpython"},
        {"name": "jac-2.3.1-linux-aarch64"}
    ];
    assert release_asset(near, "linux", "x86_64") is None;
    assert release_asset([], "macos", "aarch64") is None;
}


test "version gate ranks semver, demotes unparseable locals" {
    assert up_to_date("1.2.2", "1.2.3") is False;
    assert up_to_date("1.2.3", "1.2.3") is True;
    assert up_to_date("1.3.0", "1.2.3") is True;
    assert up_to_date("dev", "1.2.3") is False;
}


test "linked-source marker read back; missing dir reads empty" {
    tmp = Path(tempfile.mkdtemp(prefix="upd_self_"));
    try {
        assert linked_source_dir("") == "";
        assert linked_source_dir(str(tmp)) == "";
        (tmp / "site").mkdir();
        (tmp / "site" / "jac_linked_source").write_text("/repo/jac\n");
        assert linked_source_dir(str(tmp)) == "/repo/jac";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "update rejects --release without --self" {
    assert cmds.update(release="2.3.1") == 1;
}


test "update rejects package names with --self" {
    assert cmds.update(self_update=True, packages=["somepkg"]) == 1;
}


test "guard: non-binary target refuses before any download" {
    (rc, target, fetchm, tags, tmp) = run_flow(real_bin=False);
    try {
        assert rc == 1 and fetchm.call_count == 0;
        assert b"nope" in target.read_bytes();
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "guard: linked dev binary refuses before any download" {
    (rc, target, fetchm, tags, tmp) = run_flow(linked="/repo/jac");
    try {
        assert rc == 1 and fetchm.call_count == 0;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "guard: readonly install refuses before any download" {
    if os.geteuid() != 0 {
        (rc, target, fetchm, tags, tmp) = run_flow(readonly=True);
        assert rc == 1 and fetchm.call_count == 0;
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "guard: JacPython install refuses before any download" {
    (rc, target, fetchm, tags, tmp) = run_flow(jacpython=True);
    try {
        assert rc == 1 and fetchm.call_count == 0;
        assert b"fake launcher" in target.read_bytes();
        assert [p.name for p in tmp.iterdir()] == ["jac"];
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "guard: jacup-managed install refuses before any download" {
    (rc, target, fetchm, tags, tmp) = run_flow(managed=True);
    try {
        assert rc == 1 and fetchm.call_count == 0;
        assert b"fake launcher" in target.read_bytes();
        assert sorted(p.name for p in tmp.iterdir()) == ["jac", "metadata.json"];
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "guard: release without a published checksum refuses" {
    (rc, target, fetchm, tags, tmp) = run_flow(sidecar="missing");
    try {
        assert rc == 1 and fetchm.call_count == 0;
        assert b"fake launcher" in target.read_bytes();
        assert [p.name for p in tmp.iterdir()] == ["jac"];
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "flow: downloads, checksum-verifies, replaces atomically" {
    payload = fake_bin(b"#!/bin/sh\necho new jac\n");
    (rc, target, fetchm, tags, tmp) = run_flow(payload=payload);
    try {
        assert rc == 0;
        assert target.read_bytes() == payload;
        assert (os.stat(target).st_mode & 0o777) == 0o755;
        assert fetchm.call_count == 1;
        sent = fetchm.call_args[0][0];
        assert sent.digest == hashlib.sha256(payload).hexdigest();
        assert tags == [""];  # latest-release lookup
        assert [p.name for p in tmp.iterdir()] == ["jac"];
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "flow: lying checksum keeps the old binary, cleans temp files" {
    (rc, target, fetchm, tags, tmp) = run_flow(sidecar="lying");
    try {
        assert rc == 1;
        assert b"fake launcher" in target.read_bytes();
        assert [p.name for p in tmp.iterdir()] == ["jac"];
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "flow: checksum-clean but trailer-less download refuses, keeps old binary" {
    (rc, target, fetchm, tags, tmp) = run_flow(
        payload=b"#!/bin/sh\necho not a jac binary\n"
    );
    try {
        assert rc == 1 and fetchm.call_count == 1;
        assert b"fake launcher" in target.read_bytes();
        assert [p.name for p in tmp.iterdir()] == ["jac"];
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "flow: unusable checksum line refuses like a missing one" {
    (rc, target, fetchm, tags, tmp) = run_flow(sidecar="junk");
    try {
        assert rc == 1 and fetchm.call_count == 0;
        assert b"fake launcher" in target.read_bytes();
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "flow: already-current short-circuits without downloading" {
    (rc, target, fetchm, tags, tmp) = run_flow(ver="1.2.3");
    try {
        assert rc == 0 and fetchm.call_count == 0;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "flow: explicit --release reinstalls even when current" {
    (rc, target, fetchm, tags, tmp) = run_flow(release="1.2.3", ver="1.2.3");
    try {
        assert rc == 0 and fetchm.call_count == 1;
        assert target.read_bytes() == fake_bin(b"new body");
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "flow: v-prefixed --release pins the stripped tag" {
    (rc, target, fetchm, tags, tmp) = run_flow(release="v1.2.3");
    try {
        assert rc == 0 and tags == ["1.2.3"];
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
