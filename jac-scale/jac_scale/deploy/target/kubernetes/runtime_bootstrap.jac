"""Shared in-pod runtime bootstrap for the no-Docker k8s path.

Both the monolith and the microservice targets ship local source into the
cluster (via the PvcInjector) and then install jac at pod startup on a generic
Python base image. This module owns the single, canonical INSTALL sequence -
apt base packages, Bun (for client/SPA builds), and the jac binary plus plugins
(or an experimental git-clone + zig-build of jaclang) - so the two targets share
one bootstrap instead of diverging. Each target appends its own RUN tail
(`jac start <file>` for a monolith; `jac build` + `jac start <svc>.jac` for a
service), since only the command to launch the app differs.

The commands assume a writable root filesystem and root-ish caps (apt/pip at
runtime); callers run them in a container built with `needs_root` semantics.
"""

import from jaclang.runtimelib.client { BUN_VERSION }
import from jac_scale.injector.bundle { JAC_ZIG_VERSION }
import from jac_scale.deploy.target.kubernetes.kubernetes_config { KubernetesConfig }


"""The canonical INSTALL command sequence (no app launch). apt base packages +
Bun + the jac binary and plugins, or - in experimental mode - a git clone and
`zig build` of the jaclang checkout. Returns a list of shell command strings to
join with ` && `; the caller appends the target-specific run tail. `experimental`
selects the git-clone + zig-build path over the released binary."""
def build_runtime_install_commands(
    k8s_config: KubernetesConfig, experimental: bool
) -> list[str] {
    config = k8s_config;
    commands: list[str] = [];

    # Base setup
    commands.append('export DEBIAN_FRONTEND=noninteractive');
    # Disable apt sandbox: CAP_SETUID/CAP_SETGID are dropped in the container
    # security context, so apt cannot drop privileges to the _apt user.
    commands.append(
        'echo \'APT::Sandbox::User "root";\' > /etc/apt/apt.conf.d/00sandbox'
    );
    # Remove repos that don't exist yet on Debian testing (trixie) to prevent
    # apt-get update from hanging/failing on missing Release files. Legacy
    # one-line format lives in *.list; modern python:3.x-slim images (Debian
    # trixie) use the deb822 *.sources format where the suites are combined on a
    # single `Suites:` line - the *.list-only sed misses it, so we also strip the
    # trixie-updates token from `Suites:` lines there.
    commands.append(
        'sed -i \'/trixie-updates\\|trixie-security/d\' /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null || true'
    );
    commands.append(
        'sed -i -E \'/^Suites:/ s/[[:space:]]+trixie-updates//g\' /etc/apt/sources.list.d/*.sources 2>/dev/null || true'
    );
    # Make apt-get update resilient: bounded retries + short network timeouts so
    # an unreachable suite fails fast instead of stalling the pod for minutes,
    # and `|| true` keeps a partial-but-usable index from aborting the build.
    commands.append(
        'apt-get -o Acquire::Retries=1 -o Acquire::http::Timeout=20 '
        '-o Acquire::https::Timeout=20 update || true'
    );

    # Install base packages (curl and unzip needed for Bun installation)
    base_packages = ['git', 'curl', 'unzip'];
    if config.additional_packages {
        base_packages.extend(config.additional_packages);
    }
    commands.append(f"apt-get install -y {' '.join(base_packages)}");

    # Install Bun (required for client framework frontend builds), pinned to the
    # same version jac auto-installs locally (BUN_VERSION is the single source of
    # truth in jaclang.runtimelib.client.bun_installer).
    commands.append(
        f'curl -fsSL https://bun.sh/install | bash -s "bun-v{BUN_VERSION}"'
    );
    commands.append('export BUN_INSTALL="$HOME/.bun"');
    commands.append('export PATH="$BUN_INSTALL/bin:$PATH"');

    if experimental {
        commands.append('rm -rf jaseci');
        # The pod has no SSH key/known_hosts, so a `git@host:owner/repo` or
        # `ssh://` URL makes the clone hang then fail. Normalize the common
        # GitHub SCP-style SSH form to anonymous HTTPS so the in-cluster clone
        # works for public repos without credentials.
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
        # jaclang ships as the self-contained `jac` binary, not a pip/editable
        # package, so the checkout is compiled with `zig build` to run the
        # branch's own jaclang (the point of experimental mode). The Zig version
        # comes from injector.bundle.JAC_ZIG_VERSION (single source of truth,
        # tracking jac/build.zig.zon's minimum_zig_version).
        #
        # Build deps on the bare python:3.x-slim base (it has neither a C++
        # toolchain nor the -dev libs the native LLVM shim links against):
        #   - xz-utils, zstd: build.zig's python-build-standalone payload step.
        #   - build-essential: build.zig compiles + links libjacllvm.so with the
        #     system `c++`/`ld` (jac/build.zig), absent from the slim image.
        #   - libzstd-dev, zlib1g-dev, libxml2-dev: the shim links `-lzstd -lz
        #     -lxml2`; without the -dev packages `zig build` dies at the C++ link
        #     step ("cannot find -lzstd") and the missing binary then surfaces
        #     downstream as a confusing `jac: command not found`.
        commands.append(
            'apt-get -o Acquire::Retries=1 -o Acquire::http::Timeout=20 '
            '-o Acquire::https::Timeout=20 update || true'
        );
        commands.append(
            'apt-get install -y --no-install-recommends xz-utils zstd '
            'build-essential libzstd-dev zlib1g-dev libxml2-dev'
        );
        # NB: `if/fi`, not `[ ... ] && ZARCH=...`. The commands list is joined
        # with ` && `, so a bare test that is false on x86_64 ("$ZARCH" != arm64)
        # short-circuits the ENTIRE rest of the chain - the zig download, `zig
        # build`, and PATH export all silently skip, and the run falls through to
        # `jac install` with no binary ("jac: command not found"). An if-stmt
        # always exits 0, so the chain survives on every arch.
        commands.append(
            'ZARCH="$(uname -m)"; if [ "$ZARCH" = "arm64" ]; then ZARCH="aarch64"; fi'
        );
        commands.append(f'ZDIR="zig-${{ZARCH}}-linux-{JAC_ZIG_VERSION}"');
        commands.append(
            f'curl -fsSL "https://ziglang.org/download/{JAC_ZIG_VERSION}/${{ZDIR}}.tar.xz" '
            '| tar -xJ -C /tmp'
        );
        commands.append('export PATH="/tmp/${ZDIR}:$PATH"');
        # `fetch-llvm` is a prerequisite, not a default build dep: it range-fetches
        # the pinned LLVM slice and compiles the LLVMPY_* shim that `zig build`
        # statically links. Without it the build fails late at the payload step
        # ("mkpayload: no LLVM shim ... Run `zig build fetch-llvm` once"). Matches
        # scripts/fresh_env.sh, which runs fetch-llvm before the build.
        commands.append('( cd jac && zig build fetch-llvm && zig build )');
        commands.append('export PATH="$PWD/jac/zig-out/bin:$PATH"');
        # --global: plugins go into the binary's own site so `jac start` finds
        # them after `cd ..` (a bare `jac install` would target a per-project
        # .jac/venv that isn't on PATH at run time).
        commands.append('jac install -e ./jac-scale --extras all --global');
        # byllm/mcp are optional: a core-only fork branch may not ship them, so
        # skip-when-absent rather than failing the bootstrap.
        commands.append('[ ! -d ./jac-byllm ] || jac install -e ./jac-byllm --global');
        commands.append('[ ! -d ./jac-mcp ] || jac install -e ./jac-mcp --global');
        commands.append('cd ..');
    } else {
        packages = config.plugin_versions or {};
        jaclang_v = packages.get('jaclang', 'latest');
        scale_v = packages.get('jac_scale', 'latest');
        byllm_v = packages.get('jac_byllm', 'latest');
        mcp_v = packages.get('jac_mcp', 'latest');
        # jaclang ships as the self-contained `jac` binary (not on PyPI); the
        # official installer fetches it from GitHub Releases onto PATH.
        # `--version` pins to a specific jaseci release; omit it for latest.
        install_jac = (
            'curl -fsSL https://raw.githubusercontent.com/jaseci-labs/'
            'jaseci/main/scripts/install.sh | bash'
        );
        if jaclang_v != 'latest' {
            install_jac += f" -s -- --version {jaclang_v}";
        }
        commands.append(install_jac);
        commands.append('export PATH="$HOME/.local/bin:$PATH"');
        # Fail loud + actionable if `jac` did not land. install.sh delegates the
        # `latest` lookup to GitHub Releases; when that cannot resolve (e.g. a new
        # tag scheme) or `curl | bash` silently no-ops on a fetch error, the next
        # `jac` call would otherwise die as a bare 127 deep in the pod and the
        # deploy would only report "fleet did not become ready". Surface the real
        # cause and the fix in the pod log instead of crash-looping blind.
        commands.append(
            f'if ! command -v jac >/dev/null 2>&1; then '
            f'echo "[jac-scale] FATAL: jac was not installed (requested '
            f'jaclang={jaclang_v}). The GitHub release lookup did not resolve. '
            f'Pin [plugins.scale.kubernetes].plugin_versions.jaclang to a '
            f'published release, or deploy with --experimental to build jac from '
            f'source in-pod." >&2; exit 1; fi'
        );
        # Plugins install --global (into the binary's own site, honoring any pins
        # in config.plugin_versions) so `jac start` finds them: these run before
        # `cd {app_mount_path}`, so a bare `jac install` would have no project
        # venv to target. Extras ride in the spec as PEP 508 brackets
        # (`jac-scale[all]`) because `--extras` is dropped for named packages.
        # jac-scale[all] is always needed; byllm/mcp are opt-out via 'none'.
        if scale_v == 'latest' {
            commands.append("jac install 'jac-scale[all]' --global");
        } else {
            commands.append(f"jac install 'jac-scale[all]=={scale_v}' --global");
        }
        if byllm_v and byllm_v != 'none' {
            if byllm_v == 'latest' {
                commands.append('jac install byllm --global');
            } else {
                commands.append(f'jac install byllm=={byllm_v} --global');
            }
        }
        if mcp_v and mcp_v != 'none' {
            if mcp_v == 'latest' {
                commands.append('jac install jac-mcp --global');
            } else {
                commands.append(f'jac install jac-mcp=={mcp_v} --global');
            }
        }
    }
    return commands;
}
