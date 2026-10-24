import os;
import json;
import from collections.abc { Callable }

def escapes_record(escapes: list[tuple[int, str]]) -> list[any];

def element_to_dict(es: ElementSummary) -> dict[str, any];

def _str_list(value: object) -> list[str];

def _int_list(value: object) -> list[int];

def _str_rows(value: object) -> list[list[str]];

def _escape_rows(value: object) -> list[tuple[int, str]];

def _maps(value: object) -> list[dict[str, any]];

def element_from_dict(d: dict[str, any]) -> ElementSummary;

def summary_to_dict(ps: PlacementSummary) -> dict[str, any];

def summary_from_dict(d: dict[str, any]) -> (PlacementSummary | None);

def summary_to_bytes(ps: PlacementSummary) -> bytes;

def summary_from_bytes(
    data: bytes, path_mapper: Callable[[str], str] | None = None
) -> (PlacementSummary | None);

def collect_placement_rows(prog: JacProgram) -> dict[str, dict[str, any]];
