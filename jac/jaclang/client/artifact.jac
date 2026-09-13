"""Client bundle artifacts shared by builders and the application server."""

import from pathlib { Path }
import from types { ModuleType }

class ClientBundleError(RuntimeError) {}

class MissingBunError(ClientBundleError) {}

obj ClientBundle {
    has module_name: str,
        code: str,
        client_functions: list[str],
        client_globals: list[str],
        hash: str;
}

def prebuilt_bundle(module: ModuleType, source_path: Path) -> ClientBundle | None {
    import from jaclang.server.sealed_serve { client_dist_for, serve_manifest_for }
    dist = client_dist_for(str(source_path));
    if dist is None {
        return None;
    }
    candidates = sorted(dist.`glob('client.*.js'));
    if len(candidates) != 1 {
        raise ClientBundleError(f'Expected one client bundle in {dist}, found {len(candidates)}');
    }
    bundle_js = candidates[0];
    manifest = serve_manifest_for(str(source_path)) or {};
    client = manifest.get('client', {}) or {};
    return ClientBundle(
        module_name=module.__name__,
        code=bundle_js.read_text(encoding='utf-8'),
        client_functions=list(client.get('exports', []) or []),
        client_globals=list(client.get('globals', []) or []),
        hash=bundle_js.name.split('.')[1]
    );
}
