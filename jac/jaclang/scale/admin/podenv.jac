import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jaclang.scale.jserver.jserver { HTTPMethod, JEndPoint }

obj JacAPIServerPodEnv {
    def register_podenv_endpoints -> None;
}
