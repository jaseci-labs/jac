import from jaclang.runtimelib.serving.datatypes { Request }
import from jaclang.runtimelib.serving.datatypes { JSONResponse }
import from jaclang.runtimelib.serving.endpoint { HTTPMethod, JEndPoint }

obj JacAPIServerNetwork {
    def register_network_endpoints -> None;
}
