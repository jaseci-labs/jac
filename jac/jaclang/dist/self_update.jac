import ctypes;
import os;
import platform;
import re;
import shutil;
import tempfile;
import urllib.request;
import from jaclang.cli.console { console }
import from pathlib { Path }

glob SELF_UPDATE_REPO: str = "jaseci-labs/jaseci";

def platform_triple(system: str = "", machine: str = "") -> ((str, str) | None) {
    os_name = (system or platform.system()).lower();
    cpu = (machine or platform.machine()).lower();
    if os_name == "linux" {
        plat = "linux";
    } elif os_name == "darwin" {
        plat = "macos";
    } else {
        return None;
    }
    if cpu in ("x86_64", "amd64") {
        arch = "x86_64";
    } elif cpu in ("aarch64", "arm64") {
        arch = "aarch64";
    } else {
        return None;
    }
    return (plat, arch);
}

def release_asset(
    assets: list[any], plat: str, arch: str
) -> ((dict[str, any], str) | None) {
    pattern = re.compile(rf"^jac-(\d+\.\d+\.\d+)-{re.escape(plat)}-{re.escape(arch)}$");
    for asset in assets {
        m = pattern.match(str(asset.get("name", "")));
        if m {
            return (asset, m.group(1));
        }
    }
    return None;
}

def up_to_date(current: str, latest: str) -> bool {
    import from jaclang.packages.semver { SemverError, Version }
    try {
        return Version.parse(current) >= Version.parse(latest);
    } except SemverError {
        return False;
    }
}

def _fetch_text(url: str) -> (str | None) {
    request = urllib.request.Request(url, headers={"User-Agent": "jac-update"});
    try {
        with urllib.request.urlopen(request, timeout=60) as response {
            return response.read().decode("utf-8");
        }
    } except OSError {
        return None;
    }
}

def _sidecar_digest(url: str) -> (str | None) {
    text = _fetch_text(f"{url}.sha256");
    if text is None {
        return None;
    }
    token = text.split()[0] if text.split() else "";
    if re.fullmatch(r"[0-9a-f]{64}", token) {
        return token;
    }
    return None;
}

def _running_jacpython -> bool {
    return hasattr(ctypes.pythonapi, "_PyJac_CompilerBridgeVersion");
}

