import argparse;
import importlib;
import json;
import subprocess;
import sys;
import from pathlib { Path }

def main(manifest_path: str) -> int {
    manifest = Path(manifest_path).resolve();
    data = json.loads(manifest.read_text(encoding='utf-8'));
    parser = argparse.ArgumentParser(add_help=False);
    parser.add_argument('--app', `default=data['entry']);
    (args, remaining) = parser.parse_known_args();
    selected = next(
        (
            item
            for item in data['applications']
            if item['name'] == args.app
        ),
        None
    );
    if selected is None {
        raise ValueError(f'No exported application named {args.app!r}');
    }
    if selected.get('native') {
        native = selected['native'];
        output = manifest.parent / selected['root'] / native['output'];
        if native['kind'] == 'shared' {
            sys.stdout.write(str(output) + '\n');
            return 0;
        }
        return subprocess.run([str(output), *remaining]).returncode;
    }
    runner = importlib.import_module(selected['runner']);
    return runner.main(str(manifest), args.app, remaining);
}
