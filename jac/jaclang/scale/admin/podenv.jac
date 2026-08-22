import from jaclang.runtimelib.serving.datatypes { Request }
import from jaclang.runtimelib.serving.datatypes { JSONResponse }
import from jaclang.runtimelib.serving.endpoint { HTTPMethod, JEndPoint }

obj JacAPIServerPodEnv {
    def register_podenv_endpoints -> None;
}
