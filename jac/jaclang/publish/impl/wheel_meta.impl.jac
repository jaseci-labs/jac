"""Implementation of WHEEL file and entry_points.txt generators."""

import from jaclang.project.config { JacConfig }
import from jaclang.publish.metadata { normalize_package_name }

import from importlib.metadata { version as _pkg_version }
glob _JAC_VERSION: str = _pkg_version("jaclang");

def _pkg_norm_name(config: JacConfig) -> str {
    return normalize_package_name(config.package.name).replace("-", "_");
}

impl generate_wheel_file(
    generator_version: str = _JAC_VERSION,
    pure_python: bool = True,
    python_tag: str = "py3",
    abi_tag: str = "none",
    platform_tag: str = "any",
) -> str {
    generator_str = f"jac ({generator_version})" if generator_version else "jac";
    lines = [
        "Wheel-Version: 1.0",
        f"Generator: {generator_str}",
        f"Root-Is-Purelib: {str(pure_python).lower()}",
        f"Tag: {python_tag}-{abi_tag}-{platform_tag}",
        "",

    ];
    return "\n".join(lines);
}

impl generate_entry_points(config: JacConfig) -> str {
    if not config.entrypoints {
        return "";
    }

    sections: list[str] = [];

    for (group, refs) in sorted(config.entrypoints.items()) {
        if not refs {
            continue;
        }
        # 'scripts' → 'console_scripts' (pip convention for CLI entry points)
        section_name = "console_scripts" if group == "scripts" else group;
        entry_lines: list[str] = [f"[{section_name}]"];
        for (ep_name, ref) in sorted(refs.items()) {
            entry_lines.append(f"{ep_name} = {ref}");
        }
        sections.append("\n".join(entry_lines));
    }

    return ("\n\n".join(sections) + "\n") if sections else "";
}

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

impl dist_info_dirname(config: JacConfig) -> str {
    if config.package is None {
        raise ValueError(
            "Cannot build dist-info name: [package] section is missing in jac.toml"
        );
    }
    return f"{_pkg_norm_name(config)}-{config.package.version}.dist-info";
}
