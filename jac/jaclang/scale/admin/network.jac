import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jaclang.scale.jserver.jserver { HTTPMethod, JEndPoint }

obj JacAPIServerNetwork {
    def register_network_endpoints -> None;
}
