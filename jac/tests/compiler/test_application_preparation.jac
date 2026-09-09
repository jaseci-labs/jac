"""Application preparation owns compilation; loading consumes its artifacts."""

import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.compiler.driver.application { prepare_application }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compiler { JacCompiler }
import from jaclang.runtime.prepared { forget, prepared_manifest, initialize_application }


test "executable import discovery includes package initializers and deferred imports" {
    import from jaclang.compiler.backends.py.artifact_imports { runtime_sources }
    tmp = tempfile.mkdtemp(prefix="jac-prepared-imports-");
    try {
        base = Path(tmp);
        for name in ['pkg', 'shared'] {
            (base / name).mkdir();
        }
        expected = ['pkg/__init__.jac', 'pkg/util.jac', 'pkg/extra.jac',
                    'shared/__init__.jac', 'shared/sub.jac'];
        for name in expected {
            (base / name).write_text('');
        }
        source = str(base / 'pkg' / 'main.jac');
        code = compile(
            'from .util import f\nfrom shared import sub\ndef later():\n import pkg.extra\n',
            source, 'exec'
        );
        assert runtime_sources(code, source, tmp) == {
            str(base / name) for name in expected
        };
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "preparation does not execute modules and warm restoration does not compile" {
    tmp = tempfile.mkdtemp(prefix="jac-prepared-");
    try {
        path = Path(tmp) / 'main.jac';
        marker = Path(tmp) / 'initialized';
        (Path(tmp) / 'values.jac').write_text(
            "def:pub message -> str { return 'hello'; }\n"
        );
        path.write_text(
            "import from values { message }\n"
            + "import from pathlib { Path }\n"
            + f"with entry {{ Path({str(marker)!r}).write_text('yes'); }}\n"
            + "def:pub hello -> str { return message(); }\n"
        );
        first = prepare_application(str(path), JacProgram(), tmp);
        assert not marker.exists();
        assert str(path) in first.code;
        assert first.manifests[str(path)]['func_access']['hello'] is False;
        assert first.manifests[str(path)]['func_access']['message'] is False;
        forget(str(path));
        with patch.object(
            JacCompiler, '_compile_pipeline',
            side_effect=AssertionError('warm preparation entered the compiler')
        ) {
            second = prepare_application(str(path), JacProgram(), tmp);
        }
        assert not marker.exists();
        assert second.manifests == first.manifests;
        with patch.object(
            JacCompiler, 'get_bytecode',
            side_effect=AssertionError('initialization requested compiler bytecode')
        ) {
            module: any = initialize_application(second);
        }
        assert marker.exists();
        assert module.hello() == 'hello';
    } finally {
        forget(str(Path(tmp) / 'main.jac'));
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "source changes invalidate a prepared revision and replace its access metadata" {
    tmp = tempfile.mkdtemp(prefix="jac-prepared-edit-");
    try {
        path = Path(tmp) / 'main.jac';
        path.write_text("def:pub hello -> str { return 'old'; }\n");
        prepare_application(str(path), JacProgram(), tmp);
        path.write_text("def hello -> str { return 'changed'; }\n");
        updated = prepare_application(str(path), JacProgram(), tmp);
        assert updated.manifests[str(path)]['func_access']['hello'] is True;
        assert prepared_manifest(str(path)) == updated.manifests[str(path)];
    } finally {
        forget(str(Path(tmp) / 'main.jac'));
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "failed preparation does not replace the last working revision" {
    tmp = tempfile.mkdtemp(prefix="jac-prepared-fail-");
    try {
        path = Path(tmp) / 'main.jac';
        path.write_text("def:pub hello -> str { return 'old'; }\n");
        previous = prepare_application(str(path), JacProgram(), tmp);
        path.write_text("def hello -> str { return missing_symbol; }\n");
        failed = False;
        try {
            prepare_application(str(path), JacProgram(), tmp);
        } except RuntimeError {
            failed = True;
        }
        assert failed;
        assert prepared_manifest(str(path)) == previous.manifests[str(path)];
    } finally {
        forget(str(Path(tmp) / 'main.jac'));
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
