"""Remove build-host paths from the installed interpreter's extension metadata."""
import pathlib
import pprint
import sys

prefix = pathlib.Path(sys.executable).resolve().parents[1]
work = prefix.parents[1]
for config in (prefix / "lib/python3.14").glob("_sysconfigdata_*.py"):
    namespace = {}
    exec(compile(config.read_text(), str(config), "exec"), namespace)
    values = namespace["build_time_vars"]
    for key, value in values.items():
        if isinstance(value, str):
            for tool in ("pycc", "cc", "ar", "ranlib"):
                value = value.replace(str(work / "bin" / tool), "cc" if tool == "pycc" else tool)
            value = value.replace("-I" + str(work / "deps/include"), "")
            value = value.replace("-L" + str(work / "deps/lib"), "")
            values[key] = value
    values.update(CC="cc", CXX="c++", AR="ar", RANLIB="ranlib")
    config.write_text(
        "# Configuration of Jac's source-built CPython runtime.\n"
        "import sys as _sys\n"
        "build_time_vars = " + pprint.pformat(values, sort_dicts=True) + "\n"
        "for _key, _value in build_time_vars.items():\n"
        "    if isinstance(_value, str):\n"
        f"        build_time_vars[_key] = _value.replace({str(prefix)!r}, _sys.base_prefix)\n"
    )
