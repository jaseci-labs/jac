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


def build_runtime_install_commands(k8s_config: KubernetesConfig) -> list[str] {
    config = k8s_config;
    commands: list[str] = [];

    commands.append(f'export HOME={JAC_HOME}');
    commands.append(f'mkdir -p {JAC_HOME}/.local/bin');

    commands.append('export DEBIAN_FRONTEND=noninteractive');

    # apt only for declared packages: the binary bundles bun+python and the bundle ships as a tar, so the default boot needs nothing from apt.
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
    # On the official base image /usr/local/bin/jac ships with its runtime
    # pre-extracted; reuse it ONLY when it is byte-identical to the shipped
    # binary (the .jab seal is version-locked), else install the bundle copy.
    commands.append(
        f'if [ -x /usr/local/bin/jac ] && [ "$(sha256sum /usr/local/bin/jac '
        f"| cut -d' ' -f1)\" = \"$(sha256sum \"{tc}/bin/jac\" | cut -d' ' -f1)\" ]; "
        f'then ln -sf /usr/local/bin/jac "$HOME/.local/bin/jac"; '
        f'else install -m 0755 "{tc}/bin/jac" "$HOME/.local/bin/jac"; fi'
    );
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
    commands = build_runtime_install_commands(k8s_config);
    commands.append(f'cd {APP_MOUNT_PATH}');
    # Point the pip cache at the shared RWX bundle PVC: the first pod warms it,
    # every later pod (and every redeploy) downloads ~nothing. pip only - bun's
    # cache is thousands of tiny files, pathological on EFS/NFS; it stays on
    # the pod-local disk. Best-effort: an unwritable PVC skips the export.
    cache = f"{BUNDLE_MOUNT_PATH}/.cache";
    commands.append(
        f'if mkdir -p {cache}/pip 2>/dev/null; then '
        # Bound the cache so it cannot squeeze the bundles off the shared PVC
        # (default size 1Gi): past ~512MB it is wiped and rewarmed by this boot.
        f'if [ "$(du -sm {cache} 2>/dev/null | cut -f1)" -gt 512 ] 2>/dev/null; then '
        f'rm -rf {cache}/pip && mkdir -p {cache}/pip; fi; '
        f'export PIP_CACHE_DIR={cache}/pip; '
        f'fi'
    );
    # The toolchain bundle ships the prebuilt jac binary and the app bundle
    # ships source precompiled into .jir; first boot only needs to install the
    # app's declared deps. PIP_PREFIX puts them in the project venv on the
    # shared volume (the CLI wires it onto sys.path at boot): pip's default
    # target is the runtime site, which on the official base image is a
    # container-local layer, so installs there never reach the main container.
    commands.append(f'export PIP_PREFIX="{APP_MOUNT_PATH}/.jac/venv"');
    # npm deps exist only to BUILD the client; JAC_CLIENT_SKIP_NPM_INSTALL
    # (the `jac create --skip` knob) skips the whole closure, including the
    # client machinery's base install that a jac.toml table-strip misses on
    # client-kind projects. Service pods never build; the gateway only builds
    # when the bundle ships no prebuilt dist.
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
    # The rolling `dev` tag is mutable: without Always a node keeps serving
    # whatever it cached first. Versioned and `latest` tags keep k8s defaults.
    return "Always" if image.endswith(":dev") else "";
}
