import sys;

import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.jac0core.sealed { python_tag }
import from jaclang.project.config { JacConfig, get_config_for_path }
import from jaclang.project.providers { get_python_provider, resolve_plan }
import from jaclang.runtimelib.jab_vendor {
    download_wheels,
    wheels_dir,
    write_vendor_manifest
}


obj WheelVendor {
    has config: JacConfig,
        app_dir: Path;

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
        if specs {
            (ok, err) = download_wheels(specs, wheels_dir(self.app_dir));
            if not ok {
                console.error(f"Wheel download failed:\n{err}");
                sys.exit(1);
            }
        }
        write_vendor_manifest(self.app_dir, specs, python_tag=python_tag());
        wd = wheels_dir(self.app_dir);
        count = len(list(wd.glob("*.whl"))) if wd.is_dir() else 0;
        console.print(f"  Vendored {count} wheel(s) for {len(specs)} spec(s).");
    }
}


def main {
    args = sys.argv[1:];
    if not args {
        console.error("usage: jac run vendor_wheels.jac <app_dir>");
        sys.exit(2);
    }
    app_dir = Path(args[0]).resolve();
    config = get_config_for_path(app_dir);
    if config is None {
        console.error(f"No jac.toml under {app_dir}; nothing to vendor.");
        sys.exit(1);
    } else {
        WheelVendor(config=config, app_dir=app_dir).run();
    }
}

with entry:__main__ {
    main();
}
