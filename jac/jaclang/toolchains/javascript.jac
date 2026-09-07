import from jaclang.toolchains.host { use_system_tools }
import os;
import shutil;
import subprocess;
import from pathlib { Path }
import from jaclang.toolchains.host { host_platform }
import from jaclang.toolchains.pins { NODE_ARTIFACTS }
import from jaclang.toolchains.store { install, offline }

def native_node -> Path {
    found = shutil.which("node");
    if found and use_system_tools() {
        try {
            result = subprocess.run(
                [found, "--version"], capture_output=True, text=True, timeout=15
            );
            if result.returncode == 0 and result.stdout.strip().startswith("v22.") {
                return Path(found).resolve();
            }
        } except (OSError, subprocess.TimeoutExpired) {}
    }
    host = host_platform();
    artifact = NODE_ARTIFACTS.get(host);
    if artifact is None {
        raise RuntimeError(f"No native JavaScript toolchain for {host}");
    }
    archive = artifact.url.rsplit("/", 1)[1];
    top = archive.removesuffix(".tar.xz").removesuffix(".tar.gz").removesuffix(".zip");
    relative = top + ("/node.exe" if os.name == "nt" else "/bin/node");
    location = install(artifact, relative) / relative;
    subprocess.run(
        [str(location), "--version"], check=True, capture_output=True, timeout=15
    );
    return location;
}

def build_environment(base: dict[str, str]) -> dict[str, str] {
    node_path = native_node();
    result = dict(base);
    result["PATH"] = str(node_path.parent) + os.pathsep + result.get("PATH", "");
    result["NODE_BINARY"] = str(node_path);
    if offline() {
        result["EXPO_OFFLINE"] = "1";
    }
    return result;
}
