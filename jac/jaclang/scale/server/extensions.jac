import base64;
import hmac;
import logging;
import os;

glob logger: logging.Logger = logging.getLogger(__name__);


def validate_events_url(url: (str | None));


def fleet_provisions_unknown_users(sv_name: str) -> bool;


obj FleetIdentityExtension(ServerExtension) {
    def register(server: JacAPIServer);
}


obj ObservabilityExtension(ServerExtension) {
    def register(server: JacAPIServer);
}


obj MetricsExtension(ServerExtension) {
    def register(server: JacAPIServer) -> None;
    def on_worker_exit(server: JacAPIServer, pid: int);
}


obj MailExtension(ServerExtension) {
    has emailer: (Emailer | None) = None,
        resolved: bool = False;

    def transport -> Emailer | None;
    def mail_transport -> any;
    def register(server: JacAPIServer);
}


obj EventsExtension(ServerExtension) {
    has broker: any = None;

    def register(server: JacAPIServer) -> None;
    def validate(server: JacAPIServer) -> list[str];
    def on_worker_start(server: JacAPIServer);
}


obj AdminExtension(ServerExtension, JacAPIServerAdmin, JacAPIServerLLMTelemetry, JacAPIServerWorkloads, JacAPIServerLogs, JacAPIServerTraces, JacAPIServerOps, JacAPIServerDeployHealth, JacAPIServerNetwork, JacAPIServerPodEnv) {
    def validate(server: JacAPIServer) -> list[str];
    def register(server: JacAPIServer) -> None;
}


def scale_extensions -> list[ServerExtension];
