"""Implementation of WHEEL file and entry_points.txt generators."""

import from jaclang.project.config { JacConfig }
import from jaclang.publish.metadata { normalize_package_name }

# ===============================================================================
# generate_wheel_file
# ===============================================================================
impl generate_wheel_file(
    generator_version: str = "",
    pure_python: bool = True,
    python_tag: str = "py3",
    abi_tag: str = "none",
    platform_tag: str = "any",
) -> str {
    # Try to get the installed jaclang version for the generator tag
    if not generator_version {
        try {
            import jaclang;
            generator_version = getattr(jaclang, "__version__", "");
        } except Exception {
            generator_version = "";
        }
    }

    generator_str = f"jac ({generator_version})" if generator_version else "jac";
    purelib_str = "true" if pure_python else "false";
    tag_str = f"{python_tag}-{abi_tag}-{platform_tag}";

    lines = [
        "Wheel-Version: 1.0",
        f"Generator: {generator_str}",
        f"Root-Is-Purelib: {purelib_str}",
        f"Tag: {tag_str}",
        "",

    ];
    return "\n".join(lines);
}

# ===============================================================================
# generate_entry_points
# ===============================================================================
impl generate_entry_points(config: JacConfig) -> str {
    if not config.entrypoints {
        return "";
    }

    sections: list[str] = [];

    for (group, refs) in config.entrypoints.items() {
        if not refs {
            continue;
        }
        # 'scripts' → 'console_scripts' (pip convention for CLI entry points)
        section_name = "console_scripts" if group == "scripts" else group;
        entry_lines: list[str] = [f"[{section_name}]"];
        for (ep_name, ref) in refs.items() {
            entry_lines.append(f"{ep_name} = {ref}");
        }
        sections.append("\n".join(entry_lines));
    }

    if sections {
        return "\n\n".join(sections) + "\n";
    }
    return "";
}

# ===============================================================================
# parse_entry_points
# ===============================================================================
impl parse_entry_points(text: str) -> dict[str, dict[str, str]] {
    result: dict[str, dict[str, str]] = {};
    current_group: str | None = None;

    for line in text.splitlines() {
        line = line.strip();
        if not line or line.startswith("#") {
            continue;
        }
        if line.startswith("[") and line.endswith("]") {
            current_group = line[1:-1];
            result[current_group] = {};
        } elif "=" in line and current_group is not None {
            (ep_name, _, ref) = line.partition("=");
            result[current_group][ep_name.strip()] = ref.strip();
        }
    }

    return result;
}

# ===============================================================================
# wheel_filename
# ===============================================================================
impl wheel_filename(
    config: JacConfig,
    python_tag: str = "py3",
    abi_tag: str = "none",
    platform_tag: str = "any",
) -> str {
    if config.package is None {
        raise ValueError(
            "Cannot build wheel filename: [package] section is missing in jac.toml"
        );
    }
    # PEP 427: hyphens in the name become underscores in the filename
    name = normalize_package_name(config.package.name).replace("-", "_");
    version = config.package.version;
    return f"{name}-{version}-{python_tag}-{abi_tag}-{platform_tag}.whl";
}

# ===============================================================================
# dist_info_dirname
# ===============================================================================
impl dist_info_dirname(config: JacConfig) -> str {
    if config.package is None {
        raise ValueError(
            "Cannot build dist-info name: [package] section is missing in jac.toml"
        );
    }
    name = normalize_package_name(config.package.name).replace("-", "_");
    return f"{name}-{config.package.version}.dist-info";
}
