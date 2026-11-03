"""The source facts `jac fix` migrates by, answered inside the kernel session:
retired placement markers found by the lexer, the codespace of each top-level
element and import, and the declarations a serving app exposes."""
import os;

glob ELEMENT_KEYWORDS: tuple[str, ...] = (
         'import',
         'include',
         'def',
         'obj',
         'class',
         'enum',
         'node',
         'edge',
         'walker',
         'can',
         'glob',
         'test',
         'impl',
         'sem',
         'with',
         'async',
         'let'
     ),
     NAMED_ELEMENT_KEYWORDS: tuple[str, ...] = (
         'def',
         'obj',
         'class',
         'enum',
         'node',
         'edge',
         'walker',
         'can',
         'glob',
         'test',
         'impl',
         'let'
     ),
     MARKER_SPACES: dict[str, str] = {'sv': 'server', 'cl': 'client', 'na': 'native'};

def is_string_kind(kind_str: str) -> bool;

def dotted_target(tokens: list[LexToken], start: int) -> str;

def first_name_after(tokens: list[LexToken], start: int) -> str;

def collect_block_claims(
    tokens: list[LexToken], body_start: int, body_end: int, space: str, res: MarkerScan
);

def marker_scan(src: str, file_path: str) -> MarkerScan;

def import_spaces(module: uni.Module) -> list[ImportSpace];

def top_element_spaces(module: uni.Module) -> list[ElementSpace];

def module_has_jsx(decl: uni.UniNode) -> bool;

def returns_jsx(decl: uni.UniNode) -> bool;

def parse_module(path: str) -> (uni.Module | None);

def plain_top_decls(module: uni.Module) -> dict[str, uni.UniNode];

def priv_top_decls(module: uni.Module) -> dict[str, uni.UniNode];

def resolve_project_import(
    module_path: uni.ModulePath, importer: str, proj_root: str
) -> str;

def imported_names(imp: uni.Import) -> list[str];

def served_access_plan(proj_root: str) -> AccessPlan;
