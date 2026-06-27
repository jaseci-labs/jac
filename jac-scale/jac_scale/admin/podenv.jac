import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jac_scale.jserver.jserver { HTTPMethod, JEndPoint }

obj JacAPIServerPodEnv {
    def register_podenv_endpoints -> None;
}
