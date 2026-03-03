"""File discovery utilities for Jac module caching.

Provides functions to discover annex files (.impl.jac, .test.jac),
variant files (.sv.jac, .cl.jac, .na.jac), and base files for a
given Jac source path. Used by JIR cache invalidation and formatter.
"""
import os;
import sys;
import from pathlib { Path }

"""Get the platform-appropriate global cache directory for Jac bytecode.

    Returns:
        Path to the global cache directory:
        - Linux:   ~/.cache/jac/bytecode/ (respects XDG_CACHE_HOME)
        - macOS:   ~/Library/Caches/jac/bytecode/
        - Windows: %LOCALAPPDATA%/jac/cache/bytecode/
    """
def get_global_cache_dir -> Path {
    if (sys.platform == 'win32') {
        base = Path(os.environ.get('LOCALAPPDATA', Path.home() / 'AppData' / 'Local'));
        return (base / 'jac' / 'cache' / 'bytecode');
    } elif (sys.platform == 'darwin') {
        return Path.home() / 'Library' / 'Caches' / 'jac' / 'bytecode';
    } else {
        xdg_cache = os.environ.get('XDG_CACHE_HOME');
        base = Path(xdg_cache) if xdg_cache else (Path.home() / '.cache');
        return base / 'jac' / 'bytecode';
    }
}

"""Discover annex files (.impl.jac, .test.jac) for a source .jac or .cl.jac file.

    Searches: same directory, module-specific folder (foo.impl/), shared folder (impl/, test/).
    """
def discover_annex_files(source_path: str, suffix: str = '.impl.jac') -> list[str] {
    src = Path(source_path).resolve();
    if (not src.name.endswith('.jac') or src.name.endswith(suffix)) {
        return [];
    }
    base = src.stem;
    # Determine the source file's own variant context (if any).
    src_variant: (str | None) = None;
    for vext in ('.sv', '.cl', '.na') {
        if base.endswith(vext) {
            src_variant = vext;
            base = base[:-len(vext)];
            break;
        }
    }
    # When the source is a variant (.sv/.cl/.na) and no bare .jac head
    # exists, bare annex files (no variant suffix) belong to this variant.
    bare_head_exists = (
        src_variant is not None and (src.parent / (base + '.jac')).is_file()
    );
    mod_folder = src.parent / (base + suffix[:-4]);
    shared_folder = suffix[1:-4];
    dirs = [src.parent, mod_folder, (src.parent / shared_folder)];
    results: list[str] = [];
    for d in dirs {
        if not d.is_dir() {
            continue;
        }
        for f in d.iterdir() {
            if (not f.is_file() or not f.name.endswith(suffix)) {
                continue;
            }
            if ((d != mod_folder) and not f.name.startswith(f"{base}.")) {
                continue;
            }
            # Determine the annex file's variant context.
            annex_stem = f.name[:-len(suffix)];  # e.g. "svc.sv" from "svc.sv.impl.jac"
            annex_variant: (str | None) = None;
            for vext in ('.sv', '.cl', '.na') {
                if annex_stem.endswith(vext) {
                    annex_variant = vext;
                    break;
                }
            }
            # Variant-suffixed annex: must match the source variant exactly.
            # Bare annex (no variant): matches any source, UNLESS a bare
            # .jac head exists that would claim it instead.
            if annex_variant is not None {
                if (annex_variant != src_variant) {
                    continue;
                }
            } elif (src_variant is not None and bare_head_exists) {
                continue;
            }
            results.append(str(f));
        }
    }
    return results;
}

"""Discover variant files (.sv.jac, .cl.jac, .na.jac) for a head module.

    The head module is whichever file has the highest precedence among the
    variants that exist on disk:  .jac > .sv.jac > .cl.jac > .na.jac

    Given the head, this function returns all *lower-precedence* variant
    files that exist.  For example if only ``main.sv.jac`` and ``main.na.jac``
    exist, calling with ``main.sv.jac`` returns ``[".../main.na.jac"]``.

    Impl and test files are never considered heads or variants.
    """
glob _VARIANT_SUFFIXES: list[str] = ['.sv.jac', '.cl.jac', '.na.jac'];

def discover_variant_files(source_path: str) -> list[str] {
    src = Path(source_path).resolve();
    if not src.name.endswith('.jac') {
        return [];
    }
    if ('.impl.' in src.name or '.test.' in src.name) {
        return [];
    }
    # Determine the base stem and which suffix the source has.
    stem = src.stem;  # e.g. "main" or "main.sv"
    head_suffix: (str | None) = None;
    for vs in _VARIANT_SUFFIXES {
        ext = vs[:-4];  # ".sv", ".cl", ".na"
        if stem.endswith(ext) {
            head_suffix = vs;
            stem = stem[:-len(ext)];
            break;
        }
    }
    # If a higher-precedence file exists on disk this file is a variant,
    # not the head — return empty so the head handles discovery.
    if (head_suffix is not None) {
        if (src.parent / f"{stem}.jac").is_file() {
            return [];
        }
        for vs in _VARIANT_SUFFIXES {
            if (vs == head_suffix) {
                break;
            }
            if (src.parent / f"{stem}{vs}").is_file() {
                return [];
            }
        }
    }
    # Collect only the suffixes that come AFTER the head in precedence.
    if (head_suffix is None) {
        # Plain .jac — all variant suffixes are lower precedence.
        search_suffixes = _VARIANT_SUFFIXES;
    } else {
        idx = _VARIANT_SUFFIXES.index(head_suffix);
        search_suffixes = _VARIANT_SUFFIXES[idx + 1:];
    }
    variants: list[str] = [];
    for variant_suffix in search_suffixes {
        variant_path = src.parent / f"{stem}{variant_suffix}";
        if variant_path.is_file() {
            variants.append(str(variant_path));
        }
    }
    return variants;
}

"""Discover the base .jac or .cl.jac file for an annex file (.impl.jac, .test.jac).

    Searches: same directory, module-specific folder (foo.impl/), shared folder (impl/).
    For multi-part names like "foo.bar.impl.jac", only the first component is used.
    """
def discover_base_file(annex_path: str) -> (str | None) {
    src = Path(annex_path).resolve();
    annex_types = {'.impl.jac': '.impl', '.test.jac': '.test'};
    for (suffix, folder_suffix) in annex_types.items() {
        if src.name.endswith(suffix) {
            base_name = src.name[:-len(suffix)].split('.')[0];
            parent = src.parent.name;
            candidates = [(src.parent, base_name)];
            if parent.endswith(folder_suffix) {
                candidates.append((src.parent.parent, parent[:-len(folder_suffix)]));
            }
            if (parent in {'impl','test'}) {
                candidates.append((src.parent.parent, base_name));
            }
            for (directory, name) in candidates {
                for ext in ('.jac', '.cl.jac') {
                    path = directory / f"{name}{ext}";
                    if (path.is_file() and (path != src)) {
                        return str(path);
                    }
                }
            }
            break;
        }
    }
    return None;
}
