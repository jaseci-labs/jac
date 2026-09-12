"""Run pinned CPython tests against the shipped native JacPython runtime.

Use the experimental binary: jac run scripts/run_cpython_compiler_tests.jac.
The runner requires the native compiler bridge. It does not import or install
an interpreted replacement. Python audit events count native compiler calls;
optional public API wrappers only count calls into the native entry points.
No upstream test corpus is checked into this repository.
"""
import argparse;
import builtins;
import ctypes;
import hashlib;
import importlib;
import io;
import json;
import from pathlib { Path }
import sys;
import tarfile;
import tempfile;
import types;
import unittest;
import urllib.request;
def fetch_tests(cache: Path) -> Path {
    repo = Path(__file__).resolve().parents[1];
    pin_path = repo / "jac/bootstrap/python/sources.json";
    pin = json.loads(pin_path.read_text())["cpython"];
    destination = cache / pin["sha256"];
    library = destination / f"Python-{pin['version']}" / "Lib";
    marker = destination / ".complete";
    print(
        f"CPython {pin['version']} tests; archive SHA256 {pin['sha256']}", flush=True
    );
    if (
        marker.is_file()
        and (library / "test/test_compile.py").is_file()
        and (library / "ast.py").is_file()
    ) {
        return library;
    }
    with urllib.request.urlopen(pin["url"], timeout=120) as response {
        archive = response.read();
    }
    if (hashlib.sha256(archive).hexdigest() != pin["sha256"]) {
        raise RuntimeError("CPython test archive checksum mismatch");
    }
    destination.mkdir(parents=True, exist_ok=True);
    # AST round-trip tests also need pinned standard-library source fixtures.
    prefix = f"Python-{pin['version']}/Lib/";
    with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as bundle {
        members = [
            m
            for m in bundle
            if (m.isfile() and m.name.startswith(prefix))
        ];
        bundle.extractall(destination, members=members, filter="data");
    }
    marker.write_text((pin["sha256"] + "\n"));
    return library;
}

