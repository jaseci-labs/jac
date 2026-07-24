import logging;
import os;
import re;
import from pathlib { Path }

glob logger = logging.getLogger(__name__);

glob BINARY_PATH_ENV: str = "JAC_SCALE_BINARY_PATH",
     VERSION_ENV: str = "JAC_SCALE_VERSION",
     PIN_SECTION: str = "scale-runtime";

glob _PIN_RE = re.compile(r"^\d+\.\d+\.\d+([-.+][0-9A-Za-z.\-+]*)?$");


enum Channel {
    STABLE = "stable",
    DEV = "dev",
    LOCAL = "local",
    EXPERIMENTAL = "experimental"
}


def peek_pin(project_dir: str) -> tuple[str, str] {
    raw = os.environ.get(VERSION_ENV, "").strip();
    if raw {
        return (raw, VERSION_ENV);
    }
    try {
        import from jaclang.project.config { get_config_for_path }
        config = get_config_for_path(Path(project_dir));
    } except Exception {
        return ("", "");
    }
    if config is None {
        return ("", "");
    }
    section = config.get_section(PIN_SECTION);
    if section is None {
        return ("", "");
    }
    raw = str(section.get("version", "")).strip();
    if raw {
        return (raw, f"[{PIN_SECTION}] version");
    }
    return ("", "");
}


def _runner_release_version -> tuple[int, int] | None {
    try {
        import from jaclang.cli.cli { jac_version }
        parts = str(jac_version()).split(".");
        return (int(parts[0]), int(parts[1]));
    } except Exception {
        return None;
    }
}


def _check_pin_window(version: str, source: str) {
    current = _runner_release_version();
    if current is None {
        return;
    }
    (cur_major, cur_minor) = current;
    floor_minor = max(cur_minor - 1, 0);
    parts = version.split(".");
    pin = (int(parts[0]), int(parts[1]));
    if pin < (cur_major, floor_minor) {
        raise RuntimeError(
            f"{source} pins jac {version}, which is outside the supported "
            f"window (this jac is {cur_major}.{cur_minor}.x; supported pins "
            f"are {cur_major}.{floor_minor}.* and newer). Older releases "
            "predate the current app-sealing flow; to ship one anyway, "
            f"download its binary and set {BINARY_PATH_ENV}."
        );
    }
}


def resolve_pinned_version(project_dir: str) -> str {
    (raw, source) = peek_pin(project_dir);
    if not raw {
        return "";
    }
    version = raw;
    if version[0] in ("v", "V") {
        version = version[1:];
    }
    if _PIN_RE.match(version) is None {
        raise RuntimeError(
            f"{source} = {raw!r} is not a release version; expected something "
            "like 0.34.2 (an optional leading 'v' is accepted)."
        );
    }
    _check_pin_window(version, source);
    return version;
}


def resolve_dev_channel(project_dir: str) -> Channel {
    (pin, source) = peek_pin(project_dir);
    if os.environ.get(BINARY_PATH_ENV, "") {
        if pin {
            logger.warning(
                f"{BINARY_PATH_ENV} is set, so the local binary ships and "
                f"the {source} pin is ignored."
            );
        }
        return Channel.LOCAL;
    }
    import from jaclang.project.config { get_config_for_path }
    config = get_config_for_path(Path(project_dir));
    if pin {
        if config is not None and config.get_section("experimental") is not None {
            if source == VERSION_ENV {
                logger.warning(
                    f"{VERSION_ENV}={pin} overrides the [experimental] stanza "
                    "for this deploy."
                );
            } else {
                raise RuntimeError(
                    f"jac.toml declares both [{PIN_SECTION}] version = {pin!r} "
                    "and [experimental]; remove one of the two stanzas."
                );
            }
        }
        return Channel.STABLE;
    }
    if config is None {
        return Channel.STABLE;
    }
    if config.get_section("experimental") is not None {
        return Channel.EXPERIMENTAL;
    }
    if config.get_section("dev") is None {
        return Channel.STABLE;
    }
    return Channel.DEV;
}


def resolve_experimental_pr(project_dir: str) -> str {
    import from jaclang.project.config { get_config_for_path }
    config = get_config_for_path(Path(project_dir));
    if config is None {
        return "";
    }
    section = config.get_section("experimental");
    if section is None {
        return "";
    }
    return str(section.get("pr", "")).strip();
}
