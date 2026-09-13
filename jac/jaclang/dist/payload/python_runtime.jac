"""Interpreter compatibility shared by Python payload producers."""

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