def main -> int {
    parser = argparse.ArgumentParser(description=__doc__);
    parser.add_argument(
        "--cache",
        `type=Path,
        `default=Path(tempfile.gettempdir()) / "jac-cpython-tests"
    );
    parser.add_argument(
        "--tests", nargs="+", help="Method or class names in the upstream module"
    );
    parser.add_argument("--module", `default="test.test_compile");
    parser.add_argument(
        "--compile-tests",
        action="store_true",
        help="Compile the test module freshly through native JacPython"
    );
    parser.add_argument(
        "--symtable-api",
        action="store_true",
        help="Count public native symbol-table calls"
    );
    parser.add_argument(
        "--tokenize-api",
        action="store_true",
        help="Count public native tokenizer calls"
    );
    # Retained command-line compatibility: every run now uses these native APIs.
    parser.add_argument("--runtime", action="store_true", help=argparse.SUPPRESS);
    parser.add_argument("--ast-api", action="store_true", help=argparse.SUPPRESS);
    args = parser.parse_args();
    bridge = ctypes.pythonapi?._PyJac_CompilerBridgeVersion;
    if bridge is None or bridge() != 3 {
        raise RuntimeError(
            "Use a Jac binary built with -Djacpython=true and the native compiler bridge (version 3)"
        );
    }
    for retired in (
        "_jacpython_compile",
        "_jacpython_symtable",
        "_jacpython_tokenize",
        "_jacpython_image"
    ) {
        if hasattr(sys, retired) {
            raise RuntimeError(
                f"Unexpected interpreted replacement infrastructure: {retired}"
            );
        }
    }
    calls: list[int] = [0];
    active: list[bool] = [True];
    def audit(event: str, args: any) {
        if active[0] and event == "compile" {
            calls[0] += 1;
        }
    }
    sys.addaudithook(audit);
    restorations: list[tuple[any, str, any]] = [];
    try {
        if args.symtable_api {
            import _symtable;
            original_symtable = _symtable.symtable;
            def count_symtable(*args: any, **kwargs: any) -> any {
                calls[0] += 1;
                return original_symtable(*args, **kwargs);
            }
            restorations.append((_symtable, "symtable", original_symtable));
            _symtable.symtable = count_symtable;
        }
        if args.tokenize_api {
            import _tokenize;
            original_tokenizer = _tokenize.TokenizerIter;
            def count_tokenizer(*args: any, **kwargs: any) -> any {
                calls[0] += 1;
                return original_tokenizer(*args, **kwargs);
            }
            restorations.append((_tokenize, "TokenizerIter", original_tokenizer));
            _tokenize.TokenizerIter = count_tokenizer;
        }
        return run_tests(args, calls);
    } finally {
        active[0] = False;
        for (module, name, original) in reversed(restorations) {
            setattr(module, name, original);
        }
    }
}

def run_tests(args: any, calls: list[int]) -> int {
    library = fetch_tests(args.cache);
    sys.path.insert(0, str(library));
    try {
        importlib.import_module("test");
    } finally {
        # Keep test.__path__, while runtime stdlib imports use the installed tree.
        sys.path.pop(0);
    }
    support = importlib.import_module("test.support");
    # Resource decorators are evaluated when the test module is imported.
    support.use_resources = [];
    reference_module = importlib.import_module(args.module);
    test_module: any = reference_module;
    # Verify runtime compilation before measuring individual tests.
    builtins.compile("pass", "<warmup>", "exec", dont_inherit=True);
    compiled_codes: set[int] = set();
    if args.compile_tests {
        assert reference_module.__file__ is not None;
        path = Path(reference_module.__file__);
        test_module = types.ModuleType(reference_module.__name__);
        test_module.__file__ = str(path);
        test_module.__package__ = reference_module.__package__;
        test_module.__spec__ = reference_module.__spec__;
        code = builtins.compile(
            path.read_bytes(), str(path), "exec", dont_inherit=True
        );
        pending = [code];
        while pending {
            item = pending.pop();
            compiled_codes.add(id(item));
            pending.extend(
                c
                for c in item.co_consts
                if isinstance(c, types.CodeType)
            );
        }
        sys.modules[args.module] = test_module;
        try {
            exec(code, test_module.__dict__);
        } finally {
            sys.modules[args.module] = reference_module;
        }
        print(f"JACPYTHON_TEST_MODULE {args.module}", flush=True);
    }
    if args.symtable_api or args.tokenize_api {
        print(f"JACPYTHON_API_FIXTURE_CALLS {calls[0]}", flush=True);
    }
    if (args.module == "test.test_ast.test_ast") {
        test_module.STDLIB = str(library);
        test_module.STDLIB_FILES = [path.name for path in library.glob("*.py")];
        test_module.STDLIB_FILES.extend(
            ["test/test_grammar.py", "test/test_unpack_ex.py"]
        );
    }
    class Result(unittest.TextTestResult) {
        has compiled_test: bool = False;

        def startTest(self: Result, test_case: any) {
            calls[0] = 0;
            method = getattr(
                test_case, getattr(test_case, "_testMethodName", "runTest"), None
            );
            seen: set[int] = set();
            self.compiled_test = False;
            while ((method is not None) and (id(method) not in seen)) {
                seen.add(id(method));
                if (id(method?.__code__) in compiled_codes) {
                    self.compiled_test = True;
                    break;
                }
                method = method?.__wrapped__;
            }
            super.startTest(test_case);
        }

        def addSuccess(self: Result, test_case: any) {
            if (calls[0] or self.compiled_test) {
                super.addSuccess(test_case);
            } else {
                self.addSkip(test_case, "no direct call to JacPython in this test");
            }
        }

        def stopTest(self: Result, test_case: any) {
            print(f"JACPYTHON_CALLS {test_case.id()} {calls[0]}", flush=True);
            super.stopTest(test_case);
        }
    }
    print("Compiler path: native Jac machine code", flush=True);
    try {
        sys.modules[args.module] = test_module;
        if args.tests {
            names = [
                f"TestSpecifics.{name}"
                    if (
                        name.startswith("test_")
                        and hasattr(test_module, "TestSpecifics")
                    )
                    else name for name in args.tests
            ];
            suite = unittest.defaultTestLoader.loadTestsFromNames(names, test_module);
        } elif (not args.compile_tests and (args.module == "test.test_compile")) {
            suite = unittest.defaultTestLoader.loadTestsFromTestCase(
                test_module.TestSpecifics
            );
        } else {
            suite = unittest.defaultTestLoader.loadTestsFromModule(test_module);
        }
        result = unittest.TextTestRunner(verbosity=2, resultclass=Result).run(suite);
        return int(not result.wasSuccessful());
    } finally {
        sys.modules[args.module] = reference_module;
    }
}

with entry:__main__ {
    sys.exit(main());
}
