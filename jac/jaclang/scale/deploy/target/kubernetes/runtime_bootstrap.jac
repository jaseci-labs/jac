import from jaclang.runtimelib.client { BUN_VERSION }
import from jaclang.scale.injector.bundle {
    JAC_HOME,
    APP_VOLUME_NAME,
    APP_MOUNT_PATH,
    TOOLCHAIN_SUBDIR
}
import from jaclang.scale.injector.binary { overlay_pod_path }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}


def build_service_apt_prefix(k8s_config: KubernetesConfig) -> str {
    # apt install for the service container (not the discarded init layer).
    packages = k8s_config.service_dependencies;
    if not packages {
        return "";
    }
    import re;
    valid = re.compile(r"^[a-z0-9][a-z0-9.+\-]*$");
    for pkg in packages {
        if not valid.match(pkg) {
            raise ValueError(
                f"[dependencies.system] package name {pkg!r} is not a valid "
                "Debian package name (allowed characters: a-z 0-9 . + -)."
            );
        }
    }
    pkg_list = ' '.join(sorted(set(packages)));
    # Trailing ` && ` (not `;`) chains the install into the app-start command so
    # a failed apt aborts the container boot instead of starting without the deps.
    return (
        "export DEBIAN_FRONTEND=noninteractive && "
        "apt-get update && apt-get install -y --no-install-recommends "
        f"{pkg_list} && "
    );
}


def build_runtime_install_commands(
    k8s_config: KubernetesConfig, overlay_source: bool = False
) -> list[str] {
    config = k8s_config;
    commands: list[str] = [];

    commands.append(f'export HOME={JAC_HOME}');
    commands.append(f'mkdir -p {JAC_HOME}/.local/bin');

    commands.append('export DEBIAN_FRONTEND=noninteractive');

    commands.append(
        'echo \'APT::Sandbox::User "root";\' > /etc/apt/apt.conf.d/00sandbox'
    );

    commands.append(
        'sed -i \'/trixie-updates\\|trixie-security/d\' /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null || true'
    );
    commands.append(
        'sed -i -E \'/^Suites:/ s/[[:space:]]+trixie-updates//g\' /etc/apt/sources.list.d/*.sources 2>/dev/null || true'
    );

    commands.append(
        'apt-get -o Acquire::Retries=1 -o Acquire::http::Timeout=20 '
        '-o Acquire::https::Timeout=20 update || true'
    );

    base_packages = ['git', 'curl', 'unzip'];
    if config.additional_packages {
        base_packages.extend(config.additional_packages);
    }
    commands.append(f"apt-get install -y {' '.join(base_packages)}");

    commands.append(
        f'curl -fsSL https://bun.sh/install | bash -s "bun-v{BUN_VERSION}"'
    );
    commands.append('export BUN_INSTALL="$HOME/.bun"');
    commands.append('export PATH="$BUN_INSTALL/bin:$PATH"');

    tc = f"{APP_MOUNT_PATH}/{TOOLCHAIN_SUBDIR}";
    commands.append(f'install -m 0755 "{tc}/bin/jac" "$HOME/.local/bin/jac"');
    commands.append('export PATH="$HOME/.local/bin:$PATH"');
    commands.append(
        'if ! command -v jac >/dev/null 2>&1; then echo "[jac-scale] FATAL: '
        'shipped jac binary did not run (toolchain unpack failed, or the '
        'binary arch does not match the node - set JAC_NODE_ARCH and '
        'redeploy)." >&2; exit 1; fi'
    );

    if overlay_source {
        overlay_rel = overlay_pod_path();
        commands.append(
            f"grep -q '^\\[dev\\]' {APP_MOUNT_PATH}/jac.toml || "
            f"printf '\\n[dev]\\njaclang_source = \"{overlay_rel}\"\\n' "
            f'>> {APP_MOUNT_PATH}/jac.toml'
        );
    }
    return commands;
}


def runtime_path -> str {
    return f"{JAC_HOME}/.local/bin:{JAC_HOME}/.bun/bin:/usr/local/bin:/usr/bin:/bin";
}


def runtime_container_env -> list[dict[str, str]] {
    return [
        {"name": "HOME", "value": JAC_HOME},
        {"name": "PATH", "value": runtime_path()}
    ];
}


def build_bootstrap_init_container(
    k8s_config: KubernetesConfig, base_image: str, overlay_source: bool = False
) -> dict[str, any] {
    commands = build_runtime_install_commands(k8s_config, overlay_source);
    commands.append(f'cd {APP_MOUNT_PATH}');
    commands.append('jac install');
    script = ' && '.join(commands);
    return {
        "name": "jac-bootstrap",
        "image": base_image,
        "command": ["bash", "-c"],
        "args": [script],
        "securityContext": {
            "readOnlyRootFilesystem": False,
            "allowPrivilegeEscalation": False,
            "capabilities": {
                "drop": ["ALL"],
                "add": ["CHOWN", "DAC_OVERRIDE", "FOWNER", "FSETID", "SETUID", "SETGID"]
            },
            "seccompProfile": {"type": "RuntimeDefault"}
        },
        "volumeMounts": [{"name": APP_VOLUME_NAME, "mountPath": APP_MOUNT_PATH}]
    };
}
