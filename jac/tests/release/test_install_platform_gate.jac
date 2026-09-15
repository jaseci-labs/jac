"""Tests for what scripts/install.sh tells a user whose platform did not build.

A release-only build leg can now fail without blocking the release, so a
published release can genuinely carry no binary for a platform. The installer
has to say that outright, because there is nothing it can substitute: an arm64
macOS binary does not run on an Intel Mac, and Rosetta translates the other
direction. Before this, the user got a bare download failure and a list of
guesses.

`curl` and `uname` are stubbed on PATH, so these drive the real script against a
release whose asset list is under the test's control, with no network.
"""

import os;
import shutil;
import subprocess;
import tempfile;
import hashlib;
import from pathlib { Path }

glob REPO_ROOT: Path = Path(__file__).resolve().parents[3],
     INSTALLER: str = str(REPO_ROOT / "scripts" / "install.sh");

glob FAKE_UNAME: str = '#!/usr/bin/env bash\n'
         + 'case "$1" in\n'
         + '    -s) cat "$FAKE_OS" ;;\n'
         + '    -m) cat "$FAKE_ARCH" ;;\n'
         + '    *)  cat "$FAKE_OS" ;;\n'
         + 'esac\n';

glob FAKE_CURL: str = '#!/usr/bin/env bash\n'
         + 'url="${!#}"\n'
         + 'printf \'%s\\n\' "$url" >> "$FAKE_CURL_LOG"\n'
         + 'case "$url" in\n'
         + '    */releases/latest)\n'
         + '        echo \'{"tag_name": "v0.37.1"}\'\n'
         + '        ;;\n'
         + '    */releases/tags/v0.37.1)\n'
         + '        cat "$FAKE_RELEASE"\n'
         + '        ;;\n'
         + '    *"/releases?per_page="*)\n'
         + '        echo \'[{"tag_name": "v0.37.1"},{"tag_name": "v0.37.0"}]\'\n'
         + '        ;;\n'
         + '    */releases/tags/v0.37.0)\n'
         + '        cat "$FAKE_PRIOR" \n'
         + '        ;;\n'
         + '    */releases/download/*)\n'
         + '        cp "$FAKE_DOWNLOADS/${url##*/}" "$3"\n'
         + '        ;;\n'
         + '    *)\n'
         + '        exit 22\n'
         + '        ;;\n'
         + 'esac\n';

"""A release payload listing exactly the named assets."""
def release_json(names: list[str]) -> str {
    entries = ", ".join([f'{{"name": "{n}"}}' for n in names]);
    return '{"tag_name": "v0.37.1", "assets": [' + entries + ']}\n';
}

"""Stubbed `curl` and `uname` on PATH plus the files driving what they answer."""
def scaffold(arch: str, assets: list[str]) -> dict[(str, str)] {
    base = tempfile.mkdtemp(prefix="jac-install-platform-gate-");
    bindir = os.path.join(base, "bin");
    os.makedirs(bindir);
    fx = {
        "base": base,
        "bin": bindir,
        "os": os.path.join(base, "os.txt"),
        "arch": os.path.join(base, "arch.txt"),
        "release": os.path.join(base, "release.json"),
        "prior": os.path.join(base, "prior.json"),
        "downloads": os.path.join(base, "downloads"),
        "log": os.path.join(base, "curl.log")
    };
    os.makedirs(fx["downloads"]);
    for (name, body) in [("uname", FAKE_UNAME), ("curl", FAKE_CURL)] {
        p = Path(bindir) / name;
        p.write_text(body);
        os.chmod(str(p), 0o755);
    }
    Path(fx["os"]).write_text("Darwin\n");
    Path(fx["arch"]).write_text(arch + "\n");
    Path(fx["release"]).write_text(release_json(assets));
    Path(fx["prior"]).write_text(
        '{"tag_name": "v0.37.0", "assets": [{"name": "jac-0.37.0-macos-x86_64"}]}\n'
    );
    return fx;
}

def run_installer(
    fx: dict[(str, str)], args: list[str] | None = None
) -> subprocess.CompletedProcess[str] {
    env = dict(os.environ);
    env["PATH"] = fx["bin"] + os.pathsep + env["PATH"];
    env["HOME"] = fx["base"];
    env["FAKE_OS"] = fx["os"];
    env["FAKE_ARCH"] = fx["arch"];
    env["FAKE_RELEASE"] = fx["release"];
    env["FAKE_PRIOR"] = fx["prior"];
    env["FAKE_DOWNLOADS"] = fx["downloads"];
    env["FAKE_CURL_LOG"] = fx["log"];
    env.pop("GITHUB_TOKEN", None);
    env.pop("GH_TOKEN", None);
    return subprocess.run(
        ["bash", INSTALLER] + (args or []),
        cwd=fx["base"],
        env=env,
        capture_output=True,
        text=True
    );
}

