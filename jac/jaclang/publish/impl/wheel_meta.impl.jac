"""Implementation of WHEEL file and entry_points.txt generators."""

import from jaclang.project.config { JacConfig }
import from jaclang.publish.metadata { normalize_package_name }

glob _JAC_VERSION: str = "";


import jaclang as _jac_mod;


def _pkg_norm_name(config: JacConfig) -> str {
    return normalize_package_name(config.package.name).replace("-", "_");
}

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
    ver = generator_version or _JAC_VERSION;
    generator_str = f"jac ({ver})" if ver else "jac";
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
    return f"{_pkg_norm_name(config)}-{config.package.version}-{python_tag}-{abi_tag}-{platform_tag}.whl";
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
    return f"{_pkg_norm_name(config)}-{config.package.version}.dist-info";
}
