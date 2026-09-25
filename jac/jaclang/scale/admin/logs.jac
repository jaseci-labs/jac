obj JacAPIServerLogs {
    has server: (EndpointHost | None) = None;

    def require_admin_json(Authorization: str | None) -> (JSONResponse | None) abst;
    def register_logs_endpoints -> None;
}
