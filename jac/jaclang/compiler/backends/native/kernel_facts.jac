import fnmatch;
import os;

obj IgnoreRule {
    has base: str,
        segments: list[str],
        negated: bool = False,
        dir_only: bool = False,
        anchored: bool = False;
}

glob PRECOMPILED_DIR: str = "_precompiled",
     SEALED_MANIFEST: str = "MANIFEST.json",
     CODEC_KIND_OTHER: int = 4,
     CODEC_SUPPORTED_KINDS: dict[str, int] = {"utf_8": 1, "latin_1": 2, "ascii": 3},
     GIT_WALK_SKIP: tuple[str, ...] = ("node_modules", "__pycache__"),
     _IGNORE_RULES: dict[str, list[IgnoreRule]] = {},
     _IGNORED_DIRS: dict[str, bool] = {};

def kernel_native_fact(kind: str, key: str) -> str;

def hex_row(kind: int, name: str) -> str;

def codec_kind(module: str) -> int;

def codec_tables_fact -> str;

def normalize_encoding(name: str) -> str;

def codec_name_fact(key: str) -> str;

def primitive_methods_fact(type_name: str) -> str;

def sealed_runtime_fact -> str;

def import_paths_fact -> str;

def package_store_fact -> str;

def git_repo_root(path: str) -> (str | None);

def global_excludes_file -> str;

def ignore_rules_of(base: str, text: str) -> list[IgnoreRule];

def ignore_rules_in(path: str, base: str) -> list[IgnoreRule];

def segments_match(pattern: list[str], parts: list[str]) -> bool;

def rule_matches(rule: IgnoreRule, path: str, is_dir: bool) -> bool;

def rules_for(repo: str, directory: str) -> list[IgnoreRule];

def ignored_by_rules(repo: str, path: str, is_dir: bool) -> bool;

def is_git_ignored(repo: str, path: str, is_dir: bool) -> bool;

def jac_files_under(root_dir: str) -> list[str];

def git_ignored_fact(root_dir: str) -> str;
