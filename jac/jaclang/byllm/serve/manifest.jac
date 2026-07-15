"""Manifest-backed model registry for byLLM local models.

Replaces the compiled `LOCAL_MODELS` dict (formerly `byllm.local_runtime`)
with a three-layer registry, merged in order (later wins):

  1. `DEFAULT_MANIFEST` -- bundled below, so the base library always ships
     with the binary (a jac glob is guaranteed packaged; a data file may not
     be). Absorbs the per-model facts that byLLM used to string-sniff from
     inside the transport (ctx window, native-tool support, tool family,
     launch flags).
  2. `<models_dir>/index.json` -- the remote-index cache, populated ONLY by an
     explicit `jac model refresh` from `[byllm.serve].manifest_url` (see
     `refresh_index`). Never fetched at import. This is how the library grows
     with no jaclang release.
  3. A dev override (`$JAC_MODELS_MANIFEST`, else `<models_dir>/models.local.json`)
     -- add/override entries locally with no tree edit.

Each entry carries the *calling convention*, not just the weights, so a model
is a self-describing Jac artifact:

    "<alias>": {
        "description": str,
        "ctx_window": int,               # stamped onto the Model (drives compaction)
        "supports_native_tools": bool,   # authoritative; replaces the gemma name-sniff
        "tool_family": str,              # informational (e.g. "gemma", "qwen")
        "weights": {                     # ONE of two forms:
            "repo": str, "file": str, "size_mb": int          # HuggingFace (needs huggingface_hub)
            # or: "url": str, "sha256": str, "file": str, "size_mb": int   # direct + dependency-free
        },
        "launch": {"jinja": bool, "chat_template": str | None},  # extra llama-server flags
        "stop": list[str],               # stop strings merged into chat requests
        "min_ram_mb": int                # advisory RAM floor (informational for
                                         # now; reserved for a future offload
                                         # estimator -- see runner.estimate_ngl)
    }
"""

import os;
import json;
import from pathlib { Path }

glob LOCAL_PREFIX: str = "local:";
glob MANIFEST_VERSION: int = 1;

# Bundled model library. Gemma 4 E4B (released 2026-04-02) is the default --
# the on-device instruction-tuned variant, ~5 GB at Q4_K_M. Entries use the
# HuggingFace weights form (proven, but needs huggingface_hub); the direct
# url+sha256 form is dependency-free and preferred for new entries.
#
# `chat_template` is intentionally null: modern instruction-tuned GGUFs ship
# their own Jinja template in file metadata, and llama-server uses it. Hard-
# coding a template breaks the newer Gemma 4 / Qwen 3.5 variants.
glob DEFAULT_MANIFEST: dict = {
    "version": MANIFEST_VERSION,
    "models": {
        "gemma-4-e4b": {
            "description": "Google Gemma 4 E4B (instruction-tuned, Q4_K_M)",
            "ctx_window": 8192,
            "supports_native_tools": False,
            "tool_family": "gemma",
            "weights": {
                "repo": "unsloth/gemma-4-E4B-it-GGUF",
                "file": "gemma-4-E4B-it-Q4_K_M.gguf",
                "size_mb": 5000
            },
            "launch": {"jinja": False, "chat_template": None},
            "stop": [],
            "min_ram_mb": 6000
        },
        "gemma-4-e2b": {
            "description": "Google Gemma 4 E2B (smaller, faster)",
            "ctx_window": 8192,
            "supports_native_tools": False,
            "tool_family": "gemma",
            "weights": {
                "repo": "unsloth/gemma-4-E2B-it-GGUF",
                "file": "gemma-4-E2B-it-Q4_K_M.gguf",
                "size_mb": 2500
            },
            "launch": {"jinja": False, "chat_template": None},
            "stop": [],
            "min_ram_mb": 3500
        },
        "qwen3.5-4b": {
            "description": "Alibaba Qwen 3.5 4B (instruction-tuned, Q4_K_M)",
            "ctx_window": 8192,
            "supports_native_tools": True,
            "tool_family": "qwen",
            "weights": {
                "repo": "unsloth/Qwen3.5-4B-GGUF",
                "file": "Qwen3.5-4B-Q4_K_M.gguf",
                "size_mb": 2800
            },
            "launch": {"jinja": True, "chat_template": None},
            "stop": [],
            "min_ram_mb": 3800
        }
    }
};

