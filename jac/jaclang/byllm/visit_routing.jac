import enum;
import re;

import from types { UnionType }


def _class_info(arch: object) -> (ClassInfo | None);


def _safe_repr(value: object, limit: int = 120) -> str;


def _describe_arch(arch: object) -> str;


def _ability_fires(osf: ObjectSpatialFunction, wkr: object) -> bool;


def _node_run_desc(node_arch: object, wkr: object) -> str;


def _slugify(text: object) -> str;


def _first_field_value(arch: object) -> object;


def _make_handles(recs: list[dict[str, object]]) -> list[str];


def _route_context -> tuple[object, (Anchor | None)];


def _candidate_for(item: object, here_anchor: (Anchor | None)) -> tuple[any, ...];


def _resolve_choice(
    item: object, by_handle: dict[object, object], recs: list[dict[str, object]]
) -> object;


def route_visit(candidates: list[object], model: BaseLLM) -> list[object];
