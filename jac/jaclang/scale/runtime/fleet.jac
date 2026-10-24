import os;

import json;
import logging;
import from pathlib { Path }
import from jaclang.server { sv_client }

glob logger = logging.getLogger(__name__),
     FLEET_ENV: str = "JAC_SV_FLEET",
     ROOT_PREFIX: str = "/",
     SERVICE_KINDS: tuple[str, ...] = ("service", "service-mesh");


obj FleetMember {
    has app: str,
        route: str = "",
        file: str = "",
        is_root: bool = False,
        client: bool = False;

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> FleetMember;
}


obj FleetSpec {
    has root_app: str = "",
        members: dict[str, FleetMember] = {},
        overrides: dict[str, dict[str, any]] = {};

    def add(member: FleetMember);
    def member(app: str) -> FleetMember | None;
    def root_member -> FleetMember | None;
    def names -> list[str];
    def service_names -> list[str];
    def routes -> dict[str, str];
    def files -> dict[str, str];
    def app_config(app: str) -> dict[str, any];
    def is_empty -> bool;
    def to_dict -> dict[str, any];
    def to_env -> str;
    static def from_dict(raw: dict[str, any]) -> FleetSpec;
    static def from_env_value(raw: str) -> FleetSpec | None;
}


def fleet_from_env -> FleetSpec | None;


def fleet_of(
    routes: dict[str, str],
    root_app: str = "",
    overrides: dict[str, dict[str, any]] | None = None,
    files: dict[str, str] | None = None,
    root_file: str = "main.jac",
    root_route: str = "",
    root_client: bool = False
) -> FleetSpec;


def solo_fleet(app_name: str, entry_file: str, client: bool = False) -> FleetSpec;


def guard_fleet_routes(fleet: FleetSpec);


def format_fleet_lines(fleet: FleetSpec) -> list[str];


def order_by_edges(names: list[str], edges: list[tuple[str, str]]) -> list[str];


def _dedup_edges(edges: list[tuple[str, str]]) -> list[tuple[str, str]];


def _compiled_app_edges(
    entry_path: str, app_name: str, app_kind: str, project_root: str
) -> list[tuple[str, str]];


def consumer_provider_edges(
    config: any,
    project_root: str,
    apps: list[AppConfig],
    entries: dict[str, str] | None = None
) -> list[tuple[str, str]];


def _member_file(entry_path: str, relative_to: str) -> str;


def _has_client(config: any, app: any) -> bool;


def _build_fleet(
    config: any,
    project_root: str,
    served: any,
    services: list[AppConfig],
    entries: dict[str, str],
    relative_to: str
) -> FleetSpec;


def service_apps_of(config: any, served: any) -> list[AppConfig];


def fleet_from_config(
    config: any, served_app: str = "", project_root: str = "", relative_to: str = ""
) -> FleetSpec;


def fleet_from_plans(
    config: any, project_root: str, served: any, members: list[any]
) -> FleetSpec;


def fleet_member_names(project_dir: str = "") -> list[str];