test "an Intel Mac is told the release has no build for it, and which one does" {
    fx = scaffold(
        "x86_64",
        [
            "jac-0.37.1-linux-x86_64",
            "jac-0.37.1-linux-aarch64",
            "jac-0.37.1-macos-aarch64",
            "jac-0.37.1-admin-dist.tar.gz"
        ]
    );
    try {
        res = run_installer(fx);
        out = res.stdout + res.stderr;
        assert res.returncode != 0 , "installing a binary that does not exist must fail: "
            + out;
        assert ("macos-x86_64" in out) , "the message must name the platform it cannot serve: "
            + out;
        assert ("Intel" in out) , "the message must say plainly that there is no Intel build: "
            + out;
        assert ("--version 0.37.0" in out) , "the message must hand over the last release that had one: "
            + out;
        assert (not os.path.exists(os.path.join(fx["base"], ".local", "bin", "jac"))) , "nothing may be installed when the platform has no binary";
    } finally {
        shutil.rmtree(fx["base"], ignore_errors=True);
    }
}

test "an Intel Mac installs normally from a release that does carry the binary" {
    fx = scaffold("x86_64", ["jac-0.37.1-macos-x86_64", "jac-0.37.1-macos-aarch64"]);
    try {
        res = run_installer(fx);
        out = res.stdout + res.stderr;
        assert ("Downloading jac-0.37.1-macos-x86_64" in out) , "a present asset must go straight to the download: "
            + out;
        assert ("no jac binary" not in out) , "a present asset must not trip the missing-platform message: "
            + out;
    } finally {
        shutil.rmtree(fx["base"], ignore_errors=True);
    }
}

test "a platform with a binary is never told to go find another release" {
    fx = scaffold("arm64", ["jac-0.37.1-macos-aarch64", "jac-0.37.1-linux-x86_64"]);
    try {
        res = run_installer(fx);
        out = res.stdout + res.stderr;
        assert ("Downloading jac-0.37.1-macos-aarch64" in out) , "the asset list must be read from the release, not from a subshell that already exited: "
            + out;
    } finally {
        shutil.rmtree(fx["base"], ignore_errors=True);
    }
}

test "an early asset match survives a release larger than the pipe buffer" {
    assets = ["jac-0.37.1-macos-aarch64"];
    assets.extend([f"extra-asset-{i}" for i in range(16384)]);
    fx = scaffold("arm64", assets);
    try {
        res = run_installer(fx);
        out = res.stdout + res.stderr;
        assert "Downloading jac-0.37.1-macos-aarch64" in out , out;
    } finally {
        shutil.rmtree(fx["base"], ignore_errors=True);
    }
}

test "the installer downloads and verifies only the selected runtime" {
    standard = "jac-0.37.1-macos-aarch64";
    native = standard + "-jacpython";
    for (args, selected) in [
        ([], standard),
        (["--jacpython", "--version", "0.37.1"], native)
    ] {
        fx = scaffold(
            "arm64", [native, native + ".sha256", standard, standard + ".sha256"]
        );
        try {
            for asset in [standard, native] {
                body = f'#!/usr/bin/env bash\necho "{asset}"\n';
                Path(fx["downloads"], asset).write_text(body);
                digest = hashlib.sha256(body.encode()).hexdigest();
                Path(fx["downloads"], asset + ".sha256").write_text(
                    f"{digest}  {asset}\n"
                );
            }
            res = run_installer(fx, args);
            out = res.stdout + res.stderr;
            assert res.returncode == 0 , out;
            assert "Checksum verified." in out , out;
            installed = Path(fx["base"], ".local", "bin", "jac");
            assert installed.read_text() == Path(fx["downloads"], selected).read_text();
            downloads = [
                url.rsplit("/", 1)[-1]
                for url in Path(fx["log"]).read_text().splitlines()
                if "/releases/download/" in url
            ];
            assert downloads == [selected, selected + ".sha256"] , str(downloads);
        } finally {
            shutil.rmtree(fx["base"], ignore_errors=True);
        }
    }
}

test "a missing JacPython asset fails without installing the default runtime" {
    fx = scaffold("x86_64", ["jac-0.37.1-macos-x86_64"]);
    try {
        res = run_installer(fx, ["--jacpython"]);
        out = res.stdout + res.stderr;
        assert res.returncode != 0;
        assert "no JacPython binary" in out , out;
        assert "omit --jacpython" in out , out;
        assert "no Intel macOS build" not in out , out;
        assert "/releases/download/" not in Path(fx["log"]).read_text();
        assert not Path(fx["base"], ".local", "bin", "jac").exists();
    } finally {
        shutil.rmtree(fx["base"], ignore_errors=True);
    }
}
