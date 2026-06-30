import from jaclang.runtimelib.client { BUN_VERSION }
import from jaclang.scale.injector.bundle {
    JAC_ZIG_VERSION,
    JAC_HOME,
    APP_VOLUME_NAME,
    APP_MOUNT_PATH,
    TOOLCHAIN_SUBDIR
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}


def build_runtime_install_commands(
    k8s_config: KubernetesConfig, experimental: bool, ship_binary: bool = False
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

    if ship_binary {
        tc = f"{APP_MOUNT_PATH}/{TOOLCHAIN_SUBDIR}";
        commands.append(f'install -m 0755 "{tc}/bin/jac" "$HOME/.local/bin/jac"');
        commands.append('export PATH="$HOME/.local/bin:$PATH"');

        commands.append(
            'if ! command -v jac >/dev/null 2>&1; then echo "[jac-scale] FATAL: '
            'shipped jac binary did not run (toolchain unpack failed or the host '
            'binary arch does not match the node). Deploy with --experimental to '
            'build jac in-pod instead." >&2; exit 1; fi'
        );

        # scale is built into the shipped jac binary (jaclang.scale); no separate
        # install. The app's runtime capability closure is materialized by the
        # app-level `jac install`. byllm is optional; the MCP server is likewise
        # built into the jac binary now.
        commands.append(
            f'[ ! -d "{tc}/jac-byllm" ] || jac install -e "{tc}/jac-byllm" --global'
        );
    } elif experimental {
        commands.append('cd "$HOME"');
        commands.append('rm -rf jaseci');
        repo_url = config.jaseci_repo_url;
        if repo_url.startswith('git@') and ':' in repo_url {
            host_path = repo_url[4:];
            host = host_path.split(':', 1)[0];
            path = host_path.split(':', 1)[1];
            repo_url = f"https://{host}/{path}";
        } elif repo_url.startswith('ssh://git@') {
            repo_url = 'https://' + repo_url[len('ssh://git@'):];
        }
        clone_cmd = f"git clone --branch {config.jaseci_branch} --single-branch {repo_url}";
        commands.append(clone_cmd);
        commands.append('cd ./jaseci');
        if config.jaseci_commit {
            commands.append(f"git checkout {config.jaseci_commit}");
        }
        commands.append('git submodule update --init --recursive');
        commands.append(
            'apt-get -o Acquire::Retries=1 -o Acquire::http::Timeout=20 '
            '-o Acquire::https::Timeout=20 update || true'
        );
        commands.append(
            'apt-get install -y --no-install-recommends xz-utils zstd '
            'build-essential libzstd-dev zlib1g-dev libxml2-dev'
        );
        commands.append(
            'ZARCH="$(uname -m)"; if [ "$ZARCH" = "arm64" ]; then ZARCH="aarch64"; fi'
        );
        commands.append(f'ZDIR="zig-${{ZARCH}}-linux-{JAC_ZIG_VERSION}"');
        commands.append(
            f'curl -fsSL "https://ziglang.org/download/{JAC_ZIG_VERSION}/${{ZDIR}}.tar.xz" '
            '| tar -xJ -C /tmp'
        );
        commands.append('export PATH="/tmp/${ZDIR}:$PATH"');
        commands.append('( cd jac && zig build fetch-llvm && zig build )');
        commands.append('export PATH="$PWD/jac/zig-out/bin:$PATH"');
        # scale is built into jaclang now (jaclang.scale); no separate install.
        # The app's runtime capability closure (serve + configured backends) is
        # materialized by `jac install` in the app dir below.
        commands.append('[ ! -d ./jac-byllm ] || jac install -e ./jac-byllm --global');
        commands.append('cd ..');
        commands.append(
            'ln -sf "$HOME/jaseci/jac/zig-out/bin/jac" "$HOME/.local/bin/jac"'
        );
    } else {
        packages = config.plugin_versions or {};
        jaclang_v = packages.get('jaclang', 'latest');
        byllm_v = packages.get('jac_byllm', 'latest');
        install_jac = (
            'curl -fsSL https://raw.githubusercontent.com/jaseci-labs/'
            'jaseci/main/scripts/install.sh | bash'
        );
        if jaclang_v != 'latest' {
            install_jac += f" -s -- --version {jaclang_v}";
        }
        commands.append(install_jac);
        commands.append('export PATH="$HOME/.local/bin:$PATH"');
        commands.append(
            f'if ! command -v jac >/dev/null 2>&1; then '
            f'echo "[jac-scale] FATAL: jac was not installed (requested '
            f'jaclang={jaclang_v}). The GitHub release lookup did not resolve. '
            f'Pin [plugins.scale.kubernetes].plugin_versions.jaclang to a '
            f'published release, or deploy with --experimental to build jac from '
            f'source in-pod." >&2; exit 1; fi'
        );
        # scale ships inside jaclang now; the pod's runtime capability closure
        # (serve + configured backends, never deploy.k8s) is materialized by the
        # app-level `jac install` into the app .jac/venv, not a global package.
        if byllm_v and byllm_v != 'none' {
            if byllm_v == 'latest' {
                commands.append('jac install byllm --global');
            } else {
                commands.append(f'jac install byllm=={byllm_v} --global');
            }
        }
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
    k8s_config: KubernetesConfig,
    experimental: bool,
    base_image: str,
    ship_binary: bool = False
) -> dict[str, any] {
    commands = build_runtime_install_commands(k8s_config, experimental, ship_binary);
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
