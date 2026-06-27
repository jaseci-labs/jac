import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jac_scale.jserver.jserver { HTTPMethod, JEndPoint }

obj JacAPIServerDeployHealth {
    def register_deploy_health_endpoints -> None;
}
