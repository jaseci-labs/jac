obj JacAPIServerDeployHealth {
    has server: (EndpointHost | None) = None;

    def require_admin_json(Authorization: str | None) -> (JSONResponse | None) abst;
    def register_deploy_health_endpoints -> None;
}
