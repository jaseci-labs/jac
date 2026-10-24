obj JacAPIServerPodEnv {
    has server: (EndpointHost | None) = None;

    def require_admin_json(Authorization: str | None) -> (JSONResponse | None) abst;
    def register_podenv_endpoints -> None;
}
