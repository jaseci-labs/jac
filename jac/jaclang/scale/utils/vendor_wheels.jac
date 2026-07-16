"""Vendor an app's python dep closure into <app_dir>/_vendor for a fat .jab.

Run by pack_jab under the POD binary (`.pod-jac run vendor_wheels.jac <dir>`),
never the driver's own jac: the wheels must be resolved by the same
interpreter that executes `jac install` on the pod, and against the same
(sanitized) jac.toml the pod unpacks, or the vendored closure can drift from
what the pod asks pip for.
"""

import sys;

import from pathlib { Path }
import from jaclang.jac0core.sealed { python_tag }
import from jaclang.project.config { get_config_for_path }
import from jaclang.project.providers { get_python_provider, resolve_plan }
import from jaclang.runtimelib.jab_vendor {
    download_wheels,
    wheels_dir,
    write_vendor_manifest
}


def main -> int {
    args = sys.argv[1:];
    if not args {
        print("usage: jac run vendor_wheels.jac <app_dir>", file=sys.stderr);
        return 2;
    }
    app_dir = Path(args[0]).resolve();
    config = get_config_for_path(app_dir);
    if config is None {
        print(f"vendor_wheels: no jac.toml under {app_dir}", file=sys.stderr);
        return 1;
    }
    # Mirror the pod's plain `jac install`: include_dev=False, scale=False.
    plan = resolve_plan(config, include_dev=False);
    py_deps = [
        d
        for d in plan.for_ecosystem("python")
        if d.source == "pypi"
    ];
    skipped = [
        d.name
        for d in plan.for_ecosystem("python")
        if d.source != "pypi"
    ];
    if skipped {
        print(
            f"vendor_wheels: not vendoring non-pypi dep(s): "
            f"{', '.join(sorted(skipped))} (pod installs them at boot)",
            file=sys.stderr
        );
    }
    specs = get_python_provider().specs_for(py_deps);
    if specs {
        (ok, err) = download_wheels(specs, wheels_dir(app_dir));
        if not ok {
            print(f"vendor_wheels: wheel download failed:\n{err}", file=sys.stderr);
            return 1;
        }
    }
    write_vendor_manifest(app_dir, specs, python_tag=python_tag());
    wd = wheels_dir(app_dir);
    count = len(list(wd.glob("*.whl"))) if wd.is_dir() else 0;
    print(f"vendor_wheels: vendored {count} wheel(s) for {len(specs)} spec(s)");
    return 0;
}

with entry:__main__ {
    sys.exit(main());
}
