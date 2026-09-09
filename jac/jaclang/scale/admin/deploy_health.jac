import from jaclang.server.serving.datatypes { Request }
import from jaclang.server.serving.datatypes { JSONResponse }
import from jaclang.server.serving.endpoint { HTTPMethod, JEndPoint }
import from jaclang.server.server { EndpointHost }

obj JacAPIServerDeployHealth {
    has server: (EndpointHost | None) = None;

    def require_admin_json(Authorization: str | None) -> (JSONResponse | None);
    def register_deploy_health_endpoints -> None;
}
