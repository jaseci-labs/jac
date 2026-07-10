# ruff: noqa: ANN401, T201
"""Generate ``_cmd_manifest.py`` from live ``@registry.command`` registrations.

Run via ``python -m jaclang.cli.gen_cmd_manifest`` or ``jac gen-cmd-manifest``.
The drift test in ``tests/test_lazy_bootstrap.py`` compares the checked-in
manifest against a fresh registry snapshot using the same collector.
"""

from __future__ import annotations

import pprint
from pathlib import Path
from typing import Any

_KIND_NAMES = {
    1: "POSITIONAL",
    2: "OPTION",
    3: "FLAG",
    4: "MULTI",
    5: "REMAINDER",
    6: "APPEND",
}

_TYPE_NAMES = {str: "str", int: "int", bool: "bool", float: "float"}


def _arg_to_dict(arg: Any) -> dict[str, Any]:
    kind_val = getattr(arg.kind, "value", arg.kind)
    kind_name = _KIND_NAMES.get(kind_val, str(kind_val))
    typ = arg.typ if isinstance(arg.typ, type) else str
    return {
        "name": arg.name,
        "kind": kind_name,
        "typ": _TYPE_NAMES.get(typ, "str"),
        "default": arg.default,
        "help": arg.help or "",
        "short": arg.short,
        "choices": arg.choices,
        "required": bool(arg.required),
        "metavar": arg.metavar,
        "dest": arg.dest,
    }


def _spec_to_dict(spec: Any) -> dict[str, Any]:
    module = spec.module
    if module is None and spec.handler is not None:
        module = getattr(spec.handler, "__module__", None)
    return {
        "name": spec.name,
        "help": spec.help,
        "tier": spec.tier or "",
        "group": spec.group,
        "hidden": bool(spec.hidden),
        "module": module,
        "args": [_arg_to_dict(a) for a in spec.args],
        "examples": list(spec.examples or []),
    }


def collect_manifest() -> list[dict[str, Any]]:
    """Import all command modules and return sorted manifest entries."""
    import jaclang.cli.commands  # noqa: F401
    from jaclang.cli.registry import get_registry, register_feature_commands

    register_feature_commands()
    specs = get_registry().get_all(include_hidden=True)
    entries = [_spec_to_dict(s) for s in specs]
    entries.sort(key=lambda e: e["name"])
    return entries


def manifest_diff(
    checked_in: list[dict[str, Any]], live: list[dict[str, Any]]
) -> list[str]:
    """Return human-readable drift messages (empty when in sync)."""
    by_name_ci = {e["name"]: e for e in checked_in}
    by_name_live = {e["name"]: e for e in live}
    errors: list[str] = []

    missing = sorted(set(by_name_live) - set(by_name_ci))
    extra = sorted(set(by_name_ci) - set(by_name_live))
    if missing:
        errors.append(f"manifest missing commands: {missing}")
    if extra:
        errors.append(f"manifest has stale commands: {extra}")

    for name in sorted(set(by_name_ci) & set(by_name_live)):
        ci, lv = by_name_ci[name], by_name_live[name]
        for field in ("help", "group", "module", "hidden", "tier"):
            if ci.get(field) != lv.get(field):
                errors.append(
                    f"{name}.{field}: manifest={ci.get(field)!r} live={lv.get(field)!r}"
                )
        ci_args = [a["name"] for a in ci.get("args", [])]
        lv_args = [a["name"] for a in lv.get("args", [])]
        if ci_args != lv_args:
            errors.append(f"{name}.args: manifest={ci_args!r} live={lv_args!r}")
    return errors


def render_manifest_py(entries: list[dict[str, Any]]) -> str:
    body = pprint.pformat(entries, width=100, sort_dicts=False)
    return (
        '"""Command manifest for lazy CLI loading.\n\n'
        "Lists all built-in command metadata so the CLI can build the argparse parser\n"
        "and print help without importing any command module bodies. Each entry's\n"
        "``module`` field is imported lazily at dispatch time.\n\n"
        "AUTO-GENERATED - regenerate with ``jac gen-cmd-manifest``.\n"
        '"""\n\n'
        "from __future__ import annotations\n\n"
        f"MANIFEST: list[dict] = {body}\n"
    )


def generate(*, verify: bool = False) -> int:
    live = collect_manifest()
    target = Path(__file__).with_name("_cmd_manifest.py")
    if verify:
        if not target.is_file():
            print(f"ERROR: {target} does not exist")
            return 1
        ns: dict[str, Any] = {}
        exec(target.read_text(encoding="utf-8"), ns)
        checked_in = ns["MANIFEST"]
        errors = manifest_diff(checked_in, live)
        if errors:
            for err in errors:
                print(f"DRIFT: {err}")
            print("Run `jac gen-cmd-manifest` to update.")
            return 1
        print("cmd manifest is up to date")
        return 0

    target.write_text(render_manifest_py(live), encoding="utf-8")
    print(f"Wrote {len(live)} commands to {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(generate())
