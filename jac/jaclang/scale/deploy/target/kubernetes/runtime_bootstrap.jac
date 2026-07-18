import from jaclang.scale.injector.bundle {
    JAC_HOME,
    APP_VOLUME_NAME,
    APP_MOUNT_PATH,
    TOOLCHAIN_SUBDIR
}
import from jaclang.scale.injector.pvc_injector {
    BUNDLE_VOLUME_NAME,
    BUNDLE_MOUNT_PATH
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}


def build_service_apt_prefix(k8s_config: KubernetesConfig) -> str {
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

    return (
        "export DEBIAN_FRONTEND=noninteractive && "
        "apt-get update && apt-get install -y --no-install-recommends "
        f"{pkg_list} && "
    );
}


def build_runtime_install_commands(
    k8s_config: KubernetesConfig, prefer_image_binary: bool = False
) -> list[str] {
    config = k8s_config;
    commands: list[str] = [];

    commands.append(f'export HOME={JAC_HOME}');
    commands.append(f'mkdir -p {JAC_HOME}/.local/bin');

    commands.append('export DEBIAN_FRONTEND=noninteractive');

    if config.additional_packages {
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
        commands.append(f"apt-get install -y {' '.join(config.additional_packages)}");
    }

    tc = f"{APP_MOUNT_PATH}/{TOOLCHAIN_SUBDIR}";
    if prefer_image_binary {
        commands.append(
            'if [ -x /usr/local/bin/jac ]; '
            'then ln -sf /usr/local/bin/jac "$HOME/.local/bin/jac"; '
            f'else install -m 0755 "{tc}/bin/jac" "$HOME/.local/bin/jac"; fi'
        );
    } else {
        commands.append(
            'if [ -x /usr/local/bin/jac ] && [ "$(sha256sum /usr/local/bin/jac '
            f"| cut -d' ' -f1)\" = \"$(sha256sum \"{tc}/bin/jac\" | cut -d' ' -f1)\" ]; "
            'then ln -sf /usr/local/bin/jac "$HOME/.local/bin/jac"; '
            f'else install -m 0755 "{tc}/bin/jac" "$HOME/.local/bin/jac"; fi'
        );
    }
    commands.append('export PATH="$HOME/.local/bin:$PATH"');
    commands.append(
        'if ! command -v jac >/dev/null 2>&1; then echo "[jac-scale] FATAL: '
        'shipped jac binary did not run (toolchain unpack failed, or the '
        'binary arch does not match the node - set JAC_NODE_ARCH and '
        'redeploy)." >&2; exit 1; fi'
    );

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
    k8s_config: KubernetesConfig, base_image: str, is_gateway: bool = True
) -> dict[str, any] {
    import from jaclang.scale.injector.binary { OFFICIAL_IMAGE }
    prefer_image_binary = base_image.startswith(f"{OFFICIAL_IMAGE}:experimental-");
    commands = build_runtime_install_commands(k8s_config, prefer_image_binary);
    commands.append(f'cd {APP_MOUNT_PATH}');

    cache = f"{BUNDLE_MOUNT_PATH}/.cache";
    commands.append(
        f'if mkdir -p {cache}/pip 2>/dev/null; then '
        f'if [ "$(du -sm {cache} 2>/dev/null | cut -f1)" -gt 512 ] 2>/dev/null; then '
        f'rm -rf {cache}/pip && mkdir -p {cache}/pip; fi; '
        f'export PIP_CACHE_DIR={cache}/pip; '
        f'fi'
    );

    commands.append(f'export PIP_PREFIX="{APP_MOUNT_PATH}/.jac/venv"');

    if not is_gateway {
        commands.append("export JAC_CLIENT_SKIP_NPM_INSTALL=1");
    } else {
        commands.append(
            'if [ -f .jac/client/dist/index.html ]; then echo "[jac-scale] '
            'prebuilt client dist found; skipping the npm closure"; '
            "export JAC_CLIENT_SKIP_NPM_INSTALL=1; else echo \"[jac-scale] no "
            'prebuilt client dist; full install"; fi'
        );
    }
    commands.append("jac install");
    script = ' && '.join(commands);
    container: dict[str, any] = {
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
        "volumeMounts": [
            {"name": APP_VOLUME_NAME, "mountPath": APP_MOUNT_PATH},
            {"name": BUNDLE_VOLUME_NAME, "mountPath": BUNDLE_MOUNT_PATH}
        ]
    };
    policy = image_pull_policy(base_image);
    if policy {
        container["imagePullPolicy"] = policy;
    }
    return container;
}


def image_pull_policy(image: str) -> str {
    import from jaclang.scale.injector.binary { OFFICIAL_IMAGE }
    return "Always"
        if image.endswith(":dev") or image.startswith(f"{OFFICIAL_IMAGE}:experimental-")
        else "";
}
