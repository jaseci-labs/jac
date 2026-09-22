import re;
import sys;

import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.jac0core.sealed { python_tag }
import from jaclang.project.config { JacConfig }
import from jaclang.project.providers { get_python_provider, resolve_plan }
import from jaclang.runtime.graph_utils { release_arch }
import from jaclang.dist.jab_vendor {
    WheelTarget,
    download_wheels,
    wheels_dir,
    write_vendor_manifest
}

glob POD_GLIBC: tuple[int, int] = (2, 36),
     _LEGACY_PLATFORM_TAG = re.compile(r"^manylinux(?:\d+|_\d+_\d+)_(.+)$");


def pod_wheel_target(pod_arch: str) -> (WheelTarget | None) {
    arch = release_arch(pod_arch);
    if not arch {
        return None;
    }
    return WheelTarget(
        arch=arch,
        python_version=f"{sys.version_info.major}.{sys.version_info.minor}",
        glibc=POD_GLIBC
    );
}


def pod_arch_from_argv(raw: str) -> str {
    legacy = _LEGACY_PLATFORM_TAG.`match(raw.strip());
    return legacy.group(1) if legacy else raw.strip();
}


obj WheelVendor {
    has config: JacConfig,
        app_dir: Path,
        target: (WheelTarget | None) = None;

    def resolve_specs -> list[str] {
        plan = resolve_plan(self.config, include_dev=False);
        py_deps = [
            d
            for d in plan.for_ecosystem("python")
            if d.source == "pypi"
        ];
        skipped = sorted(
            [
                d.name
                for d in plan.for_ecosystem("python")
                if d.source != "pypi"
            ]
        );
        if skipped {
            console.print(
                f"  ⚠ not vendoring non-pypi dep(s): {', '.join(skipped)} "
                "(pods install them at boot)",
                style="warning"
            );
        }
        return get_python_provider().specs_for(py_deps);
    }

    def run {
        specs = self.resolve_specs();
        where = self.target.describe() if self.target is not None else "this host";
        if specs {
            result = download_wheels(
                specs, wheels_dir(self.app_dir), target=self.target
            );
            if not result.ok {
                if result.detail {
                    sys.stderr.write(result.detail + "\n");
                }
                if result.missing {
                    console.error(
                        f"No usable wheel for {where}: {', '.join(result.missing)}"
                    );
                } else {
                    console.error(f"Wheel download for {where} failed.");
                }
                sys.`exit(1);
            }
        }
        write_vendor_manifest(
            self.app_dir,
            specs,
            python_tag=python_tag(),
            platform_tag=self.target.platform_tag() if self.target is not None else ""
        );
        wd = wheels_dir(self.app_dir);
        count = len(list(wd.`glob("*.whl"))) if wd.is_dir() else 0;
        console.print(
            f"  Vendored {count} wheel(s) for {len(specs)} spec(s) targeting {where}."
        );
    }
}


def main {
    args = sys.argv[1:];
    if not args {
        console.error("usage: jac run vendor_wheels.jac <app_dir> [pod_arch]");
        sys.`exit(2);
    }
    app_dir = Path(args[0]).resolve();
    target = pod_wheel_target(pod_arch_from_argv(args[1])) if len(args) > 1 else None;

    toml_path = app_dir / "jac.toml";
    config = JacConfig.load(toml_path) if toml_path.is_file() else None;
    if config is None {
        console.error(f"No jac.toml under {app_dir}; nothing to vendor.");
        sys.`exit(1);
    } else {
        WheelVendor(config=config, app_dir=app_dir, target=target).run();
    }
}

with entry:__main__ {
    main();
}
