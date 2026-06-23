"""Typeshed third-party stub index lookup.

The single binary ships only typeshed *stdlib* stubs; third-party type stubs are
installed per-project into `.jac/venv` by `jac add` and resolved from there (see
modresolver `_candidate_from_stub_package`). This module reads the shipped
`stub_index.json` (generated from typeshed METADATA by launcher/gen_stub_index.zig)
so `jac add` can tell whether a package has a `types-*` stub and what to install.

`stub_index.json` is gitignored and built at the pinned typeshed commit by
launcher/fetch-typeshed.sh (via launcher/gen_stub_index.zig), alongside the stdlib
fetch -- not committed. Missing index => lookup_stub returns None (jac add still
installs the package, just without auto-adding stubs).
"""

import json;
import os;
import re;

"""Load the shipped stub index: PEP 503 dist name -> stub metadata dict."""
def load_stub_index -> dict {
    path = os.path.join(os.path.dirname(__file__), 'stub_index.json');
    if os.path.isfile(path) {
        try {
            with open(path, 'r', encoding='utf-8') as f {
                loaded: any = json.load(f);
            }
            if isinstance(loaded, dict) {
                return loaded;
            }
        } except (OSError, ValueError) {
            ;
        }
    }
    return {};
}

"""Normalize a distribution name per PEP 503 (lowercase, runs of [-_.] -> '-')."""
def normalize_dist_name(name: str) -> str {
    return re.sub(r'[-_.]+', '-', name).lower();
}

"""Return the typeshed stub entry for a distribution, or None.

Entry keys: stub_dist (PyPI `types-*` name), version, obsolete, imports.
Obsolete stubs (upstream ships inline types) are skipped unless requested.
"""
def lookup_stub(dist_name: str, include_obsolete: bool = False) -> (dict | None) {
    idx = load_stub_index();
    entry: any = idx.get(normalize_dist_name(dist_name));
    if not isinstance(entry, dict) {
        return None;
    }
    if entry.get('obsolete') and not include_obsolete {
        return None;
    }
    return entry;
}
