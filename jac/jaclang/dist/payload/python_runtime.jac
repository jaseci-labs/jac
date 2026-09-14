import importlib.util;
import json;
import subprocess;
import sys;
import sysconfig;

def current_identity -> dict[str, str] {
    return {
        "version": sys.version,
        "magic": importlib.util.MAGIC_NUMBER.hex(),
        "cache_tag": sys.implementation.cache_tag or "",
        "platform": sysconfig.get_platform(),
        "soabi": str(sysconfig.get_config_var("SOABI") or "")
    };
}

def interpreter_identity(python: str) -> dict[str, str] {
    probe = subprocess.run(
        [
            python,
            "-I",
            "-c",
            "import sys, sysconfig, json, importlib.util; print(json.dumps({"
            "'version': sys.version, 'magic': importlib.util.MAGIC_NUMBER.hex(), "
            "'cache_tag': sys.implementation.cache_tag or '', "
            "'platform': sysconfig.get_platform(), "
            "'soabi': str(sysconfig.get_config_var('SOABI') or '')}))"
        ],
        check=True,
        capture_output=True,
        text=True
    );
    return json.loads(probe.stdout);
}

def interpreter_build_identity(python: str) -> dict[str, str] {
    import os;
    import shlex;
    probe = subprocess.run(
        [
            python,
            "-I",
            "-c",
            "import json, sysconfig; print(json.dumps({"
            "key: str(sysconfig.get_config_var(key) or '') for key in "
            "('CC', 'CFLAGS', 'CCSHARED', 'LDSHARED', 'LDFLAGS', 'MACOSX_DEPLOYMENT_TARGET')}))"
        ],
        check=True,
        capture_output=True,
        text=True
    );
    config: dict[str, str] = json.loads(probe.stdout);
    compiler = shlex.split(os.environ.get("CC") or config.get("CC") or "cc");
    version = subprocess.run(
        compiler + ["--version"], check=True, capture_output=True, text=True
    );
    config["compiler_version"] = version.stdout + version.stderr;
    if sys.platform == "darwin" {
        sdk = subprocess.run(
            ["xcrun", "--show-sdk-version"], check=True, capture_output=True, text=True
        );
        config["sdk_version"] = sdk.stdout.strip();
    }
    for name in (
        "CC",
        "CFLAGS",
        "CPPFLAGS",
        "LDFLAGS",
        "ARCHFLAGS",
        "SDKROOT",
        "MACOSX_DEPLOYMENT_TARGET"
    ) {
        config["env:" + name] = os.environ.get(name, "");
    }
    return config;
}
