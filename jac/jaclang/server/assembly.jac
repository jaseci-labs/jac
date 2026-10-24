import os;


def service_apps(cfg: any, served: any) -> list[AppConfig];

def gateway_colocates(cfg: any) -> bool;

def colocate_services(
    cfg: any, served: any, base: str, application: PreparedApplication | None = None
) -> None;


def assemble_served_program(
    cfg: any, served: any, base: str, application: PreparedApplication | None = None
);