def update_self(release: str, current: str, verbose: bool) -> int {
    import from jaclang.dist.fused_binary {
        linked_source_dir,
        materialized_runtime_dir,
        running_executable,
        runtime_trailer
    }

    triple = platform_triple();
    if triple is None {
        console.error(
            f"jac update --self has no binary for {platform.system()} {platform.machine()}.",
            hint=(
                "Watch https://github.com/"
                f"{SELF_UPDATE_REPO}/releases for new platforms"
            )
        );
        return 1;
    }
    (plat, arch) = triple;

    target = Path(running_executable());
    if runtime_trailer(str(target)) is None {
        console.error(
            "jac update --self only updates the self-contained jac binary.",
            hint=(
                "This session is not running from one (a plain interpreter or "
                "a source checkout). Refresh with: curl -fsSL "
                f"https://raw.githubusercontent.com/{SELF_UPDATE_REPO}/main/"
                "scripts/install.sh | bash"
            )
        );
        return 1;
    }
    linked = linked_source_dir(materialized_runtime_dir() or "");
    if linked {
        console.error(
            "jac update --self refuses to replace a linked dev binary.",
            hint=(
                f"This launcher compiles the jaclang source at {linked}; "
                "updating it would strand the dev loop. Pull and rebuild "
                "instead: git pull && ./scripts/fresh_env.sh"
            )
        );
        return 1;
    }
    if _running_jacpython() {
        console.error(
            "jac update --self refuses to downgrade a JacPython install.",
            hint=(
                "This session runs the experimental JacPython build, but the "
                "release channel only ships the default CPython binary; "
                "updating would silently lose the JacPython compiler. "
                "Reinstall instead: curl -fsSL "
                f"https://raw.githubusercontent.com/{SELF_UPDATE_REPO}/main/"
                "scripts/install.sh | bash -s -- --jacpython"
            )
        );
        return 1;
    }
    if (target.parent / "metadata.json").is_file() {
        console.error(
            "jac update --self refuses to replace a jacup-managed install.",
            hint=(
                f"{target.parent} is owned by jacup (metadata.json sits beside "
                "the launcher); replacing the binary in place would desync "
                "jacup's version records. Update with: jacup update"
            )
        );
        return 1;
    }
    if not os.access(str(target), os.W_OK)
        or not os.access(str(target.parent), os.W_OK) {
        console.error(
            f"No write permission for {target} (or its directory).",
            hint=(
                "Fix the permissions, or reinstall to a writable location "
                "such as ~/.local/bin with the install script."
            )
        );
        return 1;
    }

    tag = release[1:] if release.startswith("v") else release;
    console.info("Fetching release info...");
    import from jaclang.packages.github { GitHub, GitHubError, find_token }
    try {
        rel = GitHub(token=find_token()).release(SELF_UPDATE_REPO, tag);
    } except GitHubError as e {
        console.error(
            f"GitHub API failed: {e}",
            hint="Rate limited? Set GITHUB_TOKEN (or GH_TOKEN), or retry in a moment."
        );
        return 1;
    }
    if rel is None {
        if tag {
            console.error(
                f"No release v{tag} on {SELF_UPDATE_REPO}.",
                hint=f"See https://github.com/{SELF_UPDATE_REPO}/releases"
            );
        } else {
            console.error(f"No releases published on {SELF_UPDATE_REPO} yet.");
        }
        return 1;
    }
    rel_tag = str(rel.get("tag_name", "")) or f"v{tag}";
    found = release_asset(rel.get("assets", []), plat, arch);
    if found is None {
        console.error(
            f"Release {rel_tag} ships no jac binary for {plat}-{arch}.",
            hint=(
                "See https://github.com/"
                f"{SELF_UPDATE_REPO}/releases for the platforms that built"
            )
        );
        return 1;
    }
    (asset, asset_ver) = found;
    name = str(asset.get("name", ""));
    url = str(asset.get("browser_download_url", ""));
    if not url {
        console.error(f"Release asset '{name}' has no download URL.");
        return 1;
    }

    if not tag and up_to_date(current, asset_ver) {
        console.success(f"jac is up to date ({current}).");
        return 0;
    }

    mode = os.stat(str(target)).st_mode & 0o777;

    stage = Path(
        tempfile.mkdtemp(dir=str(target.parent), prefix=f".{target.name}.update-")
    );
    try {
        digest = _sidecar_digest(url);
        if digest is None {
            console.error(
                f"No usable sha256 published for {name}.",
                hint="Refusing to install an unverified binary; try again later."
            );
            return 1;
        }
        console.info(f"Downloading {name} ({rel_tag})...");
        tmp = stage / target.name;
        import from jaclang.toolchains.store { Artifact, fetch }
        try {
            fetch(
                Artifact(
                    name="jac",
                    version=rel_tag,
                    platform=f"{plat}-{arch}",
                    url=url,
                    digest=digest
                ),
                destination=tmp
            );
        } except (ValueError, RuntimeError, OSError) as e {
            console.error(f"Download failed: {e}", hint="Try again in a moment.");
            return 1;
        }
        if verbose {
            console.info(f"Checksum OK ({digest[:16]}...).");
        }
        if runtime_trailer(str(tmp)) is None {
            console.error(
                f"Downloaded {name} is not a jac binary (no runtime trailer).",
                hint=(
                    "Refusing to replace the launcher with an unrunnable "
                    "artifact; the installed version is untouched. Report it "
                    "at https://github.com/jaseci-labs/jaseci/issues"
                )
            );
            return 1;
        }
        os.chmod(str(tmp), mode);
        os.replace(str(tmp), str(target));
    } finally {
        shutil.rmtree(stage, ignore_errors=True);
    }
    console.success(f"Updated jac {current} -> {asset_ver} ({target}).");
    console.info(
        "Running jac processes keep their version; new invocations use the updated binary."
    );
    return 0;
}
