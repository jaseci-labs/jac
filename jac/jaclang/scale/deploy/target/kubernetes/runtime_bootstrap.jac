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


def build_runtime_install_commands(
    k8s_config: KubernetesConfig,
    overlay_source: bool = False,
    precompiled: bool = False
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

    # A self-contained `jac` binary was downloaded and shipped over the PVC.
    # Install it on PATH and run - no clone, no build (host or in-pod), no plugin
    # install: scale and the MCP server are built into the binary. The app's
    # runtime capability closure is materialized by the app-level `jac install`.
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
        # DEV channel: a jaclang source tree was shipped alongside the binary.
        # Point the pod's editable dev loop at it so `import jaclang` reroutes to
        # the overlaid source. The host [dev] stanza was stripped from the shipped
        # jac.toml, so this is the only [dev] table in the pod.
        overlay_rel = overlay_pod_path();
        commands.append(
            f"printf '\\n[dev]\\njaclang_source = \"{overlay_rel}\"\\n' "
            f'>> {APP_MOUNT_PATH}/jac.toml'
        );
        if precompiled {
            # Use the host-built `_precompiled` jir (OPTION A); without this the
            # dev loop defaults JAC_NO_PRECOMPILE=1 and compiles on first import.
            commands.append('export JAC_NO_PRECOMPILE=0');
        }
    }
    return commands;
}


def runtime_path -> str {
    return f"{JAC_HOME}/.local/bin:{JAC_HOME}/.bun/bin:/usr/local/bin:/usr/bin:/bin";
}


def runtime_container_env(precompiled: bool = False) -> list[dict[str, str]] {
    env: list[dict[str, str]] = [
        {"name": "HOME", "value": JAC_HOME},
        {"name": "PATH", "value": runtime_path()}
    ];
    if precompiled {
        # Let the runtime container load the shipped `_precompiled` jir instead of
        # the dev loop's default JAC_NO_PRECOMPILE=1 (compile-on-boot).
        env.append({"name": "JAC_NO_PRECOMPILE", "value": "0"});
    }
    return env;
}


def build_bootstrap_init_container(
    k8s_config: KubernetesConfig,
    base_image: str,
    overlay_source: bool = False,
    precompiled: bool = False
) -> dict[str, any] {
    commands = build_runtime_install_commands(k8s_config, overlay_source, precompiled);
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
