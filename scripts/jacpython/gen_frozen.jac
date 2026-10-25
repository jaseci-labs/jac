"""Generate the frozen modules of a JacPython build as the C data of one Jac module.

CPython freezes the modules its import system and startup need as marshalled
code objects: Programs/_freeze_module.py writes each into a
Python/frozen_modules header, Python/frozen.c lists them in the tables the
importer searches, and Modules/getpath.c unmarshals the frozen getpath.py.
JacPython builds none of those files. The build runs this generator with the
pinned build-time CPython before the native stage, on the extracted CPython
tree, and prepare_native.py lowers the module it writes into jacpython.o:

- the marshalled bytes of every frozen source, compiled and marshalled exactly
  as _freeze_module.py does (so the bytes equal its headers'),
- the bootstrap, stdlib and test tables, the alias table and
  PyImport_FrozenModules, as Python/frozen.c defines them,
- _Py_Get_Getpath_CodeObject, as Modules/getpath.c defines it.

The output is never checked in: the Lib/ sources and the marshal format it
depends on move with the CPython pin and the host build, so every build
writes it again.

    jac run scripts/jacpython/gen_frozen.jac --source <cpython tree> --output <module.jac>

build.sh imports it and calls main() instead (the host has no `jac`). Either
way the running interpreter must be the pinned CPython: marshal output is
that interpreter's.
"""
import argparse;
import marshal;
import sys;
import from pathlib { Path }
import from common { bytes_literal, pin }

glob COMMAND: str = "scripts/jacpython/gen_frozen.jac",
     # Every frozen source: (frozen id, path in the CPython tree). The id names
     # the marshalled array (_Py_M__<id with dots as underscores>) and the code
     # object's filename (<frozen id>). The order is Python/frozen.c's.
     SOURCES: list[tuple[str, str]] = [
         ("importlib._bootstrap", "Lib/importlib/_bootstrap.py"),
         ("importlib._bootstrap_external", "Lib/importlib/_bootstrap_external.py"),
         ("zipimport", "Lib/zipimport.py"),
         ("abc", "Lib/abc.py"),
         ("codecs", "Lib/codecs.py"),
         ("io", "Lib/io.py"),
         ("_collections_abc", "Lib/_collections_abc.py"),
         ("_sitebuiltins", "Lib/_sitebuiltins.py"),
         ("genericpath", "Lib/genericpath.py"),
         ("ntpath", "Lib/ntpath.py"),
         ("posixpath", "Lib/posixpath.py"),
         ("os", "Lib/os.py"),
         ("site", "Lib/site.py"),
         ("stat", "Lib/stat.py"),
         ("importlib.util", "Lib/importlib/util.py"),
         ("importlib.machinery", "Lib/importlib/machinery.py"),
         ("runpy", "Lib/runpy.py"),
         ("__hello__", "Lib/__hello__.py"),
         ("__phello__", "Lib/__phello__/__init__.py"),
         ("__phello__.ham", "Lib/__phello__/ham/__init__.py"),
         ("__phello__.ham.eggs", "Lib/__phello__/ham/eggs.py"),
         ("__phello__.spam", "Lib/__phello__/spam.py"),
         ("frozen_only", "Tools/freeze/flag.py"),
         # Frozen by hand rather than listed: Modules/getpath.c reads it.
         ("getpath", "Modules/getpath.py")
     ],
     # Tools/build/freeze_modules.py's FROZEN table, expanded: per table, the
     # (module name, frozen id, is package) rows. `<__phello__.**.*>` is the
     # package and its submodule tree, in the order that script walks it.
     BOOTSTRAP: list[tuple[str, str, bool]] = [
         ("_frozen_importlib", "importlib._bootstrap", False),
         ("_frozen_importlib_external", "importlib._bootstrap_external", False),
         ("zipimport", "zipimport", False)
     ],
     STDLIB: list[tuple[str, str, bool]] = [
         # stdlib - startup, without site (python -S)
         ("abc", "abc", False),
         ("codecs", "codecs", False),
         ("io", "io", False),
         # stdlib - startup, with site
         ("_collections_abc", "_collections_abc", False),
         ("_sitebuiltins", "_sitebuiltins", False),
         ("genericpath", "genericpath", False),
         ("ntpath", "ntpath", False),
         ("posixpath", "posixpath", False),
         ("os", "os", False),
         ("site", "site", False),
         ("stat", "stat", False),
         # runpy - run module with -m
         ("importlib.util", "importlib.util", False),
         ("importlib.machinery", "importlib.machinery", False),
         ("runpy", "runpy", False)
     ],
     TEST: list[tuple[str, str, bool]] = [
         ("__hello__", "__hello__", False),
         ("__hello_alias__", "__hello__", False),
         ("__phello_alias__", "__hello__", True),
         ("__phello_alias__.spam", "__hello__", False),
         ("__phello__", "__phello__", True),
         ("__phello__.__init__", "__phello__", False),
         ("__phello__.ham", "__phello__.ham", True),
         ("__phello__.ham.__init__", "__phello__.ham", False),
         ("__phello__.ham.eggs", "__phello__.ham.eggs", False),
         ("__phello__.spam", "__phello__.spam", False),
         ("__hello_only__", "frozen_only", False)
     ];

