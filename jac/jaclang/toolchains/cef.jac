import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.jac0core.cache_paths { FileLock }
import from jaclang.toolchains.store { Artifact, install }
import from jaclang.toolchains.host { host_platform }

def cef_artifact(sums: Path) -> Artifact {
    version = "";
    for line in sums.read_text().splitlines() {
        if line.startswith("# version:") {
            version = line.split(":", 1)[1].strip();
        }
    }
    version = os.environ.get("CEF_VERSION", "") or version;
    platforms = {"linux-x64": "linux64", "linux-aarch64": "linuxarm64"};
    host = host_platform();
    tag = platforms.get(host);
    if tag is None {
        raise RuntimeError(f"CEF desktop builds are not supported on {host}");
    }
    archive = f"cef_binary_{version}_{tag}.tar.bz2";
    for line in sums.read_text().splitlines() {
        parts = line.split();
        if len(parts) == 2 and parts[1] == archive {
            return Artifact(
                "cef",
                version,
                host,
                "https://cef-builds.spotifycdn.com/" + archive,
                parts[0],
                "sha1"
            );
        }
    }
    raise RuntimeError(f"No pinned checksum for {archive}");
}

def ensure_cef(directory: Path, headers_only: bool = False) -> Path {
    artifact = cef_artifact(directory / "cef_sums.lock");
    top = artifact.url.rsplit("/", 1)[1].removesuffix(".tar.bz2");
    installed = install(artifact, top + "/Release/libcef.so") / top;
    with FileLock(directory / ".cef.lock") {
        stamp = directory / ".cef-digest";
        healthy = (directory / "cef_dist" / "libcef.so").is_file()
            and (
                directory / "cef_headers" / "include" / "capi" / "cef_app_capi.h"
            ).is_file();
        if not healthy or not stamp.exists() or stamp.read_text() != artifact.digest {
            with tempfile.TemporaryDirectory(dir=directory) as tmp {
                staged = Path(tmp);
                headers = staged / "cef_headers";
                shutil.copytree(installed / "include", headers / "include");
                runtime = staged / "cef_dist";
                shutil.copytree(installed / "Release", runtime);
                shutil.copytree(installed / "Resources", runtime, dirs_exist_ok=True);
                for name in ["cef_headers", "cef_dist"] {
                    destination = directory / name;
                    if destination.exists() {
                        shutil.rmtree(destination);
                    }
                    (staged / name).replace(destination);
                }
            }
            stamp.write_text(artifact.digest);
        }
    }
    return directory / ("cef_headers" if headers_only else "cef_dist");
}
