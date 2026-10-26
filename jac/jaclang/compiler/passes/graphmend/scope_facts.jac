import os;
import sys;
import from pathlib { Path }

def compiled_region_ids(
    prog: JacProgram,
    current: uni.Module,
    seen: set[str],
    wrapped: (list[uni.UniNode] | None) = None,
    walked: (set[str] | None) = None,
    sites: (dict[int, set[str]] | None) = None,
    callers: (dict[int, list[tuple[(uni.Ability, bool)]]] | None) = None
) -> set[int];

def _seed(work: list[uni.Ability], ab: uni.Ability);

def _compile_entry_seeds(mod: uni.Module) -> list[uni.UniNode];

def _mod_path(mod: uni.Module, memo: dict[int, str]) -> str;

def region_context_probe(prog: JacProgram, target_path: str) -> (str | None);

def region_closure_key(prog: JacProgram, target: uni.Module, target_path: str) -> str;

def _closure_source_digest(prog: JacProgram, path: str) -> str;

def materialize_claim_chain(prog: JacProgram, target_path: str, seen: set[str]);

def module_has_wrap_site(mod: uni.Module) -> bool;

def collect_wrap_entries(
    prog: JacProgram,
    current: uni.Module,
    seen: set[str],
    wrap_keys: set[str],
    sites: (dict[int, set[str]] | None) = None
) -> list[uni.UniNode];

def resolve_wrapped_entry(
    prog: JacProgram, call: uni.FuncCall, seen: set[str]
) -> (uni.UniNode | None);

def _wrap_def_node(name: str, ctx: uni.UniNode) -> (uni.UniNode | None);

def _wrap_import_def(
    prog: JacProgram, name: str, ctx: uni.UniNode, seen: set[str]
) -> (uni.UniNode | None);

def _wrap_var_assignment(name: str, ctx: uni.UniNode) -> (uni.Assignment | None);

def entry_key(ab: uni.Ability) -> str;

def module_entry_forwards(
    prog: JacProgram, mod: uni.Module, seen: set[str]
) -> list[uni.Ability];

def module_binds_torch(mod: uni.Module) -> bool;

def torch_binds_name(site: uni.UniNode) -> bool;

def module_reaches_autograd(mod: uni.Module) -> bool;

def _optim_spelled(recv: (uni.Expr | None)) -> bool;

def region_in_inference_ctx(region: uni.UniNode) -> bool;

def _with_disables_grad(ws: uni.WithStmt, mod: uni.Module) -> bool;

def _deco_disables_grad(ab: uni.Ability, mod: uni.Module) -> bool;

def _grad_off_target(t: (uni.Expr | None), mod: uni.Module) -> bool;

def _torch_root_declares(nm: uni.Name, mod: uni.Module) -> bool;

def binds_torch_module_base(
    prog: JacProgram, arch: uni.Archetype, seen: set[str], depth: int
) -> bool;

def _base_name(base: uni.Expr) -> (str | None);

def _is_torch_module_ref(base: uni.Expr) -> bool;

def import_item_of(nm: uni.Name) -> (uni.ModuleItem | None);

def _binds_module_item(nm: uni.Name, from_path: str, item_name: str) -> bool;

def _binds_module_path(nm: uni.Name, dotted: str) -> bool;

def _sym_decl(nm: uni.Name) -> (uni.UniNode | None);

def module_is_seed(prog: JacProgram, mod: uni.Module, seen: set[str]) -> bool;

def register_claim(prog: JacProgram, mod: uni.Module, seen: set[str]) -> bool;

def claim_chain_reaches(prog: JacProgram, chain_root: str, target: str) -> bool;

def entry_module(key: str) -> str;

def claim_path(prog: JacProgram, path: str) -> bool;

def _compile_for_facts(prog: JacProgram, path: str) -> (uni.Module | None);

def claim_targets(mod: uni.Module, pkg_root: str) -> list[str];

def _import_paths(imp: uni.Import) -> list[str];

def _denied_path(mp: uni.ModulePath) -> bool;

def _add_resolved(out: list[str], src: (uni.ModulePath | uni.ModuleItem)) -> None;

def _keep(out: list[str], raw: str) -> None;

def import_is_type_checking(imp: uni.Import) -> bool;

def _cond_is_type_checking(cond: uni.Expr) -> bool;

def top_package_dir(path: str) -> str;

def _is_package_dir(d: str) -> bool;

def _within(path: str, pkg_root: str) -> bool;

def _norm(path: str) -> str;

def param_names(fn: uni.Ability) -> list[str];

def param_annotation(fn: uni.Ability, name: str) -> (uni.Expr | None);

def _wrapper_closures(deco: uni.Ability) -> list[uni.Ability];

def _resolve_decorator(
    site: uni.Ability, dec: uni.Expr, prog: JacProgram, seen: set[str]
) -> (uni.Ability | None);

def self_attr_name(nd: (uni.Expr | None)) -> (str | None);

def lexical_ability(scope: (uni.Ability | None), name: str) -> (uni.Ability | None);

def _resolve_callee(
    site: uni.Ability, call: uni.FuncCall, prog: JacProgram, seen: set[str]
) -> (uni.Ability | None);

def class_method(
    arch: uni.Archetype, name: str, prog: JacProgram, seen: set[str], depth: int
) -> (uni.Ability | None);

def _self_attr_archetype(
    arch: uni.Archetype, attr: str, prog: JacProgram, seen: set[str]
) -> (uni.Archetype | None);

def find_ability(
    mod: uni.Module, name: str, prog: JacProgram, seen: set[str]
) -> (uni.Ability | None);

def find_class(
    mod: uni.Module, name: str, prog: JacProgram, seen: set[str]
) -> (uni.Archetype | None);

def _import_target(imp: uni.Import, name: str) -> (str | None);

def materialize_module(
    prog: JacProgram, mp: uni.ModulePath, seen: set[str]
) -> (uni.Module | None);

def module_imports_plain(mod: uni.Module, name: str) -> bool;

def wrapping_classes(
    prog: JacProgram, current: uni.Module, decorator: str
) -> list[uni.Archetype];

def _decorated_with(arch: uni.Archetype, decorator: str) -> bool;

def class_init(arch: uni.Archetype) -> (uni.Ability | None);

def attr_annotation(arch: uni.Archetype, attr: str) -> (str | None);

def attr_dict_kind(arch: uni.Archetype, attr: str) -> (str | None);

def _init_reachable(arch: uni.Archetype, ctor: uni.Ability) -> list[uni.Ability];

def body_is_only(body: any, typ: any) -> bool;

def _body_raises(stmt: uni.IfStmt) -> bool;

def _negated_dict_isinstance_attr(stmt: uni.IfStmt) -> (str | None);

def _under_not(nd: uni.UniNode, stop: uni.UniNode) -> bool;

def _is_none_check_attr(cond: uni.Expr) -> (str | None);