# The marshalled code object of one source, as Programs/_freeze_module.py
# writes it: compiled from the file's bytes as `<frozen id>` with no
# inherited flags, and marshalled at the default version. The code object is
# held in a local while it is marshalled, as there: marshal writes a
# back-reference flag on every object something else also holds.
def freeze(frozen_id: str, source: Path) -> bytes {
    text = source.read_bytes();
    code = compile(
        text, f"<frozen {frozen_id}>", "exec", optimize=0, dont_inherit=True
    );
    return marshal.dumps(code);
}

def symbol(frozen_id: str) -> str {
    return "_Py_M__" + frozen_id.replace(".", "_");
}

# The module a frozen id stands for, as freeze_modules.py's FrozenSource
# names it: the id itself for a Lib/ source, none for anything else.
def source_module(frozen_id: str) -> str | None {
    return frozen_id if dict(SOURCES)[frozen_id].startswith("Lib/") else None;
}

def source_is_package(frozen_id: str) -> bool {
    return dict(SOURCES)[frozen_id].endswith("/__init__.py");
}

# The alias rows Python/frozen.c lists: every row whose module is not its
# source's own module, with that module ("<" before a package's) or NULL.
def aliases -> list[tuple[str, str | None]] {
    out: list[tuple[str, str | None]] = [];
    for (name, frozen_id, _) in BOOTSTRAP + STDLIB + TEST {
        orig = source_module(frozen_id);
        if orig is None {
            out.append((name, None));
        } elif name != orig {
            out.append((name, ("<" + orig) if source_is_package(frozen_id) else orig));
        }
    }
    return out;
}

def c_string(text: str | None) -> str {
    return f'ptr[u8]("{text}")' if text is not None else "ptr[u8]()";
}

def table(
    name: str, rows: list[tuple[str, str, bool]], sizes: dict[str, int]
) -> list[str] {
    lines = [f"         {name}: list[FrozenModule] = ["];
    entries: list[str] = [];
    for (module, frozen_id, package) in rows {
        entries.append(
            f"             FrozenModule(name={c_string(module)}, "
                + f"code=addressof({symbol(frozen_id)}), size={sizes[frozen_id]}, "
                + f"is_package={int(package)})"
        );
    }
    entries.append(
        "             FrozenModule(name=ptr[u8](), code=ptr[u8](), size=0, is_package=0)"
    );
    lines.append(",\n".join(entries));
    lines.append("         ],");
    return lines;
}