"""Strip the `local:` prefix and return the bare alias.

Returns None when `model_name` is not a local alias.
"""
def parse_alias(model_name: str) -> str | None {
    if not model_name.startswith(LOCAL_PREFIX) {
        return None;
    }
    return model_name[len(LOCAL_PREFIX):].strip().lower();
}

"""Weight/index cache root -- shared with model_cache (honours $JAC_MODELS_DIR)."""
def _models_dir -> Path {
    import from jaclang.byllm.model_cache { get_cache_dir }
    return get_cache_dir();
}

"""Remote-index cache file (populated only by explicit pull/refresh)."""
def _index_cache_path -> Path {
    return _models_dir() / "index.json";
}

"""Local dev-override file: $JAC_MODELS_MANIFEST, else <models_dir>/models.local.json."""
def _dev_override_path -> Path {
    override = os.environ.get("JAC_MODELS_MANIFEST");
    if override {
        return Path(override).expanduser();
    }
    return _models_dir() / "models.local.json";
}

"""Load a JSON object from `path`; return {} on any error or non-object."""
def _load_json_file(path: Path) -> dict {
    try {
        if not path.exists() {
            return {};
        }
        data = json.loads(path.read_text());
        return data if isinstance(data, dict) else {};
    } except Exception {
        return {};
    }
}

"""Recursively merge `over` onto `base` (dict values merge; others overwrite)."""
def _deep_merge(base: dict, over: dict) -> dict {
    out: dict = dict(base);
    for (k, v) in over.items() {
        if isinstance(v, dict) and isinstance(out.get(k), dict) {
            out[k] = _deep_merge(out[k], v);
        } else {
            out[k] = v;
        }
    }
    return out;
}

"""The fully merged manifest: DEFAULT_MANIFEST + index cache + dev override."""
def load_manifest -> dict {
    merged = _deep_merge(DEFAULT_MANIFEST, _load_json_file(_index_cache_path()));
    merged = _deep_merge(merged, _load_json_file(_dev_override_path()));
    return merged;
}

"""All model entries, keyed by alias."""
def list_entries -> dict {
    models = load_manifest().get("models");
    return models if isinstance(models, dict) else {};
}

"""All registered aliases (sorted, without the `local:` prefix)."""
def list_aliases -> list[str] {
    return sorted(list(list_entries().keys()));
}

"""Resolve a single alias to its manifest entry.

Raises ValueError (with the available aliases) when the alias is unknown.
"""
def resolve_entry(alias: str) -> dict {
    entries = list_entries();
    if alias in entries {
        return entries[alias];
    }
    available = ", ".join(sorted(entries.keys())) or "(none)";
    raise ValueError(
        f"Unknown local model alias '{alias}'. Available: {available}. "
        f"See `jac model list`."
    );
}

"""Adapt a manifest entry's `weights` into the flat spec model_cache consumes.

model_cache reads `spec['file']`, `spec['size_mb']`, and either `spec['repo']`
(HuggingFace) or `spec['url']`/`spec['sha256']` (direct download).
"""
def to_cache_spec(model_entry: dict) -> dict {
    weights = model_entry.get("weights");
    return dict(weights) if isinstance(weights, dict) else {};
}

"""Fetch the remote model index from `url` and install it as layer 2.

The only writer of `<models_dir>/index.json`; called by `jac model refresh`
(never at import). The fetched document must be a JSON object with a `models`
object; it is written atomically (.part -> replace). Returns the number of
model entries installed.
"""
def refresh_index(url: str) -> int {
    import from urllib.request { urlopen, Request }
    req = Request(url, headers={"User-Agent": "jac-model-index"});
    with urlopen(req, timeout=30) as resp {
        raw = resp.read();
    }
    data = json.loads(raw);
    if not isinstance(data, dict) or not isinstance(data.get("models"), dict) {
        raise ValueError(
            "remote model index must be a JSON object with a 'models' object "
            f"(got {type(data).__name__})"
        );
    }
    dest = _index_cache_path();
    dest.parent.mkdir(parents=True, exist_ok=True);
    tmp = dest.with_suffix(".part");
    tmp.write_text(json.dumps(data, indent=2));
    tmp.replace(dest);
    return len(data["models"]);
}
