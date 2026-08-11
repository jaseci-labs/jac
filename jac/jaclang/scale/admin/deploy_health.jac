import from jaclang.runtimelib.serving.datatypes { Request }
import from jaclang.runtimelib.serving.datatypes { JSONResponse }
import from jaclang.runtimelib.serving.endpoint { HTTPMethod, JEndPoint }

obj JacAPIServerDeployHealth {
    def register_deploy_health_endpoints -> None;
}