# The generated module: every marshalled array and table as private C data,
# the five names import.c reads, and _Py_Get_Getpath_CodeObject.
def frozen_module(frozen: dict[str, bytes]) -> str {
    sizes = {frozen_id: len(data) for (frozen_id, data) in frozen.items()};
    lines = [
        '"""The frozen modules of this JacPython build, as Python/frozen.c and the',
        "Python/frozen_modules headers define them for CPython "
            + pin()["version"]
            + ".",
        "",
        f"Generated by {COMMAND} at build time; never checked in.",
        'See jac/jaclang/runtime/python/LICENSE.cpython.\n"""',
        "",
        "import from c {",
        "    obj FrozenModule {",
        "        has name: ptr[u8],",
        "            code: ptr[u8],",
        "            size: i32,",
        "            is_package: i32;",
        "    }",
        "",
        "    obj FrozenAlias {",
        "        has name: ptr[u8],",
        "            orig: ptr[u8];",
        "    }",
        "",
        "    def PyMarshal_ReadObjectFromString(data: ptr[u8], size: i64) -> ptr;",
        ""
    ];
    arrays = [
        f"{symbol(frozen_id)}: list[u8] = "
            + bytes_literal(list(data), "u8").replace("\n", "\n             ")
        for (frozen_id, data) in frozen.items()
    ];
    lines.append("    glob:priv " + ",\n         ".join(arrays) + ",");
    lines += table("bootstrap_modules", BOOTSTRAP, sizes);
    lines += table("stdlib_modules", STDLIB, sizes);
    lines += table("test_modules", TEST, sizes);
    alias_rows = [
        f"             FrozenAlias(name={c_string(name)}, orig={c_string(orig)})"
        for (name, orig) in aliases()
    ];
    alias_rows.append("             FrozenAlias(name=ptr[u8](), orig=ptr[u8]())");
    lines += [
        "         aliases: list[FrozenAlias] = [",
        ",\n".join(alias_rows),
        "         ];",
        "",
        "    # PyImport_FrozenModules is NULL: embedding applications may point it",
        "    # at their own table.",
        "    glob _PyImport_FrozenBootstrap: ptr[FrozenModule] = addressof(bootstrap_modules),",
        "         _PyImport_FrozenStdlib: ptr[FrozenModule] = addressof(stdlib_modules),",
        "         _PyImport_FrozenTest: ptr[FrozenModule] = addressof(test_modules),",
        "         _PyImport_FrozenAliases: ptr[FrozenAlias] = addressof(aliases),",
        "         PyImport_FrozenModules: ptr[FrozenModule] = ptr[FrozenModule]();",
        "",
        "    def _Py_Get_Getpath_CodeObject -> ptr {",
        "        return PyMarshal_ReadObjectFromString(addressof("
            + symbol("getpath")
            + f"), {sizes['getpath']});",
        "    }",
        "}"
    ];
    return "\n".join(lines) + "\n";
}

def main(argv: list[str]) {
    parser = argparse.ArgumentParser(
        prog=COMMAND, description="Write the frozen modules as a Jac module."
    );
    parser.add_argument(
        "--source", required=True, help="the extracted CPython source tree"
    );
    parser.add_argument("--output", required=True, help="the Jac module to write");
    args = parser.parse_args(argv);
    version = pin()["version"];
    if ".".join(str(part) for part in sys.version_info[:3]) != version {
        sys.exit(
            f"{COMMAND}: run with the pinned CPython {version}; marshal output is "
            f"the running interpreter's ({sys.version.split()[0]})"
        );
    }
    tree = Path(args.source);
    frozen = {
        frozen_id: freeze(frozen_id, tree / relative)
        for (frozen_id, relative) in SOURCES
    };
    output = Path(args.output);
    output.parent.mkdir(parents=True, exist_ok=True);
    output.write_text(frozen_module(frozen));
    size = sum(len(data) for data in frozen.values());
    print(f"{COMMAND}: {len(frozen)} modules, {size} bytes -> {output}");
}

with entry:__main__ {
    main(sys.argv[1:]);
}
