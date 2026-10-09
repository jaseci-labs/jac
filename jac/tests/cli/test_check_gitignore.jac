import subprocess;
import from contextlib { chdir }
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from jaclang.cli.commands.analysis { _drop_git_ignored, _iter_jac_files }

test "directory scans honor Git ignores for unusual filenames" {
    with TemporaryDirectory() as tmp, chdir(tmp) {
        subprocess.run(['git', 'init', '-q'], check=True);
        Path('.gitignore').write_text('generated/\n');
        Path('main.jac').write_text('with entry { print("ok"); }\n');
        Path('generated').mkdir();
        names = [
            'plain.jac',
            'café.jac',
            'two words.jac',
            'a"b.jac',
            'tab\tname.jac',
            'line\nname.jac',
            'return\rname.jac'
        ];
        for name in names {
            (Path('generated') / name).write_text('with entry {\n');
        }
        for quote_path in ['true', 'false'] {
            subprocess.run(['git', 'config', 'core.quotePath', quote_path], check=True);
            (files, errors) = _iter_jac_files(['.']);
            assert not errors;
            assert files == ['main.jac'];
        }
        # Explicitly requested files and ignored directories remain selectable.
        for name in names {
            path = str(Path('generated') / name);
            assert _iter_jac_files([path]) == ([path], False);
        }
        (files, errors) = _iter_jac_files(['generated']);
        assert not errors;
        assert set(files) == {str(Path('generated') / name) for name in names};
        Path('.gitignore').unlink();
        (files, errors) = _iter_jac_files(['.']);
        assert not errors;
        assert set(files)
            == {'main.jac'} | {str(Path('generated') / name) for name in names};
    }
}

test "Git ignore filtering keeps paths outside a repository" {
    with TemporaryDirectory() as tmp, chdir(tmp) {
        paths = ['main.jac', 'café.jac'];
        assert _drop_git_ignored(paths) == paths;
    }
}

test "Git ignore filtering accepts empty input without invoking Git" {
    with patch('subprocess.run') as run {
        assert _drop_git_ignored([]) == [];
        run.assert_not_called();
    }
}

test "Git ignore filtering keeps paths when Git is unavailable" {
    with patch('subprocess.run', side_effect=FileNotFoundError()) {
        paths = ['main.jac', 'café.jac'];
        assert _drop_git_ignored(paths) == paths;
    }
}
