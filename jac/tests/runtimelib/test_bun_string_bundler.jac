# Unit tests for the string-bundler fallback in bun_service_builder.
#
# The fallback only runs when the bun binary is unavailable, so CI rarely
# exercises it. These tests pin its two behaviors directly: expected-shape
# import lines are rewritten to const aliases, and anything else referencing
# a bundled source fails loudly instead of producing a broken bundle.

import tempfile;
import from pathlib { Path }
import from jaclang.bun_service_builder { _string_bundle_bun_artifact }


glob _STUB_RUNTIME_JS: str = (
         'export function execWalker(w, fields) { return w; }\n'
         'export function startBunServer(handlers, port) { return null; }\n'
     ),
     _WELL_FORMED_ENTRY: str = (
         'import { execWalker as _W_greet } from "./server_runtime.js";\n'
         'import { startBunServer as _start } from "./server_runtime.js";\n'
         'console.log("entry_src", _W_greet, _start);\n'
     );


def _write_stub_artifact(tmp: str, entry_src: str) -> Path {
    out_dir = Path(tmp) / '.jac' / 'server' / 'greeter';
    out_dir.mkdir(parents=True, exist_ok=True);
    (out_dir / 'server_runtime.js').write_text(_STUB_RUNTIME_JS);
    (out_dir / 'bun_schema.js').write_text('export const SCHEMA_VERSION = 1;\n');
    (out_dir / 'bun_store.js').write_text('export const marker = "store";\n');
    (out_dir / 'greeter.js').write_text('export function greet() { return 1; }\n');
    (out_dir / 'server.mjs').write_text(entry_src);
    return out_dir;
}


test "string bundler rewrites well-formed import lines to aliases" {
    with tempfile.TemporaryDirectory() as tmp {
        out_dir = _write_stub_artifact(tmp, _WELL_FORMED_ENTRY);
        bundle = _string_bundle_bun_artifact(out_dir, 'greeter');
        assert 'const _W_greet = execWalker;' in bundle , (
            f"alias rewrite missing: {bundle[:400]}"
        );
        assert 'const _start = startBunServer;' in bundle , (
            f"second alias missing: {bundle[:400]}"
        );
        # The original import must not survive: it would be a dangling
        # relative import inside a single-file bundle.
        assert 'from "./server_runtime.js"' not in bundle , (
            "bundle still contains a bundled-source import"
        );
        # Bundled sources themselves are concatenated into the chunk list.
        assert 'export function startBunServer' in bundle , "runtime source missing";
        assert 'export const marker = "store";' in bundle , "store source missing";
    }
}


test "string bundler raises on import lines outside its expected shape" {
    with tempfile.TemporaryDirectory() as tmp {
        bad_entries: list[str] = [
            # namespace import — no `as` alias pair in braces
            'import * as ns from "./server_runtime.js";\n',
            # default import
            'import rt from "./server_runtime.js";\n',
            # multi-line import the substring surgery cannot parse
            'import {\n  execWalker as _W\n} from "./server_runtime.js";\n'
        ];
        for entry_src in bad_entries {
            out_dir = _write_stub_artifact(tmp, entry_src);
            raised = False;
            try {
                _string_bundle_bun_artifact(out_dir, 'greeter');
            } except RuntimeError as e {
                raised = True;
                assert 'String bundler cannot rewrite' in str(e) , (
                    f"wrong error text: {e}"
                );
                assert './server_runtime.js' in str(e) , (
                    f"error does not name the offending source: {e}"
                );
            }
            assert raised , f"expected RuntimeError for entry_src {entry_src!r}";
        }
    }
}
