import os;
import shutil;
import socket;
import unittest;
import from importlib.util { find_spec }
import from jaclang.testing.test_runner { STRICT_ENV, strict_mode }


def _unmet(kind: str, name: str, hint: str) {
    detail = f"missing {kind} '{name}'";
    if hint {
        detail += f" ({hint})";
    }
    if strict_mode() {
        raise AssertionError(f"{detail}; {STRICT_ENV} is set, so this is a failure");
    }
    raise unittest.SkipTest(detail);
}


def require_module(*names: str) {
    for name in names {
        found = False;
        try {
            found = find_spec(name) is not None;
        } except (ImportError, ValueError) {
            found = False;
        }
        if not found {
            _unmet("optional dependency", name, "install it to run this test");
        }
    }
}


def require_tool(*names: str) {
    for name in names {
        if not shutil.which(name) {
            _unmet("tool", name, "install it on PATH to run this test");
        }
    }
}


def require_flag(env_name: str, reason: str = "") {
    if os.environ.get(env_name, "").strip().lower()
        in ("", "0", "false", "no", "off") {
        detail = reason or "this test needs an environment only that flag provides";
        raise unittest.SkipTest(f"set {env_name}=1 to run: {detail}");
    }
}


def require_network(host: str = "pypi.org", port: int = 443) {
    try {
        socket.create_connection((host, port), timeout=5).close();
    } except OSError {
        _unmet("network reachability", f"{host}:{port}", "this test downloads from it");
    }
}
